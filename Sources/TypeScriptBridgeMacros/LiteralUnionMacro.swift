import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A macro implementation that creates union types from string literals.
///
/// This macro processes the `@Union("literal1", "literal2", ...)` syntax and generates:
/// - Enum cases for each string literal (using backticks for special characters)
/// - Codable conformance with proper serialization/deserialization
/// - Access modifier support based on the enum's access level
public struct LiteralUnionMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.invalidDeclaration
        }

        let literals = try extractLiterals(from: node)
        let accessModifier = extractAccessModifier(from: enumDecl)

        let enumCases = literals.map { literal in
            var enumCase = EnumCaseDeclSyntax(
                elements: EnumCaseElementListSyntax([
                    EnumCaseElementSyntax(name: .identifier("`\(literal)`"))
                ])
            )

            if let modifier = accessModifier {
                enumCase.modifiers = DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(modifier))
                ])
            }

            return enumCase
        }

        return enumCases.map { DeclSyntax($0) }
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.invalidDeclaration
        }

        let literals = try extractLiterals(from: node)
        let accessModifier = extractAccessModifier(from: enumDecl)
        let accessPrefix = accessModifier != nil ? "\(accessModifier!) " : ""

        let rawValueCases =
            literals.map { literal in
                "case .`\(literal)`: return \"\(literal)\""
            }
            .joined(separator: "\n")

        let initCases =
            literals.map { literal in
                "case \"\(literal)\": self = .`\(literal)`"
            }
            .joined(separator: "\n")

        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Codable {
                \(raw: accessPrefix)var rawValue: String {
                    switch self {
                    \(raw: rawValueCases)
                    }
                }
                
                \(raw: accessPrefix)init?(rawValue: String) {
                    switch rawValue {
                    \(raw: initCases)
                    default: return nil
                    }
                }
                
                \(raw: accessPrefix)init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    let rawValue = try container.decode(String.self)
                    guard let value = Self(rawValue: rawValue) else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                    }
                    self = value
                }
                
                \(raw: accessPrefix)func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    try container.encode(rawValue)
                }
            }
            """
        )

        return [extensionDecl]
    }

    private static func extractLiterals(from node: AttributeSyntax) throws -> [String] {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            throw MacroError.noArguments
        }

        var literals: [String] = []

        for argument in arguments {
            if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
            {
                literals.append(segment.content.text)
            }
        }

        guard !literals.isEmpty else {
            throw MacroError.noValidLiterals
        }

        return literals
    }

    private static func extractAccessModifier(from enumDecl: EnumDeclSyntax) -> Keyword? {
        for modifier in enumDecl.modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public):
                return .public
            case .keyword(.internal):
                return .internal
            case .keyword(.private):
                return .private
            case .keyword(.fileprivate):
                return .fileprivate
            case .keyword(.package):
                return .package
            default:
                continue
            }
        }
        return nil
    }
}

/// Errors that can occur during literal union macro expansion.
enum MacroError: Error, CustomStringConvertible {
    /// The macro was applied to a non-enum declaration
    case invalidDeclaration
    /// No arguments were provided to the macro
    case noArguments
    /// No valid string literals were found in the arguments
    case noValidLiterals

    var description: String {
        switch self {
        case .invalidDeclaration:
            return "@Union can only be applied to enum declarations"
        case .noArguments:
            return "@Union requires string literal arguments"
        case .noValidLiterals:
            return "@Union requires at least one valid string literal"
        }
    }
}
