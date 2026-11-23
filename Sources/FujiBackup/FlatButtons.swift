import SwiftUI

/// Flat buttons, like Mail's: no bezel, gradient or shadow.
/// `prominent` fills with the accent colour (the main action); otherwise the label is tinted
/// and a light tint appears behind it on hover.
struct FlatButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        FlatButton(configuration: configuration, prominent: prominent)
    }

    private struct FlatButton: View {
        let configuration: Configuration
        let prominent: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.body.weight(prominent ? .semibold : .medium))
                .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .opacity(enabled ? 1 : 0.4)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }

        private var background: AnyShapeStyle {
            let pressed = configuration.isPressed
            if prominent {
                return AnyShapeStyle(Color.accentColor.opacity(pressed ? 0.75 : hovering && enabled ? 0.9 : 1))
            }
            return AnyShapeStyle(Color.accentColor.opacity(pressed ? 0.2 : hovering && enabled ? 0.1 : 0))
        }
    }
}

/// An icon-only flat button, as in Mail's message actions. Red when `destructive`.
struct FlatIconButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        FlatIcon(configuration: configuration, destructive: destructive)
    }

    private struct FlatIcon: View {
        let configuration: Configuration
        let destructive: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hovering = false

        var body: some View {
            let color: Color = destructive ? .red : .accentColor
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(hovering && enabled ? color : .secondary)
                .frame(width: 28, height: 26)
                .background(color.opacity(configuration.isPressed ? 0.2 : hovering && enabled ? 0.1 : 0),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
                .opacity(enabled ? 1 : 0.35)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}

extension ButtonStyle where Self == FlatButtonStyle {
    static var flat: FlatButtonStyle { FlatButtonStyle() }
    static var flatProminent: FlatButtonStyle { FlatButtonStyle(prominent: true) }
}

extension ButtonStyle where Self == FlatIconButtonStyle {
    static var flatIcon: FlatIconButtonStyle { FlatIconButtonStyle() }
    static var flatIconDestructive: FlatIconButtonStyle { FlatIconButtonStyle(destructive: true) }
}
