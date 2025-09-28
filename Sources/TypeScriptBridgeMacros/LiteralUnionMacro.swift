import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A macro implementation that creates union types from literal values.
///
/// This macro processes the `@Union("literal1", 100, true, ...)` syntax and generates:
/// - Enum cases for each literal value (using backticks for special characters)
/// - Codable and Equatable conformance with proper serialization/deserialization
/// - Support for mixed types (String, Int, Double, Bool) in a single union
/// - Access modifier support based on the enum's access level
public struct LiteralUnionMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw LiteralUnionError.invalidDeclaration
        }

        let literals = try extractLiterals(from: node)
        let accessModifier = MacroUtils.extractAccessModifier(from: enumDecl)

        let enumCases = literals.map { literal in
            var enumCase = EnumCaseDeclSyntax(
                elements: EnumCaseElementListSyntax([
                    EnumCaseElementSyntax(name: .identifier(literal.enumCaseName))
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
            throw LiteralUnionError.invalidDeclaration
        }

        let literals = try extractLiterals(from: node)
        let accessModifier = MacroUtils.extractAccessModifier(from: enumDecl)
        let accessPrefix = accessModifier != nil ? "\(accessModifier!) " : ""

        // Get the Swift type for the literal values
        let literalType = determineLiteralType(from: literals)
        let isMixedType = literalType == "any _LiteralType"

        if isMixedType {
            // For mixed types, generate specialized handling
            let rawValueCases =
                literals.map { literal in
                    "case .\(literal.enumCaseName): return \(literal.swiftLiteral)"
                }
                .joined(separator: "\n")

            let initCases =
                literals.map { literal in
                    let swiftValue = literal.swiftLiteral
                    return "if let value = rawValue as? \(literal.swiftTypeName), value == \(swiftValue) { self = .\(literal.enumCaseName); return }"
                }
                .joined(separator: "\n")

            let decodingCases = 
                literals.map { literal in
                    "if let value = try? container.decode(\(literal.swiftTypeName).self), value == \(literal.swiftLiteral) { self = .\(literal.enumCaseName); return }"
                }
                .joined(separator: "\n")

            let extensionDecl = try ExtensionDeclSyntax(
                """
                extension \(type.trimmed): Codable, Equatable {
                    \(raw: accessPrefix)var rawValue: any _LiteralType {
                        switch self {
                        \(raw: rawValueCases)
                        }
                    }
                    
                    \(raw: accessPrefix)init?(rawValue: any _LiteralType) {
                        \(raw: initCases)
                        return nil
                    }
                    
                    \(raw: accessPrefix)init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        \(raw: decodingCases)
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                    }
                    
                    \(raw: accessPrefix)func encode(to encoder: Encoder) throws {
                        var container = encoder.singleValueContainer()
                        try container.encode(rawValue)
                    }
                }
                """
            )
            return [extensionDecl]
        } else {
            // For homogeneous types, use the existing approach
            let rawValueCases =
                literals.map { literal in
                    "case .\(literal.enumCaseName): return \(literal.swiftLiteral(as: literalType))"
                }
                .joined(separator: "\n")

            let initCases =
                literals.map { literal in
                    "case \(literal.swiftLiteral(as: literalType)): self = .\(literal.enumCaseName)"
                }
                .joined(separator: "\n")

            let extensionDecl = try ExtensionDeclSyntax(
                """
                extension \(type.trimmed): Codable, Equatable {
                    \(raw: accessPrefix)var rawValue: \(raw: literalType) {
                        switch self {
                        \(raw: rawValueCases)
                        }
                    }
                    
                    \(raw: accessPrefix)init?(rawValue: \(raw: literalType)) {
                        switch rawValue {
                        \(raw: initCases)
                        default: 
                            return nil
                        }
                    }
                    
                    \(raw: accessPrefix)init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        let rawValue = try container.decode(\(raw: literalType).self)
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
    }

    private static func extractLiterals(from node: AttributeSyntax) throws -> [LiteralValue] {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            throw LiteralUnionError.noArguments
        }

        var literals: [LiteralValue] = []

        for argument in arguments {
            if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
            {
                literals.append(.string(segment.content.text))
            } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                guard let intValue = Int(intLiteral.literal.text) else {
                    continue
                }
                literals.append(.int(intValue))
            } else if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                guard let doubleValue = Double(floatLiteral.literal.text) else {
                    continue
                }
                literals.append(.double(doubleValue))
            } else if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                let boolValue = boolLiteral.literal.tokenKind == .keyword(.true)
                literals.append(.bool(boolValue))
            }
        }

        guard !literals.isEmpty else {
            throw LiteralUnionError.noValidLiterals
        }

        return literals
    }

    private static func determineLiteralType(from literals: [LiteralValue]) -> String {
        let types = Set(literals.map { $0.swiftTypeName })
        
        // If all same type, use that type
        if types.count == 1 {
            return types.first!
        }
        
        // For mixed types, use any _LiteralType to support all literal types
        return "any _LiteralType"
    }

}

/// Represents different types of literal values that can be used in union types
enum LiteralValue {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    
    /// Returns the Swift literal representation of this value
    var swiftLiteral: String {
        switch self {
        case .string(let value):
            return "\"\(value)\""
        case .int(let value):
            return "\(value)"
        case .double(let value):
            return "\(value)"
        case .bool(let value):
            return "\(value)"
        }
    }
    
    /// Returns the Swift literal representation converted to target type
    func swiftLiteral(as targetType: String) -> String {
        switch targetType {
        case "Double":
            switch self {
            case .int(let value):
                return "\(Double(value))"
            case .double(let value):
                return "\(value)"
            default:
                return swiftLiteral
            }
        case "String":
            switch self {
            case .string(let value):
                return "\"\(value)\""
            case .int(let value):
                return "\"\(value)\""
            case .double(let value):
                return "\"\(value)\""
            case .bool(let value):
                return "\"\(value)\""
            }
        case "any _LiteralType":
            // For mixed types, return the literal as-is to preserve the original type
            return swiftLiteral
        default:
            return swiftLiteral
        }
    }
    
    /// Returns the enum case name for this literal
    var enumCaseName: String {
        switch self {
        case .string(let value):
            return "`\(value)`"
        case .int(let value):
            return "`\(value)`"
        case .double(let value):
            return "`\(value)`"
        case .bool(let value):
            return "`\(value)`"
        }
    }
    
    /// Returns the underlying Swift type name
    var swiftTypeName: String {
        switch self {
        case .string:
            return "String"
        case .int:
            return "Int"
        case .double:
            return "Double"
        case .bool:
            return "Bool"
        }
    }
}

/// Errors that can occur during literal union macro expansion.
enum LiteralUnionError: Error, CustomStringConvertible {
    /// The macro was applied to a non-enum declaration
    case invalidDeclaration
    /// No arguments were provided to the macro
    case noArguments
    /// No valid literals were found in the arguments
    case noValidLiterals
    /// Unsupported literal type
    case unsupportedLiteralType(String)

    var description: String {
        switch self {
        case .invalidDeclaration:
            return "@Union can only be applied to enum declarations"
        case .noArguments:
            return "@Union requires literal arguments"
        case .noValidLiterals:
            return "@Union requires at least one valid literal (String, Int, Double, or Bool)"
        case .unsupportedLiteralType(let type):
            return "@Union does not support '\(type)' literals. Supported types: String, Int, Double, Bool"
        }
    }
}
