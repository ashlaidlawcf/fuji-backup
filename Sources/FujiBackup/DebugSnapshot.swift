#if DEBUG
import AppKit
import FujiBackupCore

/// Debug builds only. FUJIBACKUP_DEMO=ready|wrongmode|empty shows sample state without a camera;
/// FUJIBACKUP_SNAPSHOT=<file.png> saves the window as a picture and quits;
/// FUJIBACKUP_DEMO_FROM=<folder> uses copies of the backups in that folder;
/// FUJIBACKUP_CHECK=recipes saves the window showing the newest backup's recipes to FUJIBACKUP_SNAPSHOT and quits;
/// FUJIBACKUP_CHECK=notice shows a message alert and reports whether it appeared, and quits;
/// FUJIBACKUP_CHECK=delete-prompt asks to delete the newest backup, prints whether a confirmation sheet appeared, and quits;
/// FUJIBACKUP_CHECK=restore-prompt asks to restore the newest backup, prints whether a confirmation sheet appeared, and quits.
@MainActor
enum DebugSnapshot {
    static let env = ProcessInfo.processInfo.environment
    private static var demoModel: AppModel?

    static func model() -> AppModel {
        guard let demo = env["FUJIBACKUP_DEMO"] else { return AppModel() }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FujiBackupDemo-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let from = env["FUJIBACKUP_DEMO_FROM"] {          // copies of real backups, e.g. ~/Documents/Fuji Backups
            for url in (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: from), includingPropertiesForKeys: nil)) ?? [] {
                try? FileManager.default.copyItem(at: url, to: folder.appendingPathComponent(url.lastPathComponent))
            }
        } else if demo != "empty" {
            var blob = Data(count: 33_404)
            blob.replaceSubrange(0..<8, with: Data("FUJIFILM".utf8))
            blob.replaceSubrange(0x14..<0x18, with: Data("X-T3".utf8))
            for (i, days) in [0.0, 2, 9, 31].enumerated() {
                let date = Date.now.addingTimeInterval(-days * 86_400 - Double(i) * 3_700)
                let url = folder.appendingPathComponent(BackupName.make(model: "X-T3", firmware: "5.11", date: date))
                try? blob.write(to: url)
                try? FileManager.default.setAttributes([.creationDate: date], ofItemAtPath: url.path)
            }
        }
        let model = AppModel(library: BackupLibrary(folder: folder), link: CameraLink(watchUSB: false))
        demoModel = model
        switch demo {
        case "wrongmode": model.link.demo(.wrongMode(name: "X-T3"))
        case "searching": break
        default: model.link.demo(.ready(DeviceInfo(manufacturer: "FUJIFILM", model: "X-T3", firmware: "5.11", serial: "")))
        }
        return model
    }

    static func takeIfRequested() async {
        if env["FUJIBACKUP_CHECK"] == "restore-prompt" { await checkRestorePrompt() }
        if env["FUJIBACKUP_CHECK"] == "delete-prompt" { await checkDeletePrompt() }
        if env["FUJIBACKUP_CHECK"] == "recipes" { await snapshotRecipes() }
        if env["FUJIBACKUP_CHECK"] == "notice" { await checkNotice() }
        guard let path = env["FUJIBACKUP_SNAPSHOT"] else { return }
        guard let window = NSApp.windows.first(where: \.isVisible) else { exit(1) }
        window.setContentSize(NSSize(width: 500, height: 520))
        try? await Task.sleep(for: .seconds(1.5))
        guard let frame = window.contentView?.superview else { exit(1) }
        guard let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { exit(1) }
        frame.cacheDisplay(in: frame.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        exit(0)
    }

    /// Opens the newest backup's recipes and saves the window to FUJIBACKUP_SNAPSHOT.
    private static func snapshotRecipes() async {
        try? await Task.sleep(for: .seconds(1))
        guard let model = demoModel, let path = env["FUJIBACKUP_SNAPSHOT"], let window = NSApp.windows.first(where: \.isVisible)
        else { print("recipes: no demo"); exit(2) }
        model.viewing = model.library.items.first
        try? await Task.sleep(for: .seconds(1.5))
        guard let frame = window.contentView?.superview,
              let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { print("recipes: no window"); exit(1) }
        frame.cacheDisplay(in: frame.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        exit(0)
    }

    private static func checkNotice() async {
        try? await Task.sleep(for: .seconds(1))
        guard let model = demoModel, let window = NSApp.windows.first(where: \.isVisible) else { print("notice: no demo"); exit(2) }
        model.notice = AppModel.Notice(title: "Test", message: "Test message")
        try? await Task.sleep(for: .seconds(1.5))
        let shown = window.attachedSheet != nil
        print("notice: sheet=\(shown)")
        exit(shown ? 0 : 1)
    }

    private static func checkDeletePrompt() async {
        try? await Task.sleep(for: .seconds(1))
        guard let model = demoModel, let item = model.library.items.first,
              let window = NSApp.windows.first(where: \.isVisible) else { print("delete-prompt: no demo"); exit(2) }
        model.askToDelete(item)
        try? await Task.sleep(for: .seconds(1.5))
        let shown = window.attachedSheet != nil
        let kept = model.library.items.contains(item)
        print("delete-prompt: sheet=\(shown) stillThere=\(kept)")
        exit(shown && kept ? 0 : 1)
    }

    private static func checkRestorePrompt() async {
        try? await Task.sleep(for: .seconds(1))
        guard let model = demoModel, let item = model.library.items.first,
              let window = NSApp.windows.first(where: \.isVisible) else { print("restore-prompt: no demo"); exit(2) }
        model.askToRestore(item.url)
        try? await Task.sleep(for: .seconds(1.5))
        let shown = window.attachedSheet != nil
        print("restore-prompt: pending=\(model.pendingRestore != nil) sheet=\(shown)")
        exit(shown ? 0 : 1)
    }
}
#endif
