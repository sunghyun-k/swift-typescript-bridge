import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// A reusable error/warning message type used by all macros in this package.
///
/// We funnel diagnostics through this single type so locations and FixIts surface in
/// Xcode (and `swift build` logs) instead of just a generic
/// "external macro implementation threw an error" line.
struct MacroDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(
        domain: String = "TypeScriptBridgeMacros",
        id: String,
        _ message: String,
        severity: DiagnosticSeverity = .error
    ) {
        self.message = message
        self.diagnosticID = MessageID(domain: domain, id: id)
        self.severity = severity
    }
}

struct MacroFixIt: FixItMessage {
    let message: String
    let fixItID: MessageID

    init(domain: String = "TypeScriptBridgeMacros", id: String, _ message: String) {
        self.message = message
        self.fixItID = MessageID(domain: domain, id: id)
    }
}

extension MacroExpansionContext {
    /// Throw a `DiagnosticsError` to abort expansion. The framework will pick up the
    /// diagnostics from the error — do **not** also call `context.diagnose`, or each
    /// message ends up reported twice.
    func diagnoseAndThrow(
        at node: some SyntaxProtocol,
        message: MacroDiagnostic,
        fixIts: [FixIt] = []
    ) throws -> Never {
        let diag = Diagnostic(node: Syntax(node), message: message, fixIts: fixIts)
        throw DiagnosticsError(diagnostics: [diag])
    }
}
