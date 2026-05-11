import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var scanner: PortScanner
    @State private var showAll = false
    @State private var timer: Timer?

    private var filteredPorts: [PortInfo] {
        showAll ? scanner.ports : scanner.ports.filter { $0.isDevPort }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 400, height: 520)
        .onAppear {
            scanner.refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                Task { @MainActor in scanner.refresh() }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "network")
                .foregroundStyle(.blue)
            Text("Port Monitor")
                .font(.headline)
            Spacer()
            Toggle(isOn: $showAll) {
                Text("Alle")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            Button {
                scanner.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(scanner.isScanning ? 360 : 0))
                    .animation(
                        scanner.isScanning
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: scanner.isScanning
                    )
            }
            .buttonStyle(.borderless)
            .help("Aktualisieren")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let err = scanner.lastError {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                Text(err)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredPorts.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(.green)
                    .font(.title2)
                Text(showAll ? "Keine belegten Ports" : "Keine Dev-Ports belegt")
                    .foregroundStyle(.secondary)
                if !showAll {
                    Text("Schalte \u{201E}Alle\u{201C} um, um alle aktiven Ports zu sehen")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredPorts) { port in
                        PortRow(port: port, scanner: scanner)
                        Divider()
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(filteredPorts.count) \(filteredPorts.count == 1 ? "Port" : "Ports")")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !showAll && scanner.ports.count > filteredPorts.count {
                Text("(\(scanner.ports.count - filteredPorts.count) ausgeblendet)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Beenden") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private struct PortRow: View {
    let port: PortInfo
    @ObservedObject var scanner: PortScanner
    @State private var hovering = false
    @State private var confirmStop = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(port.port)")
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                    if port.isDevPort {
                        Text("DEV")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.18))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(port.command)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("PID \(port.pid)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !port.user.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(port.user)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                confirmStop = true
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
            .confirmationDialog(
                "Prozess \u{201E}\(port.command)\u{201C} auf Port \(port.port) beenden?",
                isPresented: $confirmStop,
                titleVisibility: .visible
            ) {
                Button("Beenden (SIGTERM)", role: .destructive) {
                    scanner.stop(pid: port.pid, port: port.port)
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Nach 2 Sekunden wird SIGKILL gesendet, falls der Prozess noch läuft.")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(hovering ? Color.gray.opacity(0.08) : Color.clear)
        .onHover { hovering = $0 }
    }
}
