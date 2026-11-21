#if DEBUG
import AppKit
import FujiBackupCore

/// Debug builds only. FUJIBACKUP_DEMO=ready|wrongmode|empty shows sample state without a camera;
/// FUJIBACKUP_SNAPSHOT=<file.png> saves the window as a picture and quits.
@MainActor
enum DebugSnapshot {
    static let env = ProcessInfo.processInfo.environment

    static func model() -> AppModel {
        guard let demo = env["FUJIBACKUP_DEMO"] else { return AppModel() }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FujiBackupDemo-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if demo != "empty" {
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
        let model = AppModel(library: BackupLibrary(folder: folder))
        switch demo {
        case "wrongmode": model.link.demo(.wrongMode(name: "X-T3"))
        case "searching": break
        default: model.link.demo(.ready(DeviceInfo(manufacturer: "FUJIFILM", model: "X-T3", firmware: "5.11", serial: "")))
        }
        return model
    }

    static func takeIfRequested() async {
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
}
#endif
