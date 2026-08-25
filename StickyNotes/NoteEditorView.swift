import SwiftUI

final class NoteEditorModel: ObservableObject {
    @Published var note: StickyNote

    init(note: StickyNote) {
        self.note = note
    }
}

struct NoteEditorView: View {
    @ObservedObject var model: NoteEditorModel
    let onTitleChanged: (String) -> Void
    let onTextChanged: (String) -> Void
    let onColorChanged: (NoteColor) -> Void
    let onVariantChanged: (Bool) -> Void
    let onPinnedChanged: (Bool) -> Void
    let onDelete: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button("Save", action: onSave)
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
                .frame(width: 0, height: 0)
            HStack {
                ZStack(alignment: .leading) {
                    if model.note.title.isEmpty {
                        Text("Untitled")
                            .foregroundColor(textColor.opacity(0.5))
                    }
                    TextField("", text: titleBinding)
                        .textFieldStyle(.plain)
                        .foregroundColor(textColor)
                }
                .font(.headline)
                Spacer()
                Button(action: { onPinnedChanged(!model.note.isPinned) }) {
                    Image(systemName: model.note.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.borderless)
                .foregroundColor(textColor)
                .help(model.note.isPinned ? "最前面表示を解除" : "常に最前面に表示")
                Button(action: { onVariantChanged(!model.note.isDarkVariant) }) {
                    Image(systemName: model.note.isDarkVariant ? "moon.fill" : "sun.max.fill")
                }
                .buttonStyle(.borderless)
                .foregroundColor(textColor)
                .help("背景/文字色を反転")
                HStack(spacing: 6) {
                    ForEach(NoteColor.allCases) { color in
                        Circle()
                            .fill(swatchColor(for: color))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(textColor, lineWidth: model.note.colorName == color ? 2 : 0)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                            )
                            .onTapGesture {
                                colorBinding.wrappedValue = color
                            }
                            .accessibilityLabel(color.displayName)
                    }
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(textColor)
                .help("Delete")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            TextEditor(text: textBinding)
                .font(.system(size: 16))
                .foregroundColor(textColor)
                .scrollContentBackground(.hidden)
                .padding(10)
        }
        .background(backgroundColor)
        .frame(minWidth: 220, minHeight: 160)
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { model.note.title },
            set: { value in
                model.note.title = value
                onTitleChanged(value)
            }
        )
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

    private var colorBinding: Binding<NoteColor> {
        Binding(
            get: { model.note.colorName },
            set: { value in
                model.note.colorName = value
                onColorChanged(value)
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
