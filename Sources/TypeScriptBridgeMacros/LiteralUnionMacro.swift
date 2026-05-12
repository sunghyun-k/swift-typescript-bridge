import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A macro implementation that creates union types from literal values.
///
/// This macro processes the `@Union("literal1", 100, true, nil, ...)` syntax and generates:
/// - Enum cases for each literal value (using backticks for special characters)
/// - Codable and Equatable conformance with proper serialization/deserialization
/// - Support for mixed types (String, Int, Double, Bool) in a single union
/// - Support for a `nil` literal — adds a `null` case that round-trips as JSON `null`
/// - Access modifier support based on the enum's access level
public struct LiteralUnionMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            try diagnoseNotAnEnum(declaration: declaration, in: context)
        }

        let literals = try extractLiterals(from: node, in: context)
        let accessModifier = MacroUtils.extractAccessModifier(from: enumDecl)

        let enumCases = literals.map { literal in
            var enumCase = EnumCaseDeclSyntax(
                elements: EnumCaseElementListSyntax([
                    EnumCaseElementSyntax(name: .identifier(literal.enumCaseName))
                ])
            )

            if let modifier = accessModifier, modifier != .private {
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
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            try diagnoseNotAnEnum(declaration: declaration, in: context)
        }

        let literals = try extractLiterals(from: node, in: context)
        let accessModifier = MacroUtils.extractAccessModifier(from: enumDecl)
        let accessPrefix = accessModifier.flatMap { $0 == .private ? nil : $0 }.map { "\($0) " } ?? ""

        let hasNull = literals.contains(where: { if case .null = $0 { true } else { false } })
        let nonNullLiterals = literals.filter { if case .null = $0 { false } else { true } }

        // Pick the base raw type from non-null literals; if only `nil` was given, fall back to String.
        let baseType: String
        if nonNullLiterals.isEmpty {
            baseType = "String"
        } else {
            baseType = determineLiteralType(from: nonNullLiterals)
        }
        let isMixedType = baseType == "any _LiteralType"
        let rawValueType: String
        if hasNull {
            // `any _LiteralType?` is ambiguous in Swift — needs parentheses.
            rawValueType = isMixedType ? "(\(baseType))?" : "\(baseType)?"
        } else {
            rawValueType = baseType
        }

        if isMixedType {
            return [
                try mixedExtension(
                    type: type,
                    literals: literals,
                    hasNull: hasNull,
                    rawValueType: rawValueType,
                    accessPrefix: accessPrefix
                )
            ]
        } else {
            return [
                try homogeneousExtension(
                    type: type,
                    literals: literals,
                    nonNullLiterals: nonNullLiterals,
                    hasNull: hasNull,
                    baseType: baseType,
                    rawValueType: rawValueType,
                    accessPrefix: accessPrefix
                )
            ]
        }
    }

    private static func mixedExtension(
        type: some TypeSyntaxProtocol,
        literals: [LiteralValue],
        hasNull: Bool,
        rawValueType: String,
        accessPrefix: String
    ) throws -> ExtensionDeclSyntax {
        let rawValueCases =
            literals.map { literal -> String in
                if case .null = literal {
                    return "case .\(literal.enumCaseName): return nil"
                }
                return "case .\(literal.enumCaseName): return \(literal.swiftLiteral)"
            }
            .joined(separator: "\n        ")

        var initCases: [String] = []
        if hasNull {
            initCases.append("if rawValue == nil { self = .`null`; return }")
        }
        for literal in literals where !literal.isNull {
            initCases.append(
                "if let value = rawValue as? \(literal.swiftTypeName), value == \(literal.swiftLiteral) { self = .\(literal.enumCaseName); return }"
            )
        }
        let initBody = initCases.joined(separator: "\n        ")

        var decodingCases: [String] = []
        if hasNull {
            decodingCases.append("if container.decodeNil() { self = .`null`; return }")
        }
        for literal in literals where !literal.isNull {
            decodingCases.append(
                "if let value = try? container.decode(\(literal.swiftTypeName).self), value == \(literal.swiftLiteral) { self = .\(literal.enumCaseName); return }"
            )
        }
        let decodingBody = decodingCases.joined(separator: "\n        ")

        let encodeBody: String
        if hasNull {
            encodeBody = """
                if case .`null` = self {
                    try container.encodeNil()
                } else if let value = rawValue {
                    try container.encode(value)
                } else {
                    try container.encodeNil()
                }
                """
        } else {
            encodeBody = "try container.encode(rawValue)"
        }

        return try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Codable, Equatable {
                \(raw: accessPrefix)var rawValue: \(raw: rawValueType) {
                    switch self {
                    \(raw: rawValueCases)
                    }
                }

                \(raw: accessPrefix)init?(rawValue: \(raw: rawValueType)) {
                    \(raw: initBody)
                    return nil
                }

                \(raw: accessPrefix)init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    \(raw: decodingBody)
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                }

                \(raw: accessPrefix)func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    \(raw: encodeBody)
                }
            }
            """
        )
    }

    private static func homogeneousExtension(
        type: some TypeSyntaxProtocol,
        literals: [LiteralValue],
        nonNullLiterals: [LiteralValue],
        hasNull: Bool,
        baseType: String,
        rawValueType: String,
        accessPrefix: String
    ) throws -> ExtensionDeclSyntax {
        let rawValueCases =
            literals.map { literal -> String in
                if case .null = literal {
                    return "case .\(literal.enumCaseName): return nil"
                }
                return "case .\(literal.enumCaseName): return \(literal.swiftLiteral(as: baseType))"
            }
            .joined(separator: "\n        ")

        // init?(rawValue:) switches on the rawValue.
        let switchHeader = hasNull ? "switch rawValue" : "switch rawValue"
        var initSwitchCases: [String] = []
        if hasNull {
            initSwitchCases.append("case .none: self = .`null`")
        }
        for literal in nonNullLiterals {
            let pat =
                hasNull
                ? "case .some(\(literal.swiftLiteral(as: baseType)))" : "case \(literal.swiftLiteral(as: baseType))"
            initSwitchCases.append("\(pat): self = .\(literal.enumCaseName)")
        }
        let initSwitchBody = initSwitchCases.joined(separator: "\n        ")

        // init(from:)
        let initFromBody: String
        if hasNull {
            initFromBody = """
                let container = try decoder.singleValueContainer()
                if container.decodeNil() {
                    self = .`null`
                    return
                }
                let rawValue = try container.decode(\(baseType).self)
                guard let value = Self(rawValue: rawValue) else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                }
                self = value
                """
        } else {
            initFromBody = """
                let container = try decoder.singleValueContainer()
                let rawValue = try container.decode(\(baseType).self)
                guard let value = Self(rawValue: rawValue) else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                }
                self = value
                """
        }

        // encode(to:)
        let encodeBody: String
        if hasNull {
            encodeBody = """
                var container = encoder.singleValueContainer()
                if case .`null` = self {
                    try container.encodeNil()
                } else {
                    try container.encode(rawValue!)
                }
                """
        } else {
            encodeBody = """
                var container = encoder.singleValueContainer()
                try container.encode(rawValue)
                """
        }

        return try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Codable, Equatable {
                \(raw: accessPrefix)var rawValue: \(raw: rawValueType) {
                    switch self {
                    \(raw: rawValueCases)
                    }
                }

                \(raw: accessPrefix)init?(rawValue: \(raw: rawValueType)) {
                    \(raw: switchHeader) {
                    \(raw: initSwitchBody)
                    default:
                        return nil
                    }
                }

                \(raw: accessPrefix)init(from decoder: Decoder) throws {
                    \(raw: initFromBody)
                }

                \(raw: accessPrefix)func encode(to encoder: Encoder) throws {
                    \(raw: encodeBody)
                }
            }
            """
        )
    }

    private static func extractLiterals(
        from node: AttributeSyntax,
        in context: some MacroExpansionContext
    ) throws -> [LiteralValue] {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            try context.diagnoseAndThrow(
                at: node,
                message: MacroDiagnostic(
                    id: "union.noArguments",
                    "@Union requires at least one literal argument"
                )
            )
        }

        var literals: [LiteralValue] = []

        for argument in arguments {
            let expr = argument.expression
            if expr.is(NilLiteralExprSyntax.self) {
                literals.append(.null)
            } else if let stringLiteral = expr.as(StringLiteralExprSyntax.self),
                let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
            {
                literals.append(.string(segment.content.text))
            } else if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
                guard let intValue = Int(intLiteral.literal.text) else {
                    continue
                }
                literals.append(.int(intValue))
            } else if let floatLiteral = expr.as(FloatLiteralExprSyntax.self) {
                guard let doubleValue = Double(floatLiteral.literal.text) else {
                    continue
                }
                literals.append(.double(doubleValue))
            } else if let boolLiteral = expr.as(BooleanLiteralExprSyntax.self) {
                let boolValue = boolLiteral.literal.tokenKind == .keyword(.true)
                literals.append(.bool(boolValue))
            } else if expr.is(MemberAccessExprSyntax.self) {
                // Likely a `Type.self` argument — user confused @Union(literal,...) with @Union(types,...).
                try context.diagnoseAndThrow(
                    at: expr,
                    message: MacroDiagnostic(
                        id: "union.typeArgInLiteralUnion",
                        "Type arguments (Type.self) belong to the type-union overload — pass literals (String, Int, Double, Bool, nil) here, or move this case to a `@Union(...)` over types."
                    )
                )
            }
        }

        guard !literals.isEmpty else {
            try context.diagnoseAndThrow(
                at: node,
                message: MacroDiagnostic(
                    id: "union.noValidLiterals",
                    "@Union requires at least one valid literal (String, Int, Double, Bool, or nil)"
                )
            )
        }

        return literals
    }

    private static func diagnoseNotAnEnum(
        declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> Never {
        try context.diagnoseAndThrow(
            at: declaration,
            message: MacroDiagnostic(
                id: "union.invalidDeclaration",
                "@Union can only be applied to enum declarations"
            )
        )
    }

    private static func determineLiteralType(from literals: [LiteralValue]) -> String {
        let types = Set(literals.map { $0.swiftTypeName })
        if types.count == 1 {
            return types.first!
        }
        return "any _LiteralType"
    }
}

