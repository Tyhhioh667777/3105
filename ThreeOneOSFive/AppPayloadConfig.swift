//
//  AppPayloadConfig.swift
//  3105
//

import Foundation

enum AppPayloadConfig {

    // MARK: - App đích

    /// Bundle ID của app đích
    static let targetBundleID = "com.dts.freefireth"

    /// Tên hiển thị trên UI
    static let targetDisplayName = "Free Fire"

    // MARK: - Container

    /// 2 = App Data container, 7 = Group container, 13 = System group
    static let containerClass: UInt64 = 2
    static let isGroupContainer = false

    // MARK: - Danh sách file cần dán

    static let payloads: [PayloadSpec] = [
        PayloadSpec(resource: "localConfig",           ext: "json",  destination: nil),
        PayloadSpec(resource: "Assembly-CSharp-patch", ext: "bytes", destination: nil),
    ]

    /// Thư mục chứa file trong bundle
    static let payloadSubdirectory = "Payloads"

    /// Thư mục con trong container app đích
    static let destinationFolder = "Documents"

    // MARK: - Hiển thị

    static let appTitle = "3105"
    static let appSubtitle = "Fixed payload injector"

    /// Dải iOS hỗ trợ hiển thị ngắn gọn trên UI
    static let supportedIOSRange = "17.0 – 18.7.1, 26.0"

    /// Ghi chú kích hoạt trong game
    static let activationNote = "Kích hoạt xong vào game sử dụng 4 ngón tap tay 4 lần vào màn hình để kích hoạt menu trong game"

    /// Icon tùy chỉnh (nil = dùng SF Symbol)
    static let customAppIcon: String? = "FreeFireIcon"

    /// Dev Telegram
    static let developerHandle = "@devhaxios"

    // MARK: - Kiểm tra hỗ trợ iOS

    /// Kiểm tra iOS hiện tại có được exploit hỗ trợ không.
    /// Trả về: `(supported: Bool, message: String)`
    static func checkIOSSupport(major: Int,
                                minor: Int,
                                patch: Int) -> (supported: Bool, message: String) {

        let verStr = "\(major).\(minor).\(patch)"

        // < 17.0 → không hỗ trợ
        if major < 17 {
            return (false, "iOS \(verStr) quá cũ — cần iOS 17.0 trở lên")
        }

        // 17.x → toàn bộ dải đều hỗ trợ
        if major == 17 {
            return (true, "iOS \(verStr) được hỗ trợ")
        }

        // 18.x → hỗ trợ đến 18.7.1
        if major == 18 {
            if minor < 7 {
                return (true, "iOS \(verStr) được hỗ trợ")
            }
            if minor == 7 {
                if patch <= 1 {
                    return (true, "iOS \(verStr) được hỗ trợ")
                }
                return (false, "iOS \(verStr) chưa được hỗ trợ — dải hỗ trợ dừng ở 18.7.1")
            }
            return (false, "iOS \(verStr) chưa được hỗ trợ")
        }

        // 19–25 → không tồn tại (Apple nhảy từ 18 → 26)
        if major < 26 {
            return (false, "iOS \(verStr) không xác định")
        }

        // 26.0.x → hỗ trợ (patch bất kỳ trong 26.0)
        if major == 26 {
            if minor == 0 {
                return (true, "iOS \(verStr) được hỗ trợ")
            }
            return (false, "iOS \(verStr) chưa được hỗ trợ — chỉ hỗ trợ 26.0.x")
        }

        // 27+ → không hỗ trợ
        return (false, "iOS \(verStr) quá mới — chưa có offset exploit")
    }
}

/// Mô tả 1 file cần dán
struct PayloadSpec: Identifiable, Hashable {
    let resource: String
    let ext: String
    let destination: String?

    var id: String { "\(resource).\(ext)" }

    var sourceFilename: String {
        ext.isEmpty ? resource : "\(resource).\(ext)"
    }

    var destinationFilename: String {
        if let destination, !destination.isEmpty { return destination }
        return sourceFilename
    }
}
