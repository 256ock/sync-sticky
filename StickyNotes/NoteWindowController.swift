import AppKit
import Combine
import SwiftUI

final class NoteWindowController: NSObject, NSWindowDelegate {
    private let store: StickyNoteStore
    private var notesSubscription: AnyCancellable?
    private var dirtySubscription: AnyCancellable?
    private var windows: [UUID: NSWindow] = [:]
    private var models: [UUID: NoteEditorModel] = [:]
    private var titlebarControllers: [UUID: NoteTitlebarAccessoryController] = [:]
    private var titlebarControlControllers: [UUID: NoteTitlebarControlsAccessoryController] = [:]
    private var applyingStoreUpdate = false
    private var closingFromStore = Set<UUID>()

    private static let unfocusedPinnedAlpha: CGFloat = 0.55

    init(store: StickyNoteStore) {
        self.store = store
        super.init()
        notesSubscription = store.$notes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notes in
                self?.reconcile(with: notes)
            }
        dirtySubscription = store.$dirtyNoteIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dirtyIDs in
                self?.updateDocumentEditedState(dirtyIDs: dirtyIDs)
            }
    }

    private func updateDocumentEditedState(dirtyIDs: Set<UUID>) {
        for (id, window) in windows {
            window.isDocumentEdited = dirtyIDs.contains(id)
        }
    }

    /// Make pinned notes translucent while unfocused so they interfere less with work behind them.
    private func updateAlpha(for window: NSWindow, isPinned: Bool) {
        guard let id = id(for: window), let model = models[id] else { return }
        model.isWindowActive = window.isKeyWindow
        model.contentOpacity = (isPinned && !window.isKeyWindow) ? Self.unfocusedPinnedAlpha : 1.0
    }

    /// Apply .fullScreenAuxiliary only to pinned notes. Applying it to every window would
    /// show unpinned notes over other apps in full-screen mode, such as video players.
    private func collectionBehavior(isPinned: Bool) -> NSWindow.CollectionBehavior {
        isPinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
    }

    func showNewNote() {
        let id = store.createNote()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.windows[id] else { return }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func closeAll() {
        for (id, window) in windows {
            closingFromStore.insert(id)
            window.close()
            closingFromStore.remove(id)
        }
        windows.removeAll()
        models.removeAll()
        titlebarControllers.removeAll()
        titlebarControlControllers.removeAll()
    }

    func applicationWillTerminate() {
        for (id, window) in windows {
            store.updateFrame(for: id, frame: window.frame)
        }
        store.flushAllPendingSaves()
    }

    private func reconcile(with notes: [UUID: StickyNote]) {
        applyingStoreUpdate = true
        defer { applyingStoreUpdate = false }

        let existingIDs = Set(windows.keys)
        let incomingIDs = Set(notes.keys)

        for id in existingIDs.subtracting(incomingIDs) {
            if let window = windows.removeValue(forKey: id) {
                closingFromStore.insert(id)
                window.close()
                closingFromStore.remove(id)
            }
            models.removeValue(forKey: id)
            titlebarControllers.removeValue(forKey: id)
            titlebarControlControllers.removeValue(forKey: id)
        }

        for note in notes.values {
            if let window = windows[note.id], let model = models[note.id] {
                model.note = note
                titlebarControllers[note.id]?.setTitle(note.title)
                window.title = note.title.isEmpty ? "Untitled" : note.title
                if window.frame != note.frame {
                    window.setFrame(note.frame, display: true)
                }
                window.level = note.isPinned ? .floating : .normal
                window.collectionBehavior = collectionBehavior(isPinned: note.isPinned)
                updateAlpha(for: window, isPinned: note.isPinned)
            } else {
                createWindow(for: note)
            }
        }
    }

    private func createWindow(for note: StickyNote) {
        let model = NoteEditorModel(note: note)
        let view = NoteEditorView(
            model: model,
            onTextChanged: { [weak self] text in
                self?.store.updateText(for: note.id, text: text)
            },
            onSave: { [weak self] in
                self?.store.saveNow(id: note.id)
            }
        )

        let window = NSWindow(
            contentRect: CGRect(
                x: note.frame.origin.x,
                y: note.frame.origin.y,
                width: max(note.frame.width, 360),
                height: note.frame.height
            ),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = note.title.isEmpty ? "Untitled" : note.title
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = note.isPinned ? .floating : .normal
        window.collectionBehavior = collectionBehavior(isPinned: note.isPinned)
        window.contentView = NSHostingView(rootView: view)
        let titlebarController = NoteTitlebarAccessoryController(
            title: note.title,
            onTitleChanged: { [weak self] title in
                self?.store.updateTitle(for: note.id, title: title)
            }
        )
        let titlebarControlController = NoteTitlebarControlsAccessoryController(
            model: model,
            onColorChanged: { [weak self] color in
                self?.store.updateColor(for: note.id, color: color)
            },
            onVariantChanged: { [weak self] isDarkVariant in
                self?.store.updateVariant(for: note.id, isDarkVariant: isDarkVariant)
            },
            onPinnedChanged: { [weak self] isPinned in
                self?.store.updatePinned(for: note.id, isPinned: isPinned)
            }
        )
        window.addTitlebarAccessoryViewController(titlebarController)
        window.addTitlebarAccessoryViewController(titlebarControlController)
        window.minSize = CGSize(width: 360, height: 160)
        window.orderFrontRegardless()

        windows[note.id] = window
        models[note.id] = model
        titlebarControllers[note.id] = titlebarController
        titlebarControlControllers[note.id] = titlebarControlController
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isDocumentEdited = store.dirtyNoteIDs.contains(note.id)
        updateAlpha(for: window, isPinned: note.isPinned)
    }

    func windowShouldClose(_ window: NSWindow) -> Bool {
        guard let id = id(for: window), !closingFromStore.contains(id), !applyingStoreUpdate else {
            return true
        }
        store.deleteNote(id: id)
        return true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let id = id(for: window) else { return }
        windows.removeValue(forKey: id)
        models.removeValue(forKey: id)
        titlebarControllers.removeValue(forKey: id)
        titlebarControlControllers.removeValue(forKey: id)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        refreshAlpha(for: notification)
    }

    func windowDidResignKey(_ notification: Notification) {
        refreshAlpha(for: notification)
    }

    private func refreshAlpha(for notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = id(for: window),
              let note = store.notes[id]
        else { return }
        updateAlpha(for: window, isPinned: note.isPinned)
    }

    func windowDidMove(_ notification: Notification) {
        persistFrame(from: notification)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        persistFrame(from: notification)
    }

    private func persistFrame(from notification: Notification) {
        guard !applyingStoreUpdate,
              let window = notification.object as? NSWindow,
              let id = id(for: window)
        else { return }
        store.updateFrame(for: id, frame: window.frame)
    }

    private func id(for window: NSWindow) -> UUID? {
        windows.first { $0.value === window }?.key
    }
}

private final class NoteTitlebarAccessoryController: NSTitlebarAccessoryViewController, NSTextFieldDelegate {
    private let titleField = NSTextField()
    private let onTitleChanged: (String) -> Void
    private var titleFieldWidthConstraint: NSLayoutConstraint?
    private let titleFieldMaximumWidth: CGFloat = 140

    init(title: String, onTitleChanged: @escaping (String) -> Void) {
        self.onTitleChanged = onTitleChanged
        super.init(nibName: nil, bundle: nil)

        layoutAttribute = .left
        titleField.stringValue = title
        titleField.placeholderString = "Untitled"
        titleField.isEditable = true
        titleField.isSelectable = true
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.font = .systemFont(ofSize: 13)
        setTextColor()
        titleField.delegate = self
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.focusRingType = .none
        preferredContentSize = CGSize(width: 150, height: 24)
    }

    override func loadView() {
        let container = TitlebarDragView(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        container.addSubview(titleField)
        let widthConstraint = titleField.widthAnchor.constraint(equalToConstant: 0)
        titleFieldWidthConstraint = widthConstraint
        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            titleField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            widthConstraint,
            container.heightAnchor.constraint(equalToConstant: 24)
        ])
        view = container
        updateTitleFieldWidth()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(_ title: String) {
        if titleField.stringValue != title {
            titleField.stringValue = title
        }
        setTextColor()
        updateTitleFieldWidth()
    }

    private func updateTitleFieldWidth() {
        let displayedTitle = titleField.stringValue.isEmpty ? (titleField.placeholderString ?? "") : titleField.stringValue
        let textWidth = (displayedTitle as NSString).size(withAttributes: [.font: titleField.font ?? .systemFont(ofSize: 13)]).width
        titleFieldWidthConstraint?.constant = min(ceil(textWidth + 8), titleFieldMaximumWidth)
    }

    private func setTextColor() {
        titleField.textColor = .labelColor
        titleField.placeholderAttributedString = NSAttributedString(
            string: "Untitled",
            attributes: [.foregroundColor: NSColor.labelColor]
        )
    }

    func controlTextDidChange(_ notification: Notification) {
        onTitleChanged(titleField.stringValue)
        updateTitleFieldWidth()
    }
}

private final class TitlebarDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private final class NoteTitlebarControlsAccessoryController: NSTitlebarAccessoryViewController {
    private let model: NoteEditorModel
    private let onColorChanged: (NoteColor) -> Void
    private let onVariantChanged: (Bool) -> Void
    private let onPinnedChanged: (Bool) -> Void

    init(
        model: NoteEditorModel,
        onColorChanged: @escaping (NoteColor) -> Void,
        onVariantChanged: @escaping (Bool) -> Void,
        onPinnedChanged: @escaping (Bool) -> Void
    ) {
        self.model = model
        self.onColorChanged = onColorChanged
        self.onVariantChanged = onVariantChanged
        self.onPinnedChanged = onPinnedChanged
        super.init(nibName: nil, bundle: nil)

        layoutAttribute = .right
        preferredContentSize = CGSize(width: 115, height: 24)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let controlsView = NSHostingView(
            rootView: NoteTitlebarControlsView(
                model: model,
                onColorChanged: onColorChanged,
                onVariantChanged: onVariantChanged,
                onPinnedChanged: onPinnedChanged
            )
        )
        controlsView.frame = NSRect(x: 0, y: 0, width: 115, height: 24)
        view = controlsView
    }
}
