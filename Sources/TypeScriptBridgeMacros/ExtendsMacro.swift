import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `@Extends(ParentType.self)` attached macro.
public struct ExtendsMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw ExtendsError.notAStruct
        }
        let parentTypeName = try extractParentTypeName(from: node)
        let accessPrefix = Self.accessPrefix(for: structDecl)
        let ownProps = Self.storedProperties(in: structDecl)

        var decls: [DeclSyntax] = []

        // Stored parent
        decls.append("\(raw: accessPrefix)var _parent: \(raw: parentTypeName)")

        // Convenience init: init(_ parent: ParentType, <ownProps>)
        let paramList = (["_ parent: \(parentTypeName)"] + ownProps.map { "\($0.name): \($0.typeText)" })
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

        // Forwarding subscripts — parent side.
        decls.append(
            """
            \(raw: accessPrefix)subscript<T>(dynamicMember keyPath: WritableKeyPath<\(raw: parentTypeName), T>) -> T {
                get { _parent[keyPath: keyPath] }
                set { _parent[keyPath: keyPath] = newValue }
            }
            """
        )
        decls.append(
            """
            \(raw: accessPrefix)subscript<T>(dynamicMember keyPath: KeyPath<\(raw: parentTypeName), T>) -> T {
                _parent[keyPath: keyPath]
            }
            """
        )

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
        in _: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw ExtendsError.notAStruct
        }
        let parentTypeName = try extractParentTypeName(from: node)
        let accessPrefix = Self.accessPrefix(for: structDecl)
        let ownProps = Self.storedProperties(in: structDecl)

        // CodingKeys enum
        let codingKeyCases: String
        if ownProps.isEmpty {
            codingKeyCases = ""
        } else {
            codingKeyCases = ownProps.map { "case \($0.name)" }.joined(separator: "; ")
        }
        let codingKeysDecl: String = {
            if ownProps.isEmpty {
                return "private enum CodingKeys: String, CodingKey {}"
            } else {
                return "private enum CodingKeys: String, CodingKey { \(codingKeyCases) }"
            }
        }()

        // init(from:)
        var decodeBody: [String] = []
        decodeBody.append("self._parent = try \(parentTypeName)(from: decoder)")
        if !ownProps.isEmpty {
            decodeBody.append("let container = try decoder.container(keyedBy: CodingKeys.self)")
            for p in ownProps {
                if p.isOptional {
                    // Strip trailing `?` for decodeIfPresent's non-optional type arg.
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

        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Codable {
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
        return [extensionDecl]
    }

    static func extractParentTypeName(from node: AttributeSyntax) throws -> String {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
            let first = arguments.first,
            let memberAccess = first.expression.as(MemberAccessExprSyntax.self),
            let base = memberAccess.base?.as(DeclReferenceExprSyntax.self),
            memberAccess.declName.baseName.text == "self"
        else {
            throw ExtendsError.invalidParentArgument
        }
        return base.baseName.text
    }
}

enum ExtendsError: Error, CustomStringConvertible {
    case notAStruct
    case invalidParentArgument

    var description: String {
        switch self {
        case .notAStruct:
            return "@Extends can only be applied to struct declarations"
        case .invalidParentArgument:
            return "@Extends requires a parent type in `Type.self` form (e.g. @Extends(Parent.self))"
        }
    }
}
