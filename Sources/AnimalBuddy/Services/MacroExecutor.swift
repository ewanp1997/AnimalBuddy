import Foundation
import AppKit

enum MacroExecutor {
    static func run(_ macro: UserMacro, settings: AppSettings, input: DropInput? = nil) throws {
        guard macro.isConfigured else { return }
        try runSteps(macro.effectiveSteps, settings: settings, nestedSlots: [], input: input)
    }

    private static func runSteps(_ steps: [MacroStep], settings: AppSettings, nestedSlots: [BlushSlot], input: DropInput?) throws {
        for step in steps {
            guard !step.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let value = substituted(step.value, input: input)
            switch step.kind {
            case .shell: try runProcess(executable: "/bin/zsh", arguments: ["-lc", value])
            case .openApplication: try runProcess(executable: "/usr/bin/open", arguments: ["-a", value])
            case .openURL:
                guard let url = URL(string: value), NSWorkspace.shared.open(url) else { throw macroError("Could not open URL: \(value)") }
            case .runShortcut: try runProcess(executable: "/usr/bin/shortcuts", arguments: ["run", value])
            case .runBlushMacro:
                guard let slot = BlushSlot(rawValue: value) else { throw macroError("Unknown macro: \(value)") }
                guard !nestedSlots.contains(slot) else { throw macroError("Nested macro cycle detected") }
                let nested = slot == .left ? settings.leftBlushMacro : settings.rightBlushMacro
                guard nested.isConfigured else { throw macroError("The selected macro is not configured") }
                try runSteps(nested.effectiveSteps, settings: settings, nestedSlots: nestedSlots + [slot], input: input)
            }
        }
    }

    private static func substituted(_ value: String, input: DropInput?) -> String {
        guard let input else { return value }
        return value
            .replacingOccurrences(of: "{{path}}", with: input.urls.first?.path ?? "")
            .replacingOccurrences(of: "{{paths}}", with: input.urls.map(\.path).joined(separator: "\n"))
            .replacingOccurrences(of: "{{text}}", with: input.text ?? "")
            .replacingOccurrences(of: "{{category}}", with: input.category.rawValue)
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
