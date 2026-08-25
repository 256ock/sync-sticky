import Combine
import Foundation
import Darwin

final class StickyNoteStore: ObservableObject {
    @Published private(set) var notes: [UUID: StickyNote] = [:]

    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.example.StickyNotes.file-io", qos: .utility)
    private let syncDirectoryURL: URL
    private let localFrameStore: LocalFrameStore
    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryDescriptor: Int32 = -1
    private var pendingReload: DispatchWorkItem?
    private var started = false

    init(directoryURL: URL? = nil, localFrameStore: LocalFrameStore = LocalFrameStore()) {
        syncDirectoryURL = directoryURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Mobile Documents", isDirectory: true)
            .appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
            .appendingPathComponent("StickyNotes", isDirectory: true)
        self.localFrameStore = localFrameStore
    }

    var directoryURL: URL { syncDirectoryURL }

    func start() {
        guard !started else { return }
        started = true

        ioQueue.async { [weak self] in
            guard let self else { return }
            self.ensureDirectory()
            self.reloadFromDisk()
            self.startDirectoryMonitoring()
        }
    }

    func stop() {
        pendingReload?.cancel()
        directorySource?.cancel()
        directorySource = nil

        if directoryDescriptor >= 0 {
            close(directoryDescriptor)
            directoryDescriptor = -1
        }
    }

    @discardableResult
    func createNote() -> UUID {
        let frame = defaultFrame(for: notes.count)
        let note = StickyNote(frame: frame)
        notes[note.id] = note
        localFrameStore.setFrame(frame, for: note.id)
        persist(note)
        return note.id
    }

    func updateTitle(for id: UUID, title: String) {
        guard var note = notes[id], note.title != title else { return }
        note.title = title
        note.updatedAt = Date()
        notes[id] = note
        persist(note)
    }

    func updateText(for id: UUID, text: String) {
        guard var note = notes[id], note.text != text else { return }
        note.text = text
        note.updatedAt = Date()
        notes[id] = note
        persist(note)
    }

    func updateColor(for id: UUID, color: NoteColor) {
        guard var note = notes[id], note.colorName != color else { return }
        note.colorName = color
        note.updatedAt = Date()
        notes[id] = note
        persist(note)
    }

    func updateVariant(for id: UUID, isDarkVariant: Bool) {
        guard var note = notes[id], note.isDarkVariant != isDarkVariant else { return }
        note.isDarkVariant = isDarkVariant
        note.updatedAt = Date()
        notes[id] = note
        persist(note)
    }

    func updateFrame(for id: UUID, frame: CGRect) {
        // ウィンドウ位置/サイズはこのMacのみのローカル情報。iCloud同期ファイルは更新しない。
        guard var note = notes[id], note.frame != frame else { return }
        note.frame = frame
        notes[id] = note
        localFrameStore.setFrame(frame, for: id)
    }

    func deleteNote(id: UUID) {
        guard notes.removeValue(forKey: id) != nil else { return }
        localFrameStore.removeFrame(for: id)
        let url = noteURL(for: id)
        ioQueue.async { [fileManager] in
            try? fileManager.removeItem(at: url)
        }
    }

    private func defaultFrame(for index: Int) -> CGRect {
        let offset = CGFloat(index % 8) * 28
        return CGRect(x: 180 + offset, y: 560 - offset, width: 280, height: 240)
    }

    private func noteURL(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    private func ensureDirectory() {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            NSLog("StickyNotes: unable to create sync directory: %@", error.localizedDescription)
        }
    }

    private func persist(_ note: StickyNote) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        ioQueue.async { [weak self] in
            guard let self else { return }
            self.ensureDirectory()
            do {
                let data = try encoder.encode(note)
                try data.write(to: self.noteURL(for: note.id), options: [.atomic])
            } catch {
                NSLog("StickyNotes: unable to write %@: %@", note.id.uuidString, error.localizedDescription)
            }
        }
    }

    private func startDirectoryMonitoring() {
        guard directorySource == nil else { return }
        directoryDescriptor = open(directoryURL.path, O_EVTONLY)
        guard directoryDescriptor >= 0 else {
            NSLog("StickyNotes: unable to monitor sync directory: %s", strerror(errno))
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryDescriptor,
            eventMask: [.write, .extend, .attrib, .link, .rename, .delete],
            queue: ioQueue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.directoryDescriptor >= 0 else { return }
            close(self.directoryDescriptor)
            self.directoryDescriptor = -1
        }
        directorySource = source
        source.resume()
    }

    private func scheduleReload() {
        pendingReload?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reloadFromDisk()
        }
        pendingReload = work
        ioQueue.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func reloadFromDisk() {
        ensureDirectory()
        let loadedNotes = readAllNotes()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.notes = Dictionary(uniqueKeysWithValues: loadedNotes.map { ($0.id, $0) })
        }
    }

    private func readAllNotes() -> [StickyNote] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var notes = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> StickyNote? in
                guard let data = try? Data(contentsOf: url),
                      let note = try? decoder.decode(StickyNote.self, from: data)
                else {
                    NSLog("StickyNotes: ignoring unreadable note file %@", url.lastPathComponent)
                    return nil
                }
                return note
            }

        for index in notes.indices {
            let id = notes[index].id
            if let localFrame = localFrameStore.frame(for: id) {
                notes[index].frame = localFrame
            } else {
                // このMacで初めて見る付箋。デコード結果(旧形式なら実座標、新形式ならプレースホルダ)を
                // 以後このMac用のローカル位置として採用する。
                localFrameStore.setFrame(notes[index].frame, for: id)
            }
        }

        return notes
    }
}
