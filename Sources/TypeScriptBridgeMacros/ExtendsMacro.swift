import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `@Extends(ParentType.self, ...)` attached macro.
public struct ExtendsMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            try context.diagnoseAndThrow(
                at: declaration,
                message: MacroDiagnostic(
                    id: "extends.notAStruct",
                    "@Extends can only be applied to struct declarations"
                )
            )
        }
        let parents = try extractParentTypeNames(from: node, in: context)
        let accessPrefix = Self.accessPrefix(for: structDecl)
        let ownProps = Self.storedProperties(in: structDecl)

        var decls: [DeclSyntax] = []

        if parents.count == 1 {
            let parent = parents[0]
            // Backward-compatible single-parent layout.
            decls.append("\(raw: accessPrefix)var _parent: \(raw: parent)")
            let paramList =
                (["_ parent: \(parent)"] + ownProps.map { "\($0.name): \($0.typeText)" })
                .joined(separator: ", ")
            var initBody = ["self._parent = parent"]
            for p in ownProps {
                initBody.append("self.\(p.name) = \(p.name)")
            }
            decls.append(
                """
                \(raw: accessPrefix)init(\(raw: paramList)) {
                    \(raw: initBody.joined(separator: "\n    "))
                }
                """
            )
        } else {
            // Multi-parent layout: _parent1, _parent2, ...
            for (idx, parent) in parents.enumerated() {
                let n = idx + 1
                decls.append("\(raw: accessPrefix)var _parent\(raw: n): \(raw: parent)")
            }

            var params: [String] = []
            var initBody: [String] = []
            for (idx, parent) in parents.enumerated() {
                let n = idx + 1
                params.append("_ parent\(n): \(parent)")
                initBody.append("self._parent\(n) = parent\(n)")
            }
            for p in ownProps {
                params.append("\(p.name): \(p.typeText)")
                initBody.append("self.\(p.name) = \(p.name)")
            }
            decls.append(
                """
                \(raw: accessPrefix)init(\(raw: params.joined(separator: ", "))) {
                    \(raw: initBody.joined(separator: "\n    "))
                }
                """
            )
        }

        return decls
    }

    private static func accessPrefix(for structDecl: StructDeclSyntax) -> String {
        for modifier in structDecl.modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public): return "public "
            case .keyword(.package): return "package "
            case .keyword(.internal): return "internal "
            case .keyword(.fileprivate): return "fileprivate "
            default: continue
            }
        }
        return ""
    }

    struct OwnProperty {
        let name: String
        let typeText: String
        let isOptional: Bool
    }

    private static func storedProperties(in structDecl: StructDeclSyntax) -> [OwnProperty] {
        var result: [OwnProperty] = []
        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in varDecl.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                    let typeAnn = binding.typeAnnotation
                else { continue }
                // Skip computed (has accessor block with `get`) but keep plain stored.
                if let accessor = binding.accessorBlock,
                    case .accessors(let list) = accessor.accessors
                {
                    let hasGet = list.contains { $0.accessorSpecifier.tokenKind == .keyword(.get) }
                    if hasGet { continue }
                }
                let typeText = typeAnn.type.trimmedDescription
                let isOptional = typeAnn.type.is(OptionalTypeSyntax.self)
                result.append(
                    .init(
                        name: pattern.identifier.text,
                        typeText: typeText,
                        isOptional: isOptional
                    )
                )
            }
        }
        return result
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            try context.diagnoseAndThrow(
                at: declaration,
                message: MacroDiagnostic(
                    id: "extends.notAStruct",
                    "@Extends can only be applied to struct declarations"
                )
            )
        }
        let parents = try extractParentTypeNames(from: node, in: context)
        let accessPrefix = Self.accessPrefix(for: structDecl)
        let ownProps = Self.storedProperties(in: structDecl)

        if parents.count == 1 {
            return try [
                singleParentExtension(
                    type: type,
                    parent: parents[0],
                    accessPrefix: accessPrefix,
                    ownProps: ownProps
                )
            ]
        } else {
            return try [
                multiParentExtension(
                    type: type,
                    parents: parents,
                    accessPrefix: accessPrefix,
                    ownProps: ownProps
                )
            ]
        }
    }

    // MARK: - Single parent extension (existing behavior, kept for backward compat)

    private static func singleParentExtension(
        type: some TypeSyntaxProtocol,
        parent parentTypeName: String,
        accessPrefix: String,
        ownProps: [OwnProperty]
    ) throws -> ExtensionDeclSyntax {
        // Empty CodingKeys enum with raw type fails to synthesize RawRepresentable,
        // so we only emit the enum when there is at least one own property.
        let codingKeysDecl: String = {
            if ownProps.isEmpty {
                return ""
            }
            let codingKeyCases = ownProps.map { "case \($0.name)" }.joined(separator: "; ")
            return "private enum CodingKeys: String, CodingKey { \(codingKeyCases) }"
        }()

        var decodeBody: [String] = []
        if ownProps.isEmpty {
            decodeBody.append("self._parent = try \(parentTypeName)(from: decoder)")
        } else {
            decodeBody.append(
                """
                do {
                    self._parent = try \(parentTypeName)(from: decoder)
                } catch let DecodingError.typeMismatch(expected, ctx)
                    where ctx.codingPath.last.flatMap({ CodingKeys(stringValue: $0.stringValue) }) != nil
                {
                    let key = ctx.codingPath.last!.stringValue
                    throw DecodingError.typeMismatch(
                        expected,
                        DecodingError.Context(
                            codingPath: ctx.codingPath,
                            debugDescription: \"Property '\\(key)' override conflict: parent's declared type (\\(expected)) is incompatible with the JSON value. The child redeclares '\\(key)' — ensure parent and child share a JSON representation.\",
                            underlyingError: ctx.underlyingError
                        )
                    )
                }
                """
            )
            decodeBody.append("let container = try decoder.container(keyedBy: CodingKeys.self)")
            for p in ownProps {
                if p.isOptional {
                    let wrappedType = String(p.typeText.dropLast())
                    decodeBody.append(
                        "self.\(p.name) = try container.decodeIfPresent(\(wrappedType).self, forKey: .\(p.name))"
                    )
                } else {
                    decodeBody.append(
                        "self.\(p.name) = try container.decode(\(p.typeText).self, forKey: .\(p.name))"
                    )
                }
            }
        }

        var encodeBody: [String] = []
        encodeBody.append("try _parent.encode(to: encoder)")
        if !ownProps.isEmpty {
            encodeBody.append("var container = encoder.container(keyedBy: CodingKeys.self)")
            for p in ownProps {
                if p.isOptional {
                    encodeBody.append("try container.encodeIfPresent(\(p.name), forKey: .\(p.name))")
                } else {
                    encodeBody.append("try container.encode(\(p.name), forKey: .\(p.name))")
                }
            }
        }

        return try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Codable, _ExtendsParent {
                \(raw: codingKeysDecl)

                \(raw: accessPrefix)init(from decoder: Decoder) throws {
                    \(raw: decodeBody.joined(separator: "\n    "))
                }

                \(raw: accessPrefix)func encode(to encoder: Encoder) throws {
                    \(raw: encodeBody.joined(separator: "\n    "))
                }
            }
            """
        )
    }

    // MARK: - Multi-parent extension

    private static func multiParentExtension(
        type: some TypeSyntaxProtocol,
        parents: [String],
        accessPrefix: String,
        ownProps: [OwnProperty]
    ) throws -> ExtensionDeclSyntax {
        // CodingKeys (omitted when no own props — empty raw-typed enum is invalid).
        let codingKeysDecl: String = {
            if ownProps.isEmpty {
                return ""
            }
            let cases = ownProps.map { "case \($0.name)" }.joined(separator: "; ")
            return "private enum CodingKeys: String, CodingKey { \(cases) }"
        }()

        // Per-parent dynamic member lookup subscripts.
        var subscriptDecls: [String] = []
        for (idx, parent) in parents.enumerated() {
            let n = idx + 1
            subscriptDecls.append(
                """
                \(accessPrefix)subscript<__ExtendsT>(dynamicMember keyPath: WritableKeyPath<\(parent), __ExtendsT>) -> __ExtendsT {
                    get { _parent\(n)[keyPath: keyPath] }
                    set { _parent\(n)[keyPath: keyPath] = newValue }
                }
                \(accessPrefix)subscript<__ExtendsT>(dynamicMember keyPath: KeyPath<\(parent), __ExtendsT>) -> __ExtendsT {
                    _parent\(n)[keyPath: keyPath]
                }
                """
            )
        }

        // init(from:)
        var decodeBody: [String] = []
        for (idx, parent) in parents.enumerated() {
            let n = idx + 1
            if ownProps.isEmpty {
                decodeBody.append("self._parent\(n) = try \(parent)(from: decoder)")
            } else {
                decodeBody.append(
                    """
                    do {
                        self._parent\(n) = try \(parent)(from: decoder)
                    } catch let DecodingError.typeMismatch(expected, ctx)
                        where ctx.codingPath.last.flatMap({ CodingKeys(stringValue: $0.stringValue) }) != nil
                    {
                        let key = ctx.codingPath.last!.stringValue
                        throw DecodingError.typeMismatch(
                            expected,
                            DecodingError.Context(
                                codingPath: ctx.codingPath,
                                debugDescription: \"Property '\\(key)' override conflict: parent \(parent)'s declared type (\\(expected)) is incompatible with the JSON value. The child redeclares '\\(key)' — ensure parent and child share a JSON representation.\",
                                underlyingError: ctx.underlyingError
                            )
                        )
                    }
                    """
                )
            }
        }
        if !ownProps.isEmpty {
            decodeBody.append("let container = try decoder.container(keyedBy: CodingKeys.self)")
            for p in ownProps {
                if p.isOptional {
                    let wrappedType = String(p.typeText.dropLast())
                    decodeBody.append(
                        "self.\(p.name) = try container.decodeIfPresent(\(wrappedType).self, forKey: .\(p.name))"
                    )
                } else {
                    decodeBody.append(
                        "self.\(p.name) = try container.decode(\(p.typeText).self, forKey: .\(p.name))"
                    )
                }
            }
        }

        // encode(to:)
        var encodeBody: [String] = []
        for idx in 0..<parents.count {
            let n = idx + 1
            encodeBody.append("try _parent\(n).encode(to: encoder)")
        }
        if !ownProps.isEmpty {
            encodeBody.append("var container = encoder.container(keyedBy: CodingKeys.self)")
            for p in ownProps {
                if p.isOptional {
                    encodeBody.append("try container.encodeIfPresent(\(p.name), forKey: .\(p.name))")
                } else {
                    encodeBody.append("try container.encode(\(p.name), forKey: .\(p.name))")
                }
            }
        }

        let subscriptsBlock = subscriptDecls.joined(separator: "\n\n    ")

        return try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Codable, _ExtendsParents {
                \(raw: codingKeysDecl)

                \(raw: subscriptsBlock)

                \(raw: accessPrefix)init(from decoder: Decoder) throws {
                    \(raw: decodeBody.joined(separator: "\n    "))
                }

                \(raw: accessPrefix)func encode(to encoder: Encoder) throws {
                    \(raw: encodeBody.joined(separator: "\n    "))
                }
            }
            """
        )
    }

    static func extractParentTypeNames(
        from node: AttributeSyntax,
        in context: some MacroExpansionContext
    ) throws -> [String] {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self), !arguments.isEmpty
        else {
            try context.diagnoseAndThrow(
                at: node,
                message: MacroDiagnostic(
                    id: "extends.missingParent",
                    "@Extends requires at least one parent type in `Type.self` form (e.g. @Extends(Parent.self))"
                )
            )
        }
        var names: [String] = []
        for arg in arguments {
            if let memberAccess = arg.expression.as(MemberAccessExprSyntax.self),
                let base = memberAccess.base?.as(DeclReferenceExprSyntax.self),
                memberAccess.declName.baseName.text == "self"
            {
                names.append(base.baseName.text)
                continue
            }
            // FixIt: if the user wrote `Parent` (bare type reference), suggest `Parent.self`.
            var fixIts: [FixIt] = []
            if let bare = arg.expression.as(DeclReferenceExprSyntax.self) {
                let replacement: ExprSyntax = "\(bare).self"
                fixIts.append(
                    FixIt(
                        message: MacroFixIt(
                            id: "extends.addSelf",
                            "Append `.self` to refer to the type metatype"
                        ),
                        changes: [
                            .replace(oldNode: Syntax(arg.expression), newNode: Syntax(replacement))
                        ]
                    )
                )
            }
            try context.diagnoseAndThrow(
                at: arg.expression,
                message: MacroDiagnostic(
                    id: "extends.invalidParent",
                    "Each @Extends argument must be a type in `Type.self` form"
                ),
                fixIts: fixIts
            )
        }
        return names
    }
}
