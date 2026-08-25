import AppKit
import SwiftUI

@main
struct StickyNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = StickyNoteStore()
    private var windowController: NoteWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = NoteWindowController(store: store)
        windowController = controller
        configureStatusItem()
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowController?.applicationWillTerminate()
        store.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func createStickyNote(_ sender: Any?) {
        windowController?.showNewNote()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Sticky Notes")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New Sticky Note", action: #selector(createStickyNote(_:)), keyEquivalent: "n"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Sticky Notes", action: #selector(quit(_:)), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }
}
