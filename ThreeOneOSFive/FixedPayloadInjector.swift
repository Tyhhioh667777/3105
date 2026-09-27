//
//  FixedPayloadInjector.swift
//  3105
//

import Foundation
import UIKit

final class FixedPayloadInjector: ObservableObject {

    // MARK: - State

    enum State: Equatable {
        case idle
        case injecting
        case active
        case cleaning
        case partial(String)
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .injecting, .cleaning: return true
            default: return false
            }
        }

        var isActive: Bool {
            switch self {
            case .active, .partial: return true
            default: return false
            }
        }
    }

    struct FileResult: Identifiable {
        let id = UUID()
        let spec: PayloadSpec
        let success: Bool
        let destinationPath: String?
        let error: String?
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var results: [FileResult] = []
    @Published private(set) var lastMessage: String?

    // MARK: - Persistence

    private enum Keys {
        static let installedPaths = "fixedInjector.installedPaths"
        static let active         = "fixedInjector.active"
    }

    private let defaults = UserDefaults.standard
    private var installedPaths: [String] = []

    // MARK: - Init

    init() {
        if defaults.bool(forKey: Keys.active),
           let stored = defaults.stringArray(forKey: Keys.installedPaths),
           !stored.isEmpty {
            self.installedPaths = stored
            self.state = .active
            self.lastMessage = "Khôi phục từ phiên trước (\(stored.count) file)"
            log("injector: restored \(stored.count) paths from previous session")
        }
    }

    // MARK: - Public API

    /// BẬT: dán tất cả file → tự động mở game
    func inject() {
        guard !state.isBusy else { return }
        state = .injecting
        lastMessage = nil
        results = []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let outcome = self.performInjectAll()
            DispatchQueue.main.async {
                self.results = outcome.results

                if outcome.successCount == 0 {
                    // Thất bại toàn bộ → không mở game
                    self.state = .failed(outcome.results.first?.error ?? "Không dán được file nào")
                    self.lastMessage = "Thất bại toàn bộ"
                } else if outcome.failureCount > 0 {
                    // Thành công 1 phần → vẫn mở game
                    self.state = .partial("\(outcome.successCount)/\(outcome.totalCount) file thành công")
                    self.lastMessage = "Đã dán \(outcome.successCount) file · Đang mở game..."
                    self.persist(paths: outcome.installedPaths)
                    self.launchTargetAppAfterDelay()
                } else {
                    // Thành công toàn bộ → mở game
                    self.state = .active
                    self.lastMessage = "Đã dán \(outcome.successCount) file · Đang mở game..."
                    self.persist(paths: outcome.installedPaths)
                    self.launchTargetAppAfterDelay()
                }
            }
        }
    }

    /// TẮT: xóa tất cả file đã dán → không mở game
    func clean() {
        guard !state.isBusy else { return }
        state = .cleaning
        lastMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let outcome = self.performCleanAll()
            DispatchQueue.main.async {
                self.installedPaths = []
                self.results = []
                self.defaults.set(false, forKey: Keys.active)
                self.defaults.removeObject(forKey: Keys.installedPaths)

                if outcome.failureCount == 0 {
                    self.state = .idle
                    self.lastMessage = "Đã xóa \(outcome.successCount) file"
                } else {
                    self.state = .failed("\(outcome.failureCount) file không xóa được")
                    self.lastMessage = outcome.errors.joined(separator: "\n")
                }
            }
        }
    }

    /// Xóa state khi bị lệch (dùng khi debug)
    func forceClean() {
        state = .idle
        results = []
        lastMessage = nil
        installedPaths = []
        defaults.set(false, forKey: Keys.active)
        defaults.removeObject(forKey: Keys.installedPaths)
        log("injector: force cleaned")
    }

    // MARK: - Inject All

    private struct InjectOutcome {
        let results: [FileResult]
        let installedPaths: [String]
        let successCount: Int
        let failureCount: Int
        var totalCount: Int { results.count }
    }

    private func performInjectAll() -> InjectOutcome {
        var results: [FileResult] = []
        var installed: [String] = []

        // 1. Sandbox escape?
        guard KernelExploit.hasSandboxAccess() else {
            let error = "Sandbox escape chưa active. Đợi kernel exploit chạy xong."
            for spec in AppPayloadConfig.payloads {
                results.append(FileResult(spec: spec, success: false,
                                          destinationPath: nil, error: error))
            }
            return InjectOutcome(results: results, installedPaths: [],
                                 successCount: 0, failureCount: results.count)
        }

        // 2. Resolve container
        guard let containerPath = resolveContainerPath() else {
            let error = "Không lấy được container của \(AppPayloadConfig.targetBundleID)."
            for spec in AppPayloadConfig.payloads {
                results.append(FileResult(spec: spec, success: false,
                                          destinationPath: nil, error: error))
            }
            return InjectOutcome(results: results, installedPaths: [],
                                 successCount: 0, failureCount: results.count)
        }
        log("injector: container = \(containerPath)")

        let destinationDir = (containerPath as NSString)
            .appendingPathComponent(AppPayloadConfig.destinationFolder)

        // 3. Đảm bảo thư mục đích
        if !FileManager.default.fileExists(atPath: destinationDir) {
            do {
                try FileManager.default.createDirectory(
                    atPath: destinationDir,
                    withIntermediateDirectories: true
                )
                log("injector: created directory \(destinationDir)")
            } catch {
                let err = "Không tạo được thư mục \(destinationDir): \(error.localizedDescription)"
                for spec in AppPayloadConfig.payloads {
                    results.append(FileResult(spec: spec, success: false,
                                              destinationPath: nil, error: err))
                }
                return InjectOutcome(results: results, installedPaths: [],
                                     successCount: 0, failureCount: results.count)
            }
        }

        // 4. Dán từng file
        for spec in AppPayloadConfig.payloads {
            let result = injectOne(spec: spec, destinationDir: destinationDir)
            results.append(result)
            if result.success, let path = result.destinationPath {
                installed.append(path)
            }
        }

        let successCount = results.filter(\.success).count
        let failureCount = results.count - successCount

        return InjectOutcome(
            results: results,
            installedPaths: installed,
            successCount: successCount,
            failureCount: failureCount
        )
    }

    private func injectOne(spec: PayloadSpec, destinationDir: String) -> FileResult {
        guard let sourceURL = locatePayload(spec: spec) else {
            let err = "Không tìm thấy \(spec.sourceFilename) trong bundle"
            log("injector: \(err)")
            return FileResult(spec: spec, success: false,
                              destinationPath: nil, error: err)
        }

        guard let data = try? Data(contentsOf: sourceURL) else {
            let err = "Không đọc được \(spec.sourceFilename)"
            log("injector: \(err)")
            return FileResult(spec: spec, success: false,
                              destinationPath: nil, error: err)
        }

        let destination = (destinationDir as NSString)
            .appendingPathComponent(spec.destinationFilename)

        do {
            try data.write(to: URL(fileURLWithPath: destination), options: .atomic)
            log("injector: wrote \(spec.sourceFilename) → \(destination) (\(data.count) bytes)")
            return FileResult(spec: spec, success: true,
                              destinationPath: destination, error: nil)
        } catch {
            let err = "Ghi \(spec.destinationFilename) thất bại: \(error.localizedDescription)"
            log("injector: \(err)")
            return FileResult(spec: spec, success: false,
                              destinationPath: nil, error: err)
        }
    }

    // MARK: - Clean All

    private struct CleanOutcome {
        let successCount: Int
        let failureCount: Int
        let errors: [String]
    }

    private func performCleanAll() -> CleanOutcome {
        var success = 0
        var failures = 0
        var errors: [String] = []

        var paths = installedPaths
        if paths.isEmpty {
            if let containerPath = resolveContainerPath() {
                let destinationDir = (containerPath as NSString)
                    .appendingPathComponent(AppPayloadConfig.destinationFolder)
                paths = AppPayloadConfig.payloads.map {
                    (destinationDir as NSString).appendingPathComponent($0.destinationFilename)
                }
            }
        }

        guard KernelExploit.hasSandboxAccess() else {
            return CleanOutcome(
                successCount: 0,
                failureCount: paths.count,
                errors: ["Sandbox escape chưa active — không thể xóa."]
            )
        }

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                    log("injector: removed \(path)")
                    success += 1
                } catch {
                    failures += 1
                    errors.append("Xóa \(path) thất bại: \(error.localizedDescription)")
                    log("injector: delete failed \(path) — \(error.localizedDescription)")
                }
            } else {
                log("injector: file not found, skip \(path)")
                success += 1
            }
        }

        return CleanOutcome(successCount: success,
                            failureCount: failures,
                            errors: errors)
    }

    // MARK: - Launch Target App

    /// Đợi 0.8s cho UI kịp update rồi mở game
    private func launchTargetAppAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.launchTargetApp()
        }
    }

    /// Mở app đích (Free Fire)
    private func launchTargetApp() {
        let bundleID = AppPayloadConfig.targetBundleID
        log("injector: launching target app \(bundleID)")

        // Cách 1: private API (ưu tiên — không cần Info.plist)
        if launchViaPrivateAPI(bundleID: bundleID) {
            log("injector: launched via LSApplicationWorkspace")
            return
        }

        // Cách 2: fallback URL scheme
        if let scheme = urlSchemeForBundle(bundleID) {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:]) { success in
                        log("injector: URL scheme open result = \(success)")
                    }
                }
                log("injector: launched via URL scheme \(scheme)")
                return
            }
        }

        log("injector: failed to launch \(bundleID)")
    }

    /// Dùng LSApplicationWorkspace (private API) để mở app theo bundle ID
    private func launchViaPrivateAPI(bundleID: String) -> Bool {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else {
            return false
        }

        let defaultSelector = NSSelectorFromString("defaultWorkspace")
        guard workspaceClass.responds(to: defaultSelector) else { return false }
        guard let workspace = workspaceClass.perform(defaultSelector)?
            .takeUnretainedValue() as? NSObject else { return false }

        let openSelector = NSSelectorFromString("openApplicationWithBundleID:")
        guard workspace.responds(to: openSelector) else { return false }

        _ = workspace.perform(openSelector, with: bundleID as NSString)
        return true
    }

    /// Map bundle ID → URL scheme (fallback khi private API fail)
    private func urlSchemeForBundle(_ bundleID: String) -> String? {
        switch bundleID {
        case "com.dts.freefireth":
            return "freefireth://"
        case "com.dts.freefiremax":
            return "freefiremax://"
        case "com.apple.MobileSMS":
            return "sms://"
        case "com.apple.mobilesafari":
            return "https://"
        default:
            return nil
        }
    }

    // MARK: - Persistence

    private func persist(paths: [String]) {
        installedPaths = paths
        defaults.set(true, forKey: Keys.active)
        defaults.set(paths, forKey: Keys.installedPaths)
    }

    // MARK: - Bundle lookup

    private func locatePayload(spec: PayloadSpec) -> URL? {
        if let url = Bundle.main.url(
            forResource: spec.resource,
            withExtension: spec.ext.isEmpty ? nil : spec.ext,
            subdirectory: AppPayloadConfig.payloadSubdirectory
        ) {
            return url
        }
        if let url = Bundle.main.url(
            forResource: spec.resource,
            withExtension: spec.ext.isEmpty ? nil : spec.ext
        ) {
            return url
        }
        return nil
    }

    // MARK: - Container resolution

    private func resolveContainerPath() -> String? {
        var mcmError: NSString?
        if let path = MCMActivateContainerPath(
            AppPayloadConfig.containerClass,
            AppPayloadConfig.targetBundleID,
            AppPayloadConfig.isGroupContainer,
            &mcmError
        ) {
            log("injector: MCM resolved path = \(path)")
            return path
        }
        log("injector: MCM failed — \(mcmError ?? "unknown")")

        let plist = "/var/mobile/Library/MobileContainerManager/Containers.plist"
        if let dict = NSDictionary(contentsOfFile: plist) as? [String: Any],
           let entry = dict[AppPayloadConfig.targetBundleID] as? [String: Any],
           let uuid = entry["Data"] as? String {
            let p = "/var/mobile/Containers/Data/Application/\(uuid)"
            log("injector: plist path = \(p)")
            return p
        }

        return nil
    }
}
