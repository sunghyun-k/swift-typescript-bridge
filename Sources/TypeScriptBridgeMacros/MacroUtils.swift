import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Common utilities for macro implementations
enum MacroUtils {
    /// Extracts the access modifier from an enum declaration
    static func extractAccessModifier(from enumDecl: EnumDeclSyntax) -> Keyword? {
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
    
    /// Creates access prefix string from access modifier
    static func createAccessPrefix(from accessModifier: Keyword?) -> String {
        return accessModifier != nil ? "\(accessModifier!) " : ""
    }
    
    /// Common error handling for enum validation
    static func validateEnumDeclaration<T: Error>(_ declaration: some DeclGroupSyntax, 
                                                  invalidError: T) throws -> EnumDeclSyntax {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw invalidError
        }
        return enumDecl
    }
}