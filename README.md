# Sync Sticky

Sync Sticky is a lightweight macOS sticky notes app. It keeps note content in iCloud Drive so it can be shared across Macs signed in to the same iCloud account.

## Features

- Lives in the menu bar without a Dock icon
- Create and edit notes with titles, text, and colors
- Keep selected notes above other windows
- Choose automatic or manual saving
- Open detected links in the default browser with Command-click
- Switch between light and dark note colors
- Keep each note's window position and size locally on each Mac

## Requirements

- macOS 13 or later
- Xcode
- iCloud Drive enabled for cross-device sync

## Build and run

Open `StickyNotes.xcodeproj` in Xcode, select the `StickyNotes` scheme, and build and run the app.

You can also build from Terminal:

```sh
xcodebuild -project StickyNotes.xcodeproj -scheme StickyNotes -configuration Debug build
```

## Data storage and sync

Notes are stored as JSON files in:

```text
~/Library/Mobile Documents/com~apple~CloudDocs/StickyNotes
```

Sync uses the iCloud Drive folder directly. Note content is not sent to a separate service. Window positions and sizes are stored locally in the app's Application Support directory and are not synced.

## Project structure

- `StickyNotes/StickyNotesApp.swift` — App entry point and menu bar controls
- `StickyNotes/StickyNoteStore.swift` — Note persistence, sync, and file monitoring
- `StickyNotes/StickyNote.swift` — Note data model
- `StickyNotes/NoteWindowController.swift` — Note window management
- `StickyNotes/NoteEditorView.swift` — Note editing interface
- `StickyNotes/LocalFrameStore.swift` — Local window position and size storage
- `StickyNotes/LinkAwareTextView.swift` — Text view with link detection
- `Scripts/build_release.sh` — Release build and app bundle packaging script

## License

This project is licensed under the [MIT License](LICENSE).
