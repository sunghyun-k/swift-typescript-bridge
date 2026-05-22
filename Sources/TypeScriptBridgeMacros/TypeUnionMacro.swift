import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A macro implementation that creates union types from Swift types.
///
/// This macro processes the `@Union(Type1.self, Type2.self, ...)` syntax and generates:
/// - Enum cases for each type with associated values
/// - Codable conformance that attempts to decode each type in order
/// - Access modifier support based on the enum's access level
public struct TypeUnionMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            try diagnoseNotAnEnum(declaration: declaration, in: context)
        }

        let typeInfos = try extractTypeInfos(from: node, in: context)
        let accessModifier = MacroUtils.extractAccessModifier(from: enumDecl)

        let enumCases = typeInfos.map { typeInfo in
            var enumCase = EnumCaseDeclSyntax(
                elements: EnumCaseElementListSyntax([
                    EnumCaseElementSyntax(
                        name: .identifier(typeInfo.caseName),
                        parameterClause: EnumCaseParameterClauseSyntax(
                            parameters: EnumCaseParameterListSyntax([
                                EnumCaseParameterSyntax(
                                    type: IdentifierTypeSyntax(name: .identifier(typeInfo.typeName))
                                )
                            ])
                        )
                    )
                ])
            )

            if let modifier = accessModifier, modifier != .private {
                enumCase.modifiers = DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(modifier))
                ])
            }

            return enumCase
        }

        // Only generate enum cases in member expansion
        // Codable methods will be generated in extension expansion
        return enumCases.map { DeclSyntax($0) }
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            try diagnoseNotAnEnum(declaration: declaration, in: context)
        }

        let typeInfos = try extractTypeInfos(from: node, in: context)
        let accessModifier = MacroUtils.extractAccessModifier(from: enumDecl)

        let initFromDecoderMethod = try createInitFromDecoder(cases: typeInfos, accessModifier: accessModifier)
        let encodeToEncoderMethod = try createEncodeToEncoder(cases: typeInfos, accessModifier: accessModifier)
        let anyCodingKeyDecl = createAnyCodingKey()

        let extensionDecl = try ExtensionDeclSyntax("extension \(type.trimmed): Codable") {
            anyCodingKeyDecl
            initFromDecoderMethod
            encodeToEncoderMethod
        }

        return [extensionDecl]
    }

    private static func extractTypeInfos(
        from node: AttributeSyntax,
        in context: some MacroExpansionContext
    ) throws -> [TypeInfo] {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            try context.diagnoseAndThrow(
                at: node,
                message: MacroDiagnostic(
                    id: "typeUnion.noTypeArguments",
                    "@Union requires at least one type argument (Type.self)"
                )
            )
        }

        var typeInfos: [TypeInfo] = []

        for argument in arguments {
            if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self),
                let baseExpr = memberAccess.base?.as(DeclReferenceExprSyntax.self),
                memberAccess.declName.baseName.text == "self"
            {
                let typeName = baseExpr.baseName.text
                let caseName = typeName.prefix(1).lowercased() + typeName.dropFirst()
                typeInfos.append(TypeInfo(typeName: typeName, caseName: caseName))
                continue
            }
            // FixIt: bare type reference — suggest `.self`.
            var fixIts: [FixIt] = []
            if let bare = argument.expression.as(DeclReferenceExprSyntax.self) {
                let replacement: ExprSyntax = "\(bare).self"
                fixIts.append(
                    FixIt(
                        message: MacroFixIt(
                            id: "typeUnion.addSelf",
                            "Append `.self` to refer to the type metatype"
                        ),
                        changes: [
                            .replace(
                                oldNode: Syntax(argument.expression),
                                newNode: Syntax(replacement)
                            )
                        ]
                    )
                )
            }
            try context.diagnoseAndThrow(
                at: argument.expression,
                message: MacroDiagnostic(
                    id: "typeUnion.invalidArg",
                    "Each @Union argument must be a type in `Type.self` form"
                ),
                fixIts: fixIts
            )
        }

        if typeInfos.isEmpty {
            try context.diagnoseAndThrow(
                at: node,
                message: MacroDiagnostic(
                    id: "typeUnion.noValidTypes",
                    "@Union requires at least one valid type argument (Type.self)"
                )
            )
        }

        return typeInfos
    }

    private static func diagnoseNotAnEnum(
        declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> Never {
        try context.diagnoseAndThrow(
            at: declaration,
            message: MacroDiagnostic(
                id: "typeUnion.notAnEnum",
                "@Union can only be applied to enum declarations"
            )
        )
    }

    private static func createInitFromDecoder(cases: [TypeInfo], accessModifier: Keyword?) throws
        -> InitializerDeclSyntax
    {
        let accessPrefix = accessModifier.flatMap { $0 == .private ? nil : $0 }.map { "\($0) " } ?? ""

        return try InitializerDeclSyntax(
            "\(raw: accessPrefix)init(from decoder: Decoder) throws"
        ) {
            // Generate type aliases to avoid name conflicts
            for (index, typeInfo) in cases.enumerated() {
                "typealias Type\(raw: String(index)) = \(raw: typeInfo.typeName)"
            }
            ""
            "// Try discriminated union decoding first"
            for (index, typeInfo) in cases.enumerated() {
                "if Type\(raw: String(index)).self is any TypeDiscriminated.Type {"
                "    // Try to decode the type directly - if it succeeds, it's a match"
                "    if let decoded = try? Type\(raw: String(index))(from: decoder) {"
                "        self = .\(raw: typeInfo.caseName)(decoded)"
                "        return"
                "    }"
                "}"
            }
            ""
            "// Fall back to trying each type in order"
            "let container = try decoder.singleValueContainer()"
            for (index, typeInfo) in cases.enumerated() {
                "if let value = try? container.decode(Type\(raw: String(index)).self) {"
                "    self = .\(raw: typeInfo.caseName)(value)"
                "    return"
                "}"
            }
            ""
            "throw DecodingError.dataCorruptedError(in: container, debugDescription: \"Could not decode union type from any of the possible cases\")"
        }
    }

    private static func createEncodeToEncoder(cases: [TypeInfo], accessModifier: Keyword?) throws -> FunctionDeclSyntax
    {
        let accessPrefix = accessModifier.flatMap { $0 == .private ? nil : $0 }.map { "\($0) " } ?? ""

        return try FunctionDeclSyntax(
            "\(raw: accessPrefix)func encode(to encoder: Encoder) throws"
        ) {
            "var container = encoder.singleValueContainer()"
            "switch self {"
            for typeInfo in cases {
                "case .\(raw: typeInfo.caseName)(let event):"
                "    try container.encode(event)"
            }
            "}"
        }
    }

    private static func createAnyCodingKey() -> DeclSyntax {
        """
        private struct AnyCodingKey: CodingKey {
            var stringValue: String
            var intValue: Int?
            
            init?(stringValue: String) {
                self.stringValue = stringValue
                self.intValue = nil
            }
            
            init?(intValue: Int) {
                self.stringValue = "\\(intValue)"
                self.intValue = intValue
            }
        }
        """
    }
}

/// Information about a type used in a type union.
struct TypeInfo {
    /// The Swift type name (e.g., "User")
    let typeName: String
    /// The enum case name (same as typeName)
    let caseName: String
}
