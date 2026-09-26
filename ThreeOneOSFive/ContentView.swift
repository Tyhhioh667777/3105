import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var injector: FixedPayloadInjector
    @State private var showLogs = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    payloadListCard
                    toggleCard
                    statusCard
                    exploitCard
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(AppPayloadConfig.appTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showLogs = true } label: {
                        Image(systemName: "apple.terminal")
                    }
                    .accessibilityLabel("Logs")
                }
            }
            .sheet(isPresented: $showLogs) {
                LogView()
            }
        }
        .tint(AppTheme.accent)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AppRowIcon(systemName: "shippingbox.fill", frameSize: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppPayloadConfig.targetDisplayName)
                        .font(.headline)
                    Text(AppPayloadConfig.targetBundleID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            Divider()
            HStack {
                Text("Đích").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Documents/")
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
            }
        }
        .padding(14)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - Payload list

    private var payloadListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("File cần dán")
                    .font(.headline)
                Spacer()
                Text("\(AppPayloadConfig.payloads.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Color(uiColor: .secondarySystemFill),
                        in: Capsule()
                    )
            }

            Divider()

            VStack(spacing: 0) {
                ForEach(Array(AppPayloadConfig.payloads.enumerated()), id: \.element.id) { index, spec in
                    payloadRow(spec: spec)
                    if index < AppPayloadConfig.payloads.count - 1 {
                        Divider().padding(.leading, 24)
                    }
                }
            }
        }
        .padding(14)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func payloadRow(spec: PayloadSpec) -> some View {
        HStack(spacing: 10) {
            statusIcon(for: spec)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(spec.sourceFilename)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text("Documents/\(spec.destinationFilename)")
                        .font(.caption2.monospaced())
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            if let result = injector.results.first(where: { $0.spec.id == spec.id }),
               !result.success,
               result.error != nil {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func statusIcon(for spec: PayloadSpec) -> some View {
        if let result = injector.results.first(where: { $0.spec.id == spec.id }) {
            if result.success {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        } else {
            Image(systemName: "doc.fill")
                .foregroundStyle(AppTheme.accent)
        }
    }

    // MARK: - Toggle

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: toggleBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dán file")
                        .font(.headline)
                    Text("Bật = dán tất cả vào Documents của app đích")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(injector.state.isBusy || !canInteract)

            if injector.state.isBusy {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(injector.state == .injecting
                         ? "Đang dán \(AppPayloadConfig.payloads.count) file…"
                         : "Đang xóa…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { injector.state.isActive },
            set: { newValue in
                if newValue { injector.inject() } else { injector.clean() }
            }
        )
    }

    private var canInteract: Bool {
        KernelExploit.hasSandboxAccess() || appState.exploitStatus.isSuccess
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(stateTitle, systemImage: stateIcon)
                .font(.headline)
                .foregroundStyle(stateColor)

            if let msg = injector.lastMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let failedResults = injector.results.filter { !$0.success }
            if !failedResults.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(failedResults) { result in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.spec.destinationFilename)
                                    .font(.caption.weight(.semibold))
                                if let error = result.error {
                                    Text(error)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.red.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            }

            if case .failed = injector.state {
                Button("Dọn sạch trạng thái") {
                    injector.forceClean()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var stateTitle: String {
        switch injector.state {
        case .idle:              return "Chưa dán"
        case .injecting:         return "Đang dán"
        case .active:            return "Đã dán"
        case .cleaning:          return "Đang xóa"
        case .partial(let info): return "Một phần: \(info)"
        case .failed:            return "Lỗi"
        }
    }

    private var stateIcon: String {
        switch injector.state {
        case .idle:        return "circle"
        case .injecting:   return "arrow.down.circle"
        case .active:      return "checkmark.circle.fill"
        case .cleaning:    return "trash.circle"
        case .partial:     return "exclamationmark.circle.fill"
        case .failed:      return "exclamationmark.triangle.fill"
        }
    }

    private var stateColor: Color {
        switch injector.state {
        case .idle:                 return .secondary
        case .injecting, .cleaning: return .orange
        case .active:               return .green
        case .partial:              return .orange
        case .failed:               return .red
        }
    }

    // MARK: - Exploit

    private var exploitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(exploitTitle, systemImage: exploitIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(exploitColor)

            if appState.kernelExploitRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Đang chạy kernel exploit…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let unsupported = appState.unsupportedMessage {
                Text("iOS không được hỗ trợ: \(unsupported)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var exploitTitle: String {
        if appState.kernelExploitRunning { return "Kernel exploit đang chạy" }
        if appState.unsupportedMessage != nil { return "Không hỗ trợ" }
        if KernelExploit.hasSandboxAccess() { return "Sandbox escape: ACTIVE" }
        if appState.exploitStatus.isSuccess { return "Kernel exploit: OK" }
        if appState.exploitStatus.isFailed { return "Kernel exploit: THẤT BẠI" }
        return "Chưa chạy exploit"
    }

    private var exploitIcon: String {
        if KernelExploit.hasSandboxAccess() { return "checkmark.shield.fill" }
        if appState.unsupportedMessage != nil { return "xmark.octagon.fill" }
        if appState.exploitStatus.isFailed { return "xmark.octagon.fill" }
        if appState.kernelExploitRunning { return "hourglass" }
        return "shield"
    }

    private var exploitColor: Color {
        if KernelExploit.hasSandboxAccess() { return .green }
        if appState.unsupportedMessage != nil { return .red }
        if appState.exploitStatus.isFailed { return .red }
        return .secondary
    }
}
