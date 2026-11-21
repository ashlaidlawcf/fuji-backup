import SwiftUI
import UniformTypeIdentifiers
import FujiBackupCore

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var choosingFile = false

    var body: some View {
        VStack(spacing: 0) {
            CameraHeader(model: model)
            Divider()
            BackupList(model: model)
                // On a different view from the notice alert: only one alert per view is shown.
                .alert(restoreTitle, isPresented: restoring, presenting: model.pendingRestore) { pending in
                    Button("Cancel", role: .cancel) {}
                    Button("Restore", role: .destructive) { Task { await model.restore(pending) } }
                } message: { pending in
                    Text("All camera settings, including custom settings C1–C7, will be replaced with “\(pending.url.deletingPathExtension().lastPathComponent)”. The camera’s current settings are backed up first.")
                }
        }
        .frame(minWidth: 440, minHeight: 440)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Show in Finder", systemImage: "folder") { model.library.reveal() }
                    .help("Show the backups folder in Finder")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Restore from File…", systemImage: "square.and.arrow.down") { choosingFile = true }
                    .help("Restore a backup saved somewhere else")
                    .disabled(!model.canBackUp)
            }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.data]) { result in
            if case let .success(url) = result {
                let scoped = url.startAccessingSecurityScopedResource()
                model.askToRestore(url)
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
        }
        .alert(model.notice?.title ?? "", isPresented: showingNotice, presenting: model.notice) { _ in
            Button("OK") {}
        } message: { notice in
            Text(notice.message)
        }
    }

    private var restoreTitle: String {
        "Restore Settings to Your \(model.link.info?.model ?? model.pendingRestore?.backup.model ?? "Camera")?"
    }

    private var restoring: Binding<Bool> {
        Binding(get: { model.pendingRestore != nil }, set: { if !$0 { model.pendingRestore = nil } })
    }

    private var showingNotice: Binding<Bool> {
        Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })
    }
}

// MARK: Header

private struct CameraHeader: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.linearGradient(colors: [Color(white: 0.32), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.weight(.semibold))
                StatusLine(model: model)
            }
            Spacer()
            Button {
                Task { await model.backUp() }
            } label: {
                if model.activity == .backingUp {
                    ProgressView().controlSize(.small).frame(width: 74)
                } else {
                    Text("Back Up").frame(width: 74)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canBackUp)
            .keyboardShortcut("b", modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.background.secondary)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let steps {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(.tint))
                            Text(step).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .background(.background.secondary)
            }
        }
    }

    private var title: String {
        switch model.link.state {
        case .searching: "No Camera"
        case let .connecting(name), let .wrongMode(name), let .unavailable(name, _): name
        case let .ready(info): info.model
        }
    }

    private static let modeStep: AttributedString =
        try! AttributedString(markdown: "In **SET UP › CONNECTION SETTING**, set **PC CONNECTION MODE** to **USB RAW CONV./BACKUP RESTORE**.")

    private var steps: [AttributedString]? {
        switch model.link.state {
        case .searching:
            ["Turn on your camera.", Self.modeStep, "Connect it to this Mac with a USB cable."]
        case .wrongMode:
            [Self.modeStep, "Unplug the cable and plug it in again."]
        case let .unavailable(_, reason):
            [AttributedString(reason), "Turn the camera off and on, then reconnect the cable."]
        default:
            nil
        }
    }
}

private struct StatusLine: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var text: String {
        switch (model.activity, model.link.state) {
        case (.backingUp?, _): "Backing up…"
        case (.restoring?, _): "Restoring…"
        case (nil, .searching): "Waiting for a Fujifilm camera"
        case (nil, .connecting): "Connecting…"
        case (nil, .wrongMode): "Not in backup mode"
        case (nil, .unavailable): "Can’t connect"
        case let (nil, .ready(info)): "Firmware \(info.firmware) · Ready"
        }
    }

    private var color: Color {
        switch (model.activity, model.link.state) {
        case (.some, _): .blue
        case (nil, .ready): .green
        case (nil, .wrongMode), (nil, .unavailable): .orange
        default: .secondary.opacity(0.5)
        }
    }
}

// MARK: Backups

private struct BackupList: View {
    @Bindable var model: AppModel

    var body: some View {
        if model.library.items.isEmpty {
            ContentUnavailableView("No Backups", systemImage: "clock.arrow.circlepath",
                                   description: Text("Backups of your camera’s settings appear here."))
                .frame(maxHeight: .infinity)
        } else {
            List(selection: $model.selection) {
                Section("Backups") {
                    ForEach(model.library.items) { item in
                        BackupRow(item: item, canRestore: model.canBackUp) { model.askToRestore(item.url) }
                            .tag(item.id)
                            .contextMenu {
                                Button("Restore to Camera…") { model.askToRestore(item.url) }.disabled(!model.canBackUp)
                                Button("Show in Finder") { model.library.reveal(item) }
                                Divider()
                                Button("Move to Trash", role: .destructive) { model.library.trash(item) }
                            }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

private struct BackupRow: View {
    let item: BackupLibrary.Item
    let canRestore: Bool
    let restore: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.badge.gearshape")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: item.date))
                    .font(.body.weight(.medium))
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restore…", action: restore)
                .controlSize(.small)
                .disabled(!canRestore)
                .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 4)
        .onHover { hovering = $0 }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    private var details: String {
        [item.model, item.firmware.map { "Firmware \($0)" }, item.size.formatted(.byteCount(style: .file))]
            .compactMap { $0 }.joined(separator: " · ")
    }
}
