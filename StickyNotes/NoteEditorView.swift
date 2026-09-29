import AppKit
import SwiftUI

final class NoteEditorModel: ObservableObject {
    @Published var note: StickyNote

    init(note: StickyNote) {
        self.note = note
    }
}

struct NoteEditorView: View {
    @ObservedObject var model: NoteEditorModel
    let onTextChanged: (String) -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button("Save", action: onSave)
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
                .frame(width: 0, height: 0)
            LinkAwareTextView(
                text: textBinding,
                font: .systemFont(ofSize: 16),
                textColor: NSColor(textColor)
            )
            .padding(10)
        }
        .background(backgroundColor)
        .frame(minWidth: 220, minHeight: 160)
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { model.note.text },
            set: { value in
                model.note.text = value
                onTextChanged(value)
            }
        )
    }

    private var backgroundColor: Color {
        model.note.isDarkVariant ? darkBackground : lightBackground
    }

    private var textColor: Color {
        model.note.isDarkVariant ? lightText : darkText
    }

    private var lightBackground: Color {
        swatchColor(for: model.note.colorName)
    }

    private func swatchColor(for color: NoteColor) -> Color {
        switch color {
        case .yellow: return Color(red: 1.0, green: 0.95, blue: 0.62)
        case .blue: return Color(red: 0.68, green: 0.86, blue: 1.0)
        case .green: return Color(red: 0.72, green: 0.94, blue: 0.72)
        case .pink: return Color(red: 1.0, green: 0.76, blue: 0.82)
        case .purple: return Color(red: 0.86, green: 0.77, blue: 1.0)
        }
    }

    private var darkText: Color {
        switch model.note.colorName {
        case .yellow: return Color(red: 0.35, green: 0.28, blue: 0.0)
        case .blue: return Color(red: 0.05, green: 0.15, blue: 0.35)
        case .green: return Color(red: 0.05, green: 0.25, blue: 0.05)
        case .pink: return Color(red: 0.35, green: 0.05, blue: 0.12)
        case .purple: return Color(red: 0.20, green: 0.08, blue: 0.35)
        }
    }

    private var darkBackground: Color {
        switch model.note.colorName {
        case .yellow: return Color(red: 0.42, green: 0.34, blue: 0.02)
        case .blue: return Color(red: 0.08, green: 0.20, blue: 0.38)
        case .green: return Color(red: 0.08, green: 0.28, blue: 0.10)
        case .pink: return Color(red: 0.40, green: 0.10, blue: 0.18)
        case .purple: return Color(red: 0.26, green: 0.13, blue: 0.40)
        }
    }

    private var lightText: Color {
        switch model.note.colorName {
        case .yellow: return Color(red: 1.0, green: 0.97, blue: 0.85)
        case .blue: return Color(red: 0.90, green: 0.96, blue: 1.0)
        case .green: return Color(red: 0.90, green: 1.0, blue: 0.90)
        case .pink: return Color(red: 1.0, green: 0.92, blue: 0.94)
        case .purple: return Color(red: 0.95, green: 0.90, blue: 1.0)
        }
    }
}

struct NoteTitlebarControlsView: View {
    @ObservedObject var model: NoteEditorModel
    let onColorChanged: (NoteColor) -> Void
    let onVariantChanged: (Bool) -> Void
    let onPinnedChanged: (Bool) -> Void

    private var controlColor: Color {
        Color(nsColor: .labelColor)
    }

    var body: some View {
        HStack(spacing: 5) {
            Button(action: { onPinnedChanged(!model.note.isPinned) }) {
                Image(systemName: model.note.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .foregroundColor(controlColor)
            .help(model.note.isPinned ? "最前面表示を解除" : "常に最前面に表示")

            Button(action: { onVariantChanged(!model.note.isDarkVariant) }) {
                Image(systemName: model.note.isDarkVariant ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .foregroundColor(controlColor)
            .help("背景/文字色を反転")

            HStack(spacing: 3) {
                ForEach(NoteColor.allCases) { color in
                    Button(action: { onColorChanged(color) }) {
                        Circle()
                            .fill(swatchColor(for: color))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle().stroke(
                                    controlColor,
                                    lineWidth: model.note.colorName == color ? 1.5 : 0
                                )
                            )
                            .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(color.displayName)
                }
            }
        }
        .padding(.leading, 3)
        .padding(.trailing, 10)
        .frame(width: 115, height: 24)
    }

    private func swatchColor(for color: NoteColor) -> Color {
        switch color {
        case .yellow: return Color(red: 1.0, green: 0.95, blue: 0.62)
        case .blue: return Color(red: 0.68, green: 0.86, blue: 1.0)
        case .green: return Color(red: 0.72, green: 0.94, blue: 0.72)
        case .pink: return Color(red: 1.0, green: 0.76, blue: 0.82)
        case .purple: return Color(red: 0.86, green: 0.77, blue: 1.0)
        }
    }
}
