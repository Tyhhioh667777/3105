import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var injector: FixedPayloadInjector
    @State private var showLogs = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    infoCard
                    appCard
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

    // MARK: - Info (dev + app + device)

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Developer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("@devhaxios")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "app.badge.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ứng dụng")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(AppPayloadConfig.appTitle) · v\(appVersion)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "iphone")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thiết bị")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(AppInfo.machineName) · iOS \(AppInfo.osVersion)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - App + Toggle (gộp 1 hàng)

    private var appCard: some View {
        HStack(spacing: 12) {
            appIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(AppPayloadConfig.targetDisplayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(AppPayloadConfig.targetBundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: toggleBinding)
                .labelsHidden()
                .disabled(injector.state.isBusy || !canInteract)

            if injector.state.isBusy {
                ProgressView().controlSize(.small)
            }
        }
        .padding(14)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - App Icon

    @ViewBuilder
    private var appIcon: some View {
        if let customIcon = AppPayloadConfig.customAppIcon {
            // Icon tùy chỉnh từ Assets
            Image(customIcon)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if let uiIcon = UIImage(named: "AppPayloadIcon") {
            // Fallback: tìm ảnh tên AppPayloadIcon trong Assets
            Image(uiImage: uiIcon)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            // Fallback cuối: SF Symbol
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.15))
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 44, height: 44)
        }
    }

    // MARK: - Toggle binding

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
        case .idle:              return "Chưa Kích hoạt"
        case .injecting:         return "Đang Kích Hoạt"
        case .active:            return "Đã Kích Hoạt"
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

    // MARK: - App version

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }
}
