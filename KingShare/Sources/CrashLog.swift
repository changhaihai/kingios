import UIKit

/// 1:1 port of the Android CrashLog (crash dumps under Documents/crash, keeps 5 files).
final class CrashLog {
    private static let maxFiles = 5
    private static var started = false

    static func start() {
        guard !started else { return }
        started = true
        NSSetUncaughtExceptionHandler(kingCrashExceptionHandler)
    }

    fileprivate static func write(name: String, reason: String, callStack: String) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dir = documents.appendingPathComponent("crash", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileFormatter = DateFormatter()
        fileFormatter.locale = Locale(identifier: "en_US_POSIX")
        fileFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let file = dir.appendingPathComponent("crash_\(fileFormatter.string(from: Date())).txt")
        let content = "Time: \(timeFormatter.string(from: Date()))\n" +
            "Thread: \(Thread.current.name ?? "unknown")\n" +
            "Process: \(ProcessInfo.processInfo.processIdentifier)\n" +
            "Throwable: \(name): \(reason)\n" +
            "Stack trace:\n\(callStack)\n"
        try? content.write(to: file, atomically: true, encoding: .utf8)
        trim(dir)
    }

    private static func trim(_ dir: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let sorted = files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return a > b
        }
        for extra in sorted.dropFirst(maxFiles) {
            try? fm.removeItem(at: extra)
        }
    }
}

private func kingCrashExceptionHandler(_ exception: NSException) {
    CrashLog.write(name: exception.name.rawValue,
                   reason: exception.reason ?? "",
                   callStack: exception.callStackSymbols.joined(separator: "\n"))
}
