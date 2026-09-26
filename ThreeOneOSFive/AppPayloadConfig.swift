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
    //
    // Mỗi entry = 1 file cần dán vào Documents/ của app đích.
    // - resource:    tên file KHÔNG có đuôi (khớp với file trong Payloads/)
    // - ext:         đuôi file (không dấu chấm). "" nếu không có đuôi.
    // - destination: tên file khi ghi vào app đích. nil = giữ nguyên.
    //
    static let payloads: [PayloadSpec] = [
        PayloadSpec(resource: "localConfig", ext: "json",   destination: nil),
        PayloadSpec(resource: "Assembly-CSharp-patch",   ext: "bytes", destination: nil),
        //PayloadSpec(resource: "payload",  ext: "bin",   destination: nil),
    ]

    /// Thư mục chứa file trong bundle
    static let payloadSubdirectory = "Payloads"

    /// Thư mục con bên trong container app đích
    static let destinationFolder = "Documents"

    // MARK: - UI
    static let appTitle = "3105"
    static let appSubtitle = "Fixed payload injector"
}

/// Mô tả 1 file cần dán.
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