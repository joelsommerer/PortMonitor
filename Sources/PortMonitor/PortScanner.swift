import Foundation
import Combine
import Darwin
import AppKit

struct PortInfo: Identifiable, Hashable {
    let id: String
    let port: Int
    let pid: Int32
    let command: String
    let user: String
    let isDevPort: Bool
}

@MainActor
final class PortScanner: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var lastError: String?
    @Published var isScanning: Bool = false

    nonisolated static let devPorts: Set<Int> = [
        3000, 3001, 3030, 3333,
        4000, 4200, 4321,
        5000, 5001, 5173, 5174, 5273, 5500,
        8000, 8001, 8080, 8081, 8888,
        9000, 9001, 9090, 9229,
        27017, 5432, 3306, 6379, 11434
    ]

    /// Ports von Diensten, die typischerweise kein HTTP sprechen.
    /// Für diese verstecken wir den Browser-Button.
    nonisolated static let nonHttpPorts: Set<Int> = [
        22,    // SSH
        25,    // SMTP
        53,    // DNS
        110,   // POP3
        143,   // IMAP
        465, 587,  // SMTP TLS/Submission
        993, 995,  // IMAPS, POP3S
        3306,  // MySQL
        5432,  // PostgreSQL
        6379,  // Redis
        27017, // MongoDB
        9092,  // Kafka
        2181,  // ZooKeeper
        11211  // Memcached
    ]

    nonisolated static func likelyHttpPort(_ port: Int) -> Bool {
        !nonHttpPorts.contains(port)
    }

    nonisolated static func openInBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        Task { @MainActor in
            NSWorkspace.shared.open(url)
        }
    }

    func refresh() {
        isScanning = true
        Task.detached(priority: .userInitiated) {
            let result = Self.runLsof()
            await MainActor.run {
                switch result {
                case .success(let ports):
                    self.ports = ports.sorted { $0.port < $1.port }
                    self.lastError = nil
                case .failure(let message):
                    self.lastError = message
                }
                self.isScanning = false
            }
        }
    }

    enum ScanResult {
        case success([PortInfo])
        case failure(String)
    }

    nonisolated static func runLsof() -> ScanResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcLn"]

        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return .failure("lsof konnte nicht gestartet werden: \(error.localizedDescription)")
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return .failure("Konnte lsof-Ausgabe nicht lesen")
        }
        return .success(parse(lsofOutput: output))
    }

    nonisolated static func parse(lsofOutput: String) -> [PortInfo] {
        var results: [PortInfo] = []
        var currentPid: Int32 = 0
        var currentCmd: String = ""
        var currentUser: String = ""
        var seen: Set<String> = []

        for rawLine in lsofOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let prefix = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())
            switch prefix {
            case "p":
                currentPid = Int32(value) ?? 0
                currentCmd = ""
                currentUser = ""
            case "c":
                currentCmd = value
            case "L":
                currentUser = value
            case "n":
                guard let portPart = value.split(separator: ":").last,
                      let port = Int(portPart)
                else { continue }
                let key = "\(currentPid)-\(port)"
                if seen.contains(key) { continue }
                seen.insert(key)
                results.append(PortInfo(
                    id: key,
                    port: port,
                    pid: currentPid,
                    command: currentCmd,
                    user: currentUser,
                    isDevPort: devPorts.contains(port)
                ))
            default:
                break
            }
        }
        return results
    }

    func stop(pid: Int32, port: Int) {
        _ = kill(pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if kill(pid, 0) == 0 {
                _ = kill(pid, SIGKILL)
            }
            self?.refresh()
        }
    }
}
