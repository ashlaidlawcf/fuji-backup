import AppKit
import SwiftUI
import FujiBackupCore

/// C1–C7 of one backup, as cards.
struct RecipesView: View {
    let item: BackupLibrary.Item
    let close: () -> Void

    private var settings: [CustomSetting]? {
        guard let data = try? Data(contentsOf: item.url), let backup = try? SettingsBackup(data) else { return nil }
        return CustomSettings.read(backup)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recipes").font(.title2.weight(.semibold))
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done", action: close)
                    .buttonStyle(.flat)
                    .keyboardShortcut(.defaultAction)
                // Escape closes too.
                Button("Close", action: close).keyboardShortcut(.cancelAction).opacity(0).frame(width: 0, height: 0)
            }
            .padding(20)
            Divider()
            if let settings {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 14)], spacing: 14) {
                        ForEach(settings) { RecipeCard(setting: $0) }
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView("Recipes Not Available", systemImage: "camera.filters",
                                       description: Text("This app can show recipes from X-T3 backups only, for now."))
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private var subtitle: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return [f.string(from: item.date), item.model, item.firmware.map { "Firmware \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct RecipeCard: View {
    let setting: CustomSetting
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("C\(setting.slot)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.tint))
                Text(setting.name.isEmpty ? "Unnamed" : setting.name)
                    .font(.headline)
                    .foregroundStyle(setting.name.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(setting.text, forType: .string)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.flatIcon)
                .help("Copy Recipe as Text")
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                ForEach(setting.rows, id: \.0) { label, value in
                    GridRow {
                        Text(label).foregroundStyle(.secondary)
                        Text(value).textSelection(.enabled)
                    }
                }
            }
            .font(.callout)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator.opacity(0.6)))
    }
}
