import AppKit

@main
struct StickyNotesApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = StickyNoteStore()
    private var windowController: NoteWindowController?
    private var statusItem: NSStatusItem?
    private var autoSaveMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        if let existingInstance = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existingInstance.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()

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

    @objc private func toggleAutoSave(_ sender: Any?) {
        store.setAutoSaveEnabled(!store.autoSaveEnabled)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit Sticky Notes", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        let appMenuItem = NSMenuItem(title: "Sticky Notes", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        // A nil target routes editing commands to the focused text view or field editor.
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Sticky Notes")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "New Sticky Note", action: #selector(createStickyNote(_:)), keyEquivalent: "n"))
        menu.addItem(.separator())
        let autoSaveItem = NSMenuItem(title: "Auto-Save", action: #selector(toggleAutoSave(_:)), keyEquivalent: "")
        menu.addItem(autoSaveItem)
        autoSaveMenuItem = autoSaveItem
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Sticky Notes", action: #selector(quit(_:)), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        autoSaveMenuItem?.state = store.autoSaveEnabled ? .on : .off
    }
}