/// Represents different types of literal values that can be used in union types
enum LiteralValue {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// Returns the Swift literal representation of this value (non-null only).
    var swiftLiteral: String {
        switch self {
        case .string(let value): return "\"\(value)\""
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .bool(let value): return "\(value)"
        case .null: return "nil"
        }
    }

    /// Returns the Swift literal representation converted to target type.
    func swiftLiteral(as targetType: String) -> String {
        switch targetType {
        case "Double":
            switch self {
            case .int(let value): return "\(Double(value))"
            case .double(let value): return "\(value)"
            default: return swiftLiteral
            }
        case "String":
            switch self {
            case .string(let value): return "\"\(value)\""
            case .int(let value): return "\"\(value)\""
            case .double(let value): return "\"\(value)\""
            case .bool(let value): return "\"\(value)\""
            case .null: return "nil"
            }
        case "any _LiteralType":
            return swiftLiteral
        default:
            return swiftLiteral
        }
    }

    /// Returns the enum case name for this literal
    var enumCaseName: String {
        switch self {
        case .string(let value): return "`\(value)`"
        case .int(let value): return "`\(value)`"
        case .double(let value): return "`\(value)`"
        case .bool(let value): return "`\(value)`"
        case .null: return "`null`"
        }
    }

    /// Returns the underlying Swift type name (unused for `.null`).
    var swiftTypeName: String {
        switch self {
        case .string: return "String"
        case .int: return "Int"
        case .double: return "Double"
        case .bool: return "Bool"
        case .null: return "Never"  // not used; null is handled out of band
        }
    }
}
