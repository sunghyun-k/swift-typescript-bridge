import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct TypeScriptBridgePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LiteralUnionMacro.self,
        TypeUnionMacro.self,
        TypeDiscriminatorMacro.self,
    ]
}
