import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var scanner: PortScanner
    var openWindow: (() -> Void)? = nil
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
            if let openWindow = openWindow {
                Button {
                    openWindow()
                } label: {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.borderless)
                .help("Im Fenster öffnen")
            }
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

struct WindowContentView: View {
    @ObservedObject var scanner: PortScanner
    @State private var showAll = false
    @State private var searchText = ""
    @State private var timer: Timer?
    @State private var sortAscending = true

    private var filteredPorts: [PortInfo] {
        var ports = showAll ? scanner.ports : scanner.ports.filter { $0.isDevPort }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            ports = ports.filter { p in
                "\(p.port)".contains(q)
                    || p.command.lowercased().contains(q)
                    || "\(p.pid)".contains(q)
                    || p.user.lowercased().contains(q)
            }
        }
        return ports.sorted { sortAscending ? $0.port < $1.port : $0.port > $1.port }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if let err = scanner.lastError {
                errorView(err)
            } else if filteredPorts.isEmpty {
                emptyView
            } else {
                portTable
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 520, minHeight: 360)
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

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Suchen (Port, Prozess, PID)", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 280)

            Toggle(isOn: $showAll) {
                Text("Alle Ports")
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Spacer()

            Button {
                scanner.refresh()
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var portTable: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    headerCell("Port", width: 80) {
                        sortAscending.toggle()
                    } trailing: {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    headerCell("Typ", width: 70)
                    headerCell("Prozess", width: 180, alignment: .leading)
                    headerCell("PID", width: 80)
                    headerCell("User", width: 100, alignment: .leading)
                    Spacer(minLength: 0)
                    headerCell("Aktion", width: 200, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.06))

                Divider()

                ForEach(filteredPorts) { port in
                    PortTableRow(port: port, scanner: scanner)
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func headerCell(
        _ title: String,
        width: CGFloat,
        alignment: Alignment = .center,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> some View = { EmptyView() }
    ) -> some View {
        let content = HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            trailing()
        }
        .frame(width: width, alignment: alignment)

        if let action = action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func errorView(_ err: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.largeTitle)
            Text(err)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.largeTitle)
            Text(searchText.isEmpty
                 ? (showAll ? "Keine belegten Ports" : "Keine Dev-Ports belegt")
                 : "Keine Treffer für „\(searchText)\u{201C}")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBar: some View {
        HStack {
            Text("\(filteredPorts.count) \(filteredPorts.count == 1 ? "Eintrag" : "Einträge")")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !showAll && scanner.ports.count > filteredPorts.count {
                Text("(\(scanner.ports.count - filteredPorts.count) ausgeblendet)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if scanner.isScanning {
                ProgressView()
                    .controlSize(.mini)
            }
            Text("Auto-Refresh: 3 s")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
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
            if PortScanner.likelyHttpPort(port.port) {
                Button {
                    PortScanner.openInBrowser(port: port.port)
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("http://localhost:\(port.port) öffnen")
            }
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

private struct PortTableRow: View {
    let port: PortInfo
    @ObservedObject var scanner: PortScanner
    @State private var hovering = false
    @State private var confirmStop = false

    var body: some View {
        HStack(spacing: 0) {
            Text("\(port.port)")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(width: 80)
            Group {
                if port.isDevPort {
                    Text("DEV")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.18))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 70)
            Text(port.command)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 180, alignment: .leading)
            Text("\(port.pid)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80)
            Text(port.user)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if PortScanner.likelyHttpPort(port.port) {
                    Button {
                        PortScanner.openInBrowser(port: port.port)
                    } label: {
                        Label("Öffnen", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("http://localhost:\(port.port) im Browser öffnen")
                } else {
                    Spacer()
                        .frame(width: 80)
                }
                Button {
                    confirmStop = true
                } label: {
                    Label("Stop", systemImage: "stop.fill")
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
            .frame(width: 200, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(hovering ? Color.gray.opacity(0.06) : Color.clear)
        .onHover { hovering = $0 }
    }
}
