import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A macro implementation that marks types as discriminated for use in unions.
///
/// This macro:
/// - Extracts the discriminator property name from the parameter
/// - Finds the property's type definition (must be an enum with @Union)
/// - Extracts the literal values from the @Union macro
/// - Generates TypeDiscriminated protocol conformance
public struct UnionDiscriminatorMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            try context.diagnoseAndThrow(
                at: declaration,
                message: MacroDiagnostic(
                    id: "discriminator.notAStruct",
                    "@UnionDiscriminator can only be applied to struct declarations"
                )
            )
        }

        // Extract property name argument
        let keyFieldName = try extractPropertyName(from: node, in: context)

        // Find the field in the struct
        guard let fieldType = findFieldType(named: keyFieldName, in: structDecl) else {
            try context.diagnoseAndThrow(
                at: node,
                message: MacroDiagnostic(
                    id: "discriminator.fieldNotFound",
                    "Property '\(keyFieldName)' not found in struct. @UnionDiscriminator expects the named property to be declared on the same struct."
                )
            )
        }

        // Verify that the enum declaration exists for this field type
        guard findEnumDeclaration(named: fieldType, in: structDecl) != nil else {
            try context.diagnoseAndThrow(
                at: node,
                message: MacroDiagnostic(
                    id: "discriminator.enumNotFound",
                    "Enum type '\(fieldType)' (referenced by '\(keyFieldName)') not found in struct. Declare it as a nested enum, typically via `@Union(\"…\") enum \(fieldType) {}`."
                )
            )
        }

        // Generate the extension with DiscriminatorType typealias
        let extensionDecl = try ExtensionDeclSyntax("extension \(type.trimmed): TypeDiscriminated") {
            "typealias DiscriminatorType = \(raw: fieldType)"
            "static let discriminatorKey = \"\(raw: keyFieldName)\""
        }

        return [extensionDecl]
    }

    /// Extracts the property name from the unlabeled argument
    private static func extractPropertyName(
        from node: AttributeSyntax,
        in context: some MacroExpansionContext
    ) throws -> String {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
            let firstArg = arguments.first
        else {
            try context.diagnoseAndThrow(
                at: node,
                message: MacroDiagnostic(
                    id: "discriminator.missingProperty",
                    "@UnionDiscriminator requires a property name argument (e.g. @UnionDiscriminator(\"type\"))"
                )
            )
        }

        // Check that the argument is unlabeled.
        if let label = firstArg.label, !label.text.isEmpty {
            // FixIt: remove the label.
            let stripped = firstArg.with(\.label, nil).with(\.colon, nil)
            let fixIt = FixIt(
                message: MacroFixIt(
                    id: "discriminator.dropLabel",
                    "Drop the argument label"
                ),
                changes: [.replace(oldNode: Syntax(firstArg), newNode: Syntax(stripped))]
            )
            try context.diagnoseAndThrow(
                at: firstArg,
                message: MacroDiagnostic(
                    id: "discriminator.unexpectedLabel",
                    "@UnionDiscriminator expects an unlabeled argument. Use @UnionDiscriminator(\"type\") not @UnionDiscriminator(property: \"type\")"
                ),
                fixIts: [fixIt]
            )
        }

        if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self) {
            for segment in stringLiteral.segments {
                if let stringSegment = segment.as(StringSegmentSyntax.self) {
                    return stringSegment.content.text
                }
            }
        }

        try context.diagnoseAndThrow(
            at: firstArg.expression,
            message: MacroDiagnostic(
                id: "discriminator.invalidProperty",
                "Expected a string literal property name (e.g. \"type\")"
            )
        )
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

}
