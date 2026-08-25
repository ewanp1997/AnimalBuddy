import Foundation
import AppKit

enum MacroExecutor {
    static func run(_ macro: UserMacro, settings: AppSettings) throws {
        guard macro.isConfigured else { return }
        try runSteps(macro.effectiveSteps, settings: settings, nestedSlots: [])
    }

    private static func runSteps(_ steps: [MacroStep], settings: AppSettings, nestedSlots: [BlushSlot]) throws {
        for step in steps {
            guard !step.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            switch step.kind {
            case .shell: try runProcess(executable: "/bin/zsh", arguments: ["-lc", step.value])
            case .openApplication: try runProcess(executable: "/usr/bin/open", arguments: ["-a", step.value])
            case .openURL:
                guard let url = URL(string: step.value), NSWorkspace.shared.open(url) else { throw macroError("Could not open URL: \(step.value)") }
            case .runShortcut: try runProcess(executable: "/usr/bin/shortcuts", arguments: ["run", step.value])
            case .runBlushMacro:
                guard let slot = BlushSlot(rawValue: step.value) else { throw macroError("Unknown blush macro: \(step.value)") }
                guard !nestedSlots.contains(slot) else { throw macroError("Nested blush macro cycle detected") }
                let nested = slot == .left ? settings.leftBlushMacro : settings.rightBlushMacro
                guard nested.isConfigured else { throw macroError("The selected blush macro is not configured") }
                try runSteps(nested.effectiveSteps, settings: settings, nestedSlots: nestedSlots + [slot])
            }
        }
    }

    private static func runProcess(executable: String, arguments: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        let errorPipe = Pipe(); process.standardError = errorPipe
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Macro failed"
            throw macroError(message)
        }
    }

    private static func macroError(_ message: String) -> NSError {
        NSError(domain: "AnimalBuddyMacro", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
