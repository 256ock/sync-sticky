import AppKit
import Combine
import SwiftUI

final class NoteWindowController: NSObject, NSWindowDelegate {
    private let store: StickyNoteStore
    private var notesSubscription: AnyCancellable?
    private var dirtySubscription: AnyCancellable?
    private var windows: [UUID: NSWindow] = [:]
    private var models: [UUID: NoteEditorModel] = [:]
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

    /// 最前面固定(isPinned)中、フォーカスが無い間は半透明化して背後の作業の邪魔にならないようにする。
    private func updateAlpha(for window: NSWindow, isPinned: Bool) {
        window.alphaValue = (isPinned && !window.isKeyWindow) ? Self.unfocusedPinnedAlpha : 1.0
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
        }

        for note in notes.values {
            if let window = windows[note.id], let model = models[note.id] {
                model.note = note
                if window.frame != note.frame {
                    window.setFrame(note.frame, display: true)
                }
                window.level = note.isPinned ? .floating : .normal
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
            onTitleChanged: { [weak self] title in
                self?.store.updateTitle(for: note.id, title: title)
            },
            onTextChanged: { [weak self] text in
                self?.store.updateText(for: note.id, text: text)
            },
            onColorChanged: { [weak self] color in
                self?.store.updateColor(for: note.id, color: color)
            },
            onVariantChanged: { [weak self] isDarkVariant in
                self?.store.updateVariant(for: note.id, isDarkVariant: isDarkVariant)
            },
            onPinnedChanged: { [weak self] isPinned in
                self?.store.updatePinned(for: note.id, isPinned: isPinned)
            },
            onDelete: { [weak self] in
                self?.store.deleteNote(id: note.id)
            },
            onSave: { [weak self] in
                self?.store.saveNow(id: note.id)
            }
        )

        let window = NSWindow(
            contentRect: note.frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sticky Note"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = note.isPinned ? .floating : .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: view)
        window.minSize = CGSize(width: 220, height: 160)
        window.orderFrontRegardless()

        windows[note.id] = window
        models[note.id] = model
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
