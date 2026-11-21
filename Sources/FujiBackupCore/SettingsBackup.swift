import Foundation

/// A camera settings backup: the same .DAT file Fujifilm's X Acquire saves.
/// It starts with "FUJIFILM", names the model at 0x14 and holds the camera's serial number at 0x34.
public struct SettingsBackup: Equatable, Sendable {
    public let data: Data
    public let model: String

    static let magic = Data("FUJIFILM".utf8)
    static let modelRange = 0x14..<0x34
    static let maxSize = 1_000_000

    public init(_ data: Data) throws(BackupError) {
        guard data.count > Self.modelRange.upperBound, data.count <= Self.maxSize, data.starts(with: Self.magic) else {
            throw .notABackup
        }
        let raw = data.subdata(in: data.startIndex + Self.modelRange.lowerBound ..< data.startIndex + Self.modelRange.upperBound)
        let model = String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self).trimmingCharacters(in: .whitespaces)
        guard !model.isEmpty else { throw .notABackup }
        self.data = data
        self.model = model
    }

    /// Whether this backup can go back onto a camera whose current backup is `current`, running `firmware`.
    /// `firmware` of this backup is nil when unknown (a file not made by this app).
    public func checkRestore(onto current: SettingsBackup, backupFirmware: String?, cameraFirmware: String) throws(BackupError) {
        guard model == current.model else { throw .otherModel(backup: model, camera: current.model) }
        if let fw = backupFirmware, fw != cameraFirmware { throw .otherFirmware(backup: fw, camera: cameraFirmware) }
        guard data.count == current.data.count else { throw .otherLayout }
    }
}

public enum BackupError: Error, Equatable, LocalizedError {
    case notABackup
    case otherModel(backup: String, camera: String)
    case otherFirmware(backup: String, camera: String)
    case otherLayout

    public var errorDescription: String? {
        switch self {
        case .notABackup: "This file isn’t a Fujifilm settings backup."
        case .otherModel: "This backup is from a different camera model."
        case .otherFirmware: "This backup is from a different firmware version."
        case .otherLayout: "This backup doesn’t match the camera’s settings layout."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notABackup: "Choose a .DAT file saved by this app or by FUJIFILM X Acquire."
        case let .otherModel(b, c): "The backup is from an \(b), but the connected camera is an \(c)."
        case let .otherFirmware(b, c): "The backup was made on firmware \(b), but the camera runs \(c). Only restore backups made on the same firmware."
        case .otherLayout: "Its size differs from the camera’s own backup, so the camera would reject it or misread it."
        }
    }
}

/// Backup file names: "X-T3 5.11 2026-11-21 143012.dat". The firmware in the name is what the restore check uses.
public enum BackupName {
    public static func make(model: String, firmware: String, date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HHmmss"
        return "\(safe(model)) \(safe(firmware)) \(f.string(from: date)).dat"
    }

    /// The firmware recorded in a name made by `make`, or nil.
    public static func firmware(in fileName: String) -> String? {
        let parts = (fileName as NSString).deletingPathExtension.split(separator: " ")
        guard parts.count >= 4, parts[parts.count - 2].count == 10, parts[parts.count - 1].count == 6 else { return nil }
        return String(parts[parts.count - 3])
    }

    private static func safe(_ s: String) -> String {
        String(s.map { $0 == " " || $0 == "/" || $0 == ":" ? "-" : $0 })
    }
}
