import Foundation
import CryptoKit

/// Quản lý đăng nhập / license key.
/// Chuyển thể từ Login.mm (ObjC++) sang Swift thuần.
final class AuthService: ObservableObject {

    static let shared = AuthService()

    // MARK: - Published state (UI bind)

    @Published private(set) var isValid: Bool = false
    @Published private(set) var currentUser: String = ""
    @Published private(set) var expiryDate: String = ""
    @Published private(set) var remainingDays: Int = 0
    @Published private(set) var isLoggingIn: Bool = false

    // MARK: - Config

    /// URL server auth — chia nhỏ để tránh scan string
    private var authURL: URL {
        let p1 = "https://"
        let p2 = "lyngocdiem.online"
        let p3 = "/auth-ios.php"
        return URL(string: p1 + p2 + p3)!
    }

    /// Version gửi lên server
    private let clientVersion = "IOS"

    /// Secret dùng cho checksum (giống C++ code)
    private let secretKey = "ThienXMod2024SecretKey"

    /// Key lưu trữ
    private let savedKeyStorageKey = "auth.savedKey"
    private let savedTimeStorageKey = "auth.savedTime"

    private init() {}

    // MARK: - Bootstrap

    /// Gọi khi app khởi động. Đọc key đã lưu, nếu có → tự động đăng nhập.
    @discardableResult
    func autoLoginIfPossible() -> Bool {
        guard let savedKey = loadSavedKey(), !savedKey.isEmpty else {
            log("auth: no saved key")
            return false
        }
        log("auth: found saved key, attempting auto-login")
        Task {
            await login(key: savedKey, isAutoLogin: true)
        }
        return true
    }

    // MARK: - Login

    @MainActor
    func login(key: String, isAutoLogin: Bool = false) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            log("auth: empty key")
            return
        }

        isLoggingIn = true
        defer { isLoggingIn = false }

        let deviceID = Self.getDeviceID()
        let checksum = Self.generateChecksum(userKey: trimmed,
                                             deviceID: deviceID,
                                             secret: secretKey)

        log("auth: sending login request (auto=\(isAutoLogin))")

        let result = await sendLoginRequest(
            userKey: trimmed,
            deviceUUID: deviceID,
            deviceID: deviceID,
            checksum: checksum
        )

        switch result {
        case .success(let response):
            self.isValid = true
            self.currentUser = response.username ?? "User"
            self.expiryDate = response.expiry ?? "—"
            self.remainingDays = response.remainingDays ?? 0
            saveKey(trimmed)
            log("auth: login OK user=\(currentUser) days=\(remainingDays)")

        case .failure(let error):
            self.isValid = false
            log("auth: login FAILED — \(error.message)")
            // Không xóa key đã lưu nếu lỗi mạng; chỉ xóa nếu key invalid
            if error.shouldClearSavedKey {
                clearSavedKey()
            }
        }
    }

    // MARK: - Logout

    func logout() {
        clearSavedKey()
        isValid = false
        currentUser = ""
        expiryDate = ""
        remainingDays = 0
        log("auth: logged out")
    }

    // MARK: - Storage

    private func saveKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: savedKeyStorageKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: savedTimeStorageKey)
    }

    private func loadSavedKey() -> String? {
        UserDefaults.standard.string(forKey: savedKeyStorageKey)
    }

    private func clearSavedKey() {
        UserDefaults.standard.removeObject(forKey: savedKeyStorageKey)
        UserDefaults.standard.removeObject(forKey: savedTimeStorageKey)
    }

    // MARK: - Device ID

    static func getDeviceID() -> String {
        let uuid = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let name = UIDevice.current.name
        let version = UIDevice.current.systemVersion
        return md5(uuid + name + version)
    }

    // MARK: - Checksum

    static func generateChecksum(userKey: String,
                                 deviceID: String,
                                 secret: String) -> String {
        // timestamp = giờ (floor) — giống C++ code
        let timestamp = Int(Date().timeIntervalSince1970 / 3600)
        let dynamicSalt = String(md5(deviceID + secret).prefix(8))
        let raw = dynamicSalt + userKey + deviceID + String(timestamp) + secret + dynamicSalt
        return md5(raw)
    }

    // MARK: - HTTP request

    private struct LoginSuccess {
        let username: String?
        let expiry: String?
        let remainingDays: Int?
    }

    private struct LoginError: Error {
        let message: String
        let shouldClearSavedKey: Bool
    }

    private enum LoginResult {
        case success(LoginSuccess)
        case failure(LoginError)
    }

    private func sendLoginRequest(userKey: String,
                                  deviceUUID: String,
                                  deviceID: String,
                                  checksum: String) async -> LoginResult {

        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/x-www-form-urlencoded",
                         forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "uname":     userKey,
            "cs":        deviceUUID,
            "device_id": deviceID,
            "checksum":  checksum,
            "version":   clientVersion,
            "action":    "login",
        ]

        let body = params
            .map { "\($0.key)=\(urlEncode($0.value))" }
            .joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                return .failure(LoginError(message: "Không nhận được phản hồi HTTP",
                                           shouldClearSavedKey: false))
            }

            guard (200..<300).contains(http.statusCode) else {
                return .failure(LoginError(message: "Server lỗi (\(http.statusCode))",
                                           shouldClearSavedKey: false))
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(LoginError(message: "JSON không hợp lệ",
                                           shouldClearSavedKey: false))
            }

            guard let status = json["status"] as? String else {
                return .failure(LoginError(message: "Server response thiếu status",
                                           shouldClearSavedKey: false))
            }

            switch status {
            case "success":
                let success = LoginSuccess(
                    username: json["username"] as? String,
                    expiry: json["expiry"] as? String,
                    remainingDays: json["remaining_days"] as? Int
                )
                return .success(success)

            case "expired":
                return .failure(LoginError(message: "Key hết hạn",
                                           shouldClearSavedKey: true))

            case "invalid":
                let reason = json["reason"] as? String ?? "Key không hợp lệ"
                return .failure(LoginError(message: reason,
                                           shouldClearSavedKey: true))

            case "device_mismatch":
                let reason = json["reason"] as? String ?? "Quá số lượng thiết bị cho phép"
                return .failure(LoginError(message: reason,
                                           shouldClearSavedKey: true))

            default:
                let reason = json["reason"] as? String ?? "Đăng nhập thất bại"
                return .failure(LoginError(message: reason,
                                           shouldClearSavedKey: false))
            }
        } catch let urlError as URLError {
            return .failure(LoginError(message: "Lỗi mạng: \(urlError.localizedDescription)",
                                       shouldClearSavedKey: false))
        } catch {
            return .failure(LoginError(message: "Lỗi: \(error.localizedDescription)",
                                       shouldClearSavedKey: false))
        }
    }

    // MARK: - Helpers

    private func urlEncode(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?+")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    // MARK: - MD5 (dùng CryptoKit)

    static func md5(_ input: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
