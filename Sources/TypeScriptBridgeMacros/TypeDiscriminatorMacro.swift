import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A macro implementation that marks types as discriminated for use in unions.
///
/// This macro:
/// - Extracts the discriminator field name from the keyPath
/// - Finds the field's type definition (must be an enum with @Union)
/// - Extracts the literal values from the @Union macro
/// - Generates TypeDiscriminated protocol conformance
public struct TypeDiscriminatorMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw TypeDiscriminatorError.notAStruct
        }

        // Extract keyPath argument
        let keyFieldName = try extractKeyFieldName(from: node)

        // Find the field in the struct
        guard let fieldType = findFieldType(named: keyFieldName, in: structDecl) else {
            throw TypeDiscriminatorError.fieldNotFound(keyFieldName)
        }

        // Find the enum declaration for this field type
        guard let enumDecl = findEnumDeclaration(named: fieldType, in: structDecl) else {
            throw TypeDiscriminatorError.enumNotFound(fieldType)
        }

        // Extract discriminator values from @Union attribute
        let discriminatorValues = try extractDiscriminatorValues(from: enumDecl)

        // Generate the extension
        let valuesArrayLiteral = discriminatorValues.map { "\"\($0)\"" }.joined(separator: ", ")

        let extensionDecl = try ExtensionDeclSyntax("extension \(type.trimmed): TypeDiscriminated") {
            "static let discriminatorKey = \"\(raw: keyFieldName)\""
            "static let discriminatorValues = [\(raw: valuesArrayLiteral)]"
        }

        return [extensionDecl]
    }

    /// Extracts the field name from the field argument
    private static func extractKeyFieldName(from node: AttributeSyntax) throws -> String {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
            let firstArg = arguments.first,
            firstArg.label?.text == "field"
        else {
            throw TypeDiscriminatorError.missingField
        }

        // Handle string literal
        if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self) {
            for segment in stringLiteral.segments {
                if let stringSegment = segment.as(StringSegmentSyntax.self) {
                    return stringSegment.content.text
                }
            }
        }

        throw TypeDiscriminatorError.invalidField
    }

    /// Finds the type of a field in the struct
    private static func findFieldType(named fieldName: String, in structDecl: StructDeclSyntax) -> String? {
        for member in structDecl.memberBlock.members {
            if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in variableDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                        pattern.identifier.text == fieldName,
                        let typeAnnotation = binding.typeAnnotation
                    {
                        // Extract the type name
                        if let identifierType = typeAnnotation.type.as(IdentifierTypeSyntax.self) {
                            return identifierType.name.text
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Finds an enum declaration with the given name in the struct
    private static func findEnumDeclaration(named enumName: String, in structDecl: StructDeclSyntax) -> EnumDeclSyntax?
    {
        for member in structDecl.memberBlock.members {
            if let enumDecl = member.decl.as(EnumDeclSyntax.self),
                enumDecl.name.text == enumName
            {
                return enumDecl
            }
        }
        return nil
    }

    /// Extracts discriminator values from an enum's @Union attribute
    private static func extractDiscriminatorValues(from enumDecl: EnumDeclSyntax) throws -> [String] {
        // Find the @Union attribute
        for attribute in enumDecl.attributes {
            if let customAttr = attribute.as(AttributeSyntax.self),
                let identifierType = customAttr.attributeName.as(IdentifierTypeSyntax.self),
                identifierType.name.text == "Union"
            {

                // Extract literal arguments
                guard let arguments = customAttr.arguments?.as(LabeledExprListSyntax.self) else {
                    throw TypeDiscriminatorError.noUnionArguments
                }

                var values: [String] = []

                for argument in arguments {
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                        // Extract string literal value
                        for segment in stringLiteral.segments {
                            if let stringSegment = segment.as(StringSegmentSyntax.self) {
                                values.append(stringSegment.content.text)
                            }
                        }
                    } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        values.append(intLiteral.literal.text)
                    } else if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        values.append(floatLiteral.literal.text)
                    } else if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        values.append(boolLiteral.literal.text)
                    }
                }

                if values.isEmpty {
                    throw TypeDiscriminatorError.noValidUnionValues
                }

                return values
            }
        }

        throw TypeDiscriminatorError.missingUnionAttribute
    }
}

/// Errors that can occur during type discriminator macro expansion.
enum TypeDiscriminatorError: Error, CustomStringConvertible {
    case notAStruct
    case missingField
    case invalidField
    case fieldNotFound(String)
    case enumNotFound(String)
    case missingUnionAttribute
    case noUnionArguments
    case noValidUnionValues

    var description: String {
        switch self {
        case .notAStruct:
            return "@TypeDiscriminator can only be applied to struct declarations"
        case .missingField:
            return "@TypeDiscriminator requires a field argument"
        case .invalidField:
            return "Invalid field format. Expected a string literal (e.g., \"type\")"
        case .fieldNotFound(let name):
            return "Field '\(name)' not found in struct"
        case .enumNotFound(let name):
            return "Enum type '\(name)' not found in struct"
        case .missingUnionAttribute:
            return "The discriminator field's enum must have a @Union attribute"
        case .noUnionArguments:
            return "@Union attribute must have literal arguments"
        case .noValidUnionValues:
            return "No valid literal values found in @Union attribute"
        }
    }
}
