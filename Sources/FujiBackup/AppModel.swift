import Foundation
import FujiBackupCore

@MainActor @Observable
final class AppModel {
    enum Activity: Equatable { case backingUp, restoring }

    struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    struct PendingRestore: Identifiable {
        let id = UUID()
        let url: URL
        let backup: SettingsBackup
        let firmware: String?
    }

    let link: CameraLink
    let library: BackupLibrary
    private(set) var activity: Activity?
    var notice: Notice?
    var pendingRestore: PendingRestore?
    var selection: BackupLibrary.Item.ID?
    var viewing: BackupLibrary.Item?

    var canBackUp: Bool { activity == nil && link.info != nil }

    init(library: BackupLibrary = BackupLibrary(), link: CameraLink = CameraLink()) {
        self.library = library
        self.link = link
        library.reload()
    }

    func backUp() async {
        activity = .backingUp
        defer { activity = nil }
        do {
            let (info, backup) = try await link.readBackup()
            selection = try library.save(backup, firmware: info.firmware).id
        } catch {
            show("Couldn’t Back Up", error)
        }
    }

    /// Step 1: read and check the file, then ask.
    func askToRestore(_ url: URL) {
        do {
            let backup = try SettingsBackup(try Data(contentsOf: url))
            pendingRestore = PendingRestore(url: url, backup: backup, firmware: BackupName.firmware(in: url.lastPathComponent))
        } catch {
            show("Couldn’t Open Backup", error)
        }
    }

    /// Step 2, after the person confirms: back up what's on the camera now, check, then write.
    func restore(_ pending: PendingRestore) async {
        activity = .restoring
        defer { activity = nil }
        do {
            let (info, current) = try await link.readBackup()
            try pending.backup.checkRestore(onto: current, backupFirmware: pending.firmware, cameraFirmware: info.firmware)
            if current.data != pending.backup.data {
                try library.save(current, firmware: info.firmware)
            }
            try await link.writeBackup(pending.backup)
            selection = pending.url
            notice = Notice(title: "Settings Restored",
                            message: "The \(info.model)’s settings now match the backup. A copy of the settings it had before was saved to your backups.")
            await link.refresh()
        } catch {
            show("Couldn’t Restore", error)
        }
    }

    private func show(_ title: String, _ error: Error) {
        let e = error as? LocalizedError
        let text = [e?.errorDescription ?? error.localizedDescription, e?.recoverySuggestion].compactMap { $0 }.joined(separator: "\n\n")
        notice = Notice(title: title, message: text)
    }
}
