import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var injector: FixedPayloadInjector
    @ObservedObject private var auth = AuthService.shared

    @State private var showLogs = false
    @State private var keyInput: String = ""
    @State private var loginMessage: String = ""
    @State private var loginMessageIsError: Bool = false

    private let telegramURL = URL(string: "https://t.me/tizffchat")!

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
                    buyKeyButton
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
        .onAppear {
            _ = AuthService.shared.autoLoginIfPossible()
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        let version = AppInfo.versionTuple
        let support = AppPayloadConfig.checkIOSSupport(
            major: version.major,
            minor: version.minor,
            patch: version.patch
        )

        return VStack(alignment: .leading, spacing: 10) {
            row(icon: "person.crop.circle.fill",
                title: "Developer",
                value: AppPayloadConfig.developerHandle)

            Divider()

            row(icon: "app.badge.fill",
                title: "Ứng dụng",
                value: "\(AppPayloadConfig.appTitle) · v\(appVersion)")

            Divider()

            row(icon: "iphone",
                title: "Thiết bị",
                value: "\(AppInfo.machineName) · iOS \(AppInfo.osVersion)")

            Divider()

            iosSupportRow(support: support)
        }
        .padding(14)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
    }

    /// Row riêng cho trạng thái iOS hỗ trợ — có màu xanh/đỏ + ghi chú
    private func iosSupportRow(support: (supported: Bool, message: String)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: support.supported
                      ? "checkmark.seal.fill"
                      : "xmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(support.supported ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trạng thái iOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(support.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(support.supported ? .green : .red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            // Dòng phụ: dải hỗ trợ chung
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Dải hỗ trợ: \(AppPayloadConfig.supportedIOSRange)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 30)
        }
    }

    // MARK: - Auth Card

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
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var loggedInView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đã đăng nhập")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("Tài khoản: \(auth.currentUser.isEmpty ? "User" : auth.currentUser)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    auth.logout()
                    loginMessage = ""
                    log("user: logged out")
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack {
                Label("Hết hạn", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(auth.expiryDate.isEmpty ? "—" : auth.expiryDate)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
            }

            HStack {
                Label("Còn lại", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Text("Đăng nhập")
                        .font(.headline)
                    Text("Nhập key để kích hoạt")
                        .font(.caption)
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

                Button {
                    performLogin()
                } label: {
                    if auth.isLoggingIn {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Đăng nhập")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    keyInput.trimmingCharacters(in: .whitespaces).isEmpty
                    || auth.isLoggingIn
                )
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
                log("user: login success")
            } else {
                loginMessage = "Đăng nhập thất bại. Kiểm tra lại key hoặc mạng."
                loginMessageIsError = true
                log("user: login failed")
            }
        }
    }

    // MARK: - App + Toggle Card (có ghi chú)

    private var appCard: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 1)

                Text(AppPayloadConfig.activationNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    @ViewBuilder
    private var appIcon: some View {
        if let name = AppPayloadConfig.customAppIcon, let img = UIImage(named: name) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
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
                if newValue {
                    injector.inject()
                } else {
                    injector.clean()
                }
            }
        )
    }

    private var canInteract: Bool {
        auth.isValid && (KernelExploit.hasSandboxAccess()
                         || appState.exploitStatus.isSuccess)
    }

    // MARK: - Status Card

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

            let failed = injector.results.filter { !$0.success }
            if !failed.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(failed) { r in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.spec.destinationFilename)
                                    .font(.caption.weight(.semibold))
                                if let e = r.error {
                                    Text(e)
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

    // MARK: - Exploit Card

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

    // MARK: - Buy Key Button

    private var buyKeyButton: some View {
        Button {
            UIApplication.shared.open(telegramURL)
            log("user: opened Telegram buy-key link")
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Lấy Key")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Tham gia Telegram để nhận key")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.55, blue: 0.85),
                        Color(red: 0.10, green: 0.70, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mở Telegram lấy key")
    }

    // MARK: - App Version

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }
}
