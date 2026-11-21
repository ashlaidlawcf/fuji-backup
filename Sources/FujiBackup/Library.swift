import AppKit
import FujiBackupCore

/// Backups kept as .dat files in ~/Documents/Fuji Backups.
@MainActor @Observable
final class BackupLibrary {
    struct Item: Identifiable, Hashable {
        let url: URL
        let date: Date
        let model: String
        let firmware: String?
        let size: Int
        var id: URL { url }
    }

    static let defaultFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Fuji Backups", isDirectory: true)
    let folder: URL
    private(set) var items: [Item] = []

    init(folder: URL = BackupLibrary.defaultFolder) { self.folder = folder }

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        items = urls.filter { $0.pathExtension.lowercased() == "dat" }.compactMap(Self.item).sorted { $0.date > $1.date }
    }

    @discardableResult
    func save(_ backup: SettingsBackup, firmware: String) throws -> Item {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(BackupName.make(model: backup.model, firmware: firmware, date: .now))
        try backup.data.write(to: url, options: .withoutOverwriting)
        reload()
        return Self.item(url) ?? Item(url: url, date: .now, model: backup.model, firmware: firmware, size: backup.data.count)
    }

    func trash(_ item: Item) {
        try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
        reload()
    }

    func reveal(_ item: Item? = nil) {
        if let item {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        } else {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        }
    }

    static func item(_ url: URL) -> Item? {
        guard let data = try? Data(contentsOf: url), let backup = try? SettingsBackup(data) else { return nil }
        let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
        return Item(url: url, date: date, model: backup.model, firmware: BackupName.firmware(in: url.lastPathComponent), size: data.count)
    }
}
