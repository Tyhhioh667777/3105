import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var injector: FixedPayloadInjector
    @ObservedObject private var auth = AuthService.shared

    @State private var showLogs = false

    // Login form state
    @State private var keyInput: String = ""
    @State private var loginMessage: String = ""
    @State private var loginMessageIsError: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    infoCard
                    authCard
                    if auth.isValid {
                        appCard
                        statusCard
                    }
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
                }
            }
            .sheet(isPresented: $showLogs) { LogView() }
        }
        .tint(AppTheme.accent)
        .onAppear {
            // Auto-login khi mở app
            _ = AuthService.shared.autoLoginIfPossible()
        }
    }

    // MARK: - Info

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(icon: "person.crop.circle.fill", title: "Developer", value: "@devhaxios")
            Divider()
            row(icon: "app.badge.fill", title: "Ứng dụng",
                value: "\(AppPayloadConfig.appTitle) · v\(appVersion)")
            Divider()
            row(icon: "iphone", title: "Thiết bị",
                value: "\(AppInfo.machineName) · iOS \(AppInfo.osVersion)")
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold)).lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
    }

    // MARK: - Auth

    @ViewBuilder
    private var authCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if auth.isValid {
                loggedInView
            } else {
                loginView
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var loggedInView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đã đăng nhập").font(.headline).foregroundStyle(.green)
                    Text("Tài khoản: \(auth.currentUser)").font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    auth.logout()
                    loginMessage = ""
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }
            Divider()
            HStack {
                Label("Hết hạn", systemImage: "calendar")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(auth.expiryDate.isEmpty ? "—" : auth.expiryDate)
                    .font(.caption.monospaced())
            }
            HStack {
                Label("Còn lại", systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(auth.remainingDays) ngày")
                    .font(.caption.monospaced())
                    .foregroundStyle(auth.remainingDays <= 3 ? .orange : .primary)
            }
        }
    }

    private var loginView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đăng nhập").font(.headline)
                    Text("Nhập key để kích hoạt").font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                TextField("Nhập key...", text: $keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .submitLabel(.go)
                    .disabled(auth.isLoggingIn)
                    .onSubmit { performLogin() }

                Button { performLogin() } label: {
                    if auth.isLoggingIn {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Đăng nhập").font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty
                          || auth.isLoggingIn)
            }

            if !loginMessage.isEmpty {
                Text(loginMessage)
                    .font(.caption)
                    .foregroundStyle(loginMessageIsError ? .red : .green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func performLogin() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        loginMessage = ""
        Task {
            await AuthService.shared.login(key: trimmed)
            if AuthService.shared.isValid {
                loginMessage = "Đăng nhập thành công"
                loginMessageIsError = false
                keyInput = ""
            } else {
                loginMessage = "Đăng nhập thất bại. Kiểm tra lại key hoặc mạng."
                loginMessageIsError = true
            }
        }
    }

    // MARK: - App + Toggle

    private var appCard: some View {
        HStack(spacing: 12) {
            appIcon
            VStack(alignment: .leading, spacing: 3) {
                Text(AppPayloadConfig.targetDisplayName)
                    .font(.headline).lineLimit(1)
                Text(AppPayloadConfig.targetBundleID)
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
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
        .background(Color(uiColor: .systemBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var appIcon: some View {
        if let name = AppPayloadConfig.customAppIcon, let img = UIImage(named: name) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
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

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { injector.state.isActive },
            set: { newValue in
                guard auth.isValid else { return }
                if newValue { injector.inject() } else { injector.clean() }
            }
        )
    }

    private var canInteract: Bool {
        auth.isValid && (KernelExploit.hasSandboxAccess()
                         || appState.exploitStatus.isSuccess)
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(stateTitle, systemImage: stateIcon)
                .font(.headline).foregroundStyle(stateColor)

            if let msg = injector.lastMessage {
                Text(msg).font(.subheadline).foregroundStyle(.secondary)
            }

            let failed = injector.results.filter { !$0.success }
            if !failed.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(failed) { r in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.spec.destinationFilename)
                                    .font(.caption.weight(.semibold))
                                if let e = r.error {
                                    Text(e).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if case .failed = injector.state {
                Button("Dọn sạch trạng thái") { injector.forceClean() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .systemBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var stateTitle: String {
        switch injector.state {
        case .idle: return "Chưa Kích hoạt"
        case .injecting: return "Đang Kích Hoạt"
        case .active: return "Đã Kích Hoạt"
        case .cleaning: return "Đang xóa"
        case .partial(let s): return "Một phần: \(s)"
        case .failed: return "Lỗi"
        }
    }
    private var stateIcon: String {
        switch injector.state {
        case .idle: return "circle"
        case .injecting: return "arrow.down.circle"
        case .active: return "checkmark.circle.fill"
        case .cleaning: return "trash.circle"
        case .partial: return "exclamationmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    private var stateColor: Color {
        switch injector.state {
        case .idle: return .secondary
        case .injecting, .cleaning: return .orange
        case .active: return .green
        case .partial: return .orange
        case .failed: return .red
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
                    Text("Đang chạy kernel exploit…").font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let u = appState.unsupportedMessage {
                Text("iOS không được hỗ trợ: \(u)").font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .systemBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }
}
