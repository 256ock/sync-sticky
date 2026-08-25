import Combine
import Foundation
import Darwin

final class StickyNoteStore: ObservableObject {
    @Published private(set) var notes: [UUID: StickyNote] = [:]
    @Published private(set) var autoSaveEnabled: Bool
    /// 変更あり・未保存の付箋ID(手動保存待ち、または自動保存デバウンス待ち)。
    @Published private(set) var dirtyNoteIDs: Set<UUID> = []

    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.example.StickyNotes.file-io", qos: .utility)
    private let syncDirectoryURL: URL
    private let localFrameStore: LocalFrameStore
    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryDescriptor: Int32 = -1
    private var pendingReload: DispatchWorkItem?
    private var pendingSaves: [UUID: DispatchWorkItem] = [:]
    private var started = false

    private static let autoSaveDefaultsKey = "autoSaveEnabled"
    private static let autoSaveDelay: TimeInterval = 1.0

    init(directoryURL: URL? = nil, localFrameStore: LocalFrameStore = LocalFrameStore()) {
        syncDirectoryURL = directoryURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Mobile Documents", isDirectory: true)
            .appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
            .appendingPathComponent("StickyNotes", isDirectory: true)
        self.localFrameStore = localFrameStore
        autoSaveEnabled = UserDefaults.standard.object(forKey: Self.autoSaveDefaultsKey) as? Bool ?? true
    }

    func setAutoSaveEnabled(_ enabled: Bool) {
        guard autoSaveEnabled != enabled else { return }
        autoSaveEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.autoSaveDefaultsKey)
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
        dirtyNoteIDs.insert(id)
        scheduleAutoSave(for: id)
    }

    func updateText(for id: UUID, text: String) {
        guard var note = notes[id], note.text != text else { return }
        note.text = text
        note.updatedAt = Date()
        notes[id] = note
        dirtyNoteIDs.insert(id)
        scheduleAutoSave(for: id)
    }

    func updateColor(for id: UUID, color: NoteColor) {
        guard var note = notes[id], note.colorName != color else { return }
        note.colorName = color
        note.updatedAt = Date()
        notes[id] = note
        dirtyNoteIDs.insert(id)
        scheduleAutoSave(for: id)
    }

    func updateVariant(for id: UUID, isDarkVariant: Bool) {
        guard var note = notes[id], note.isDarkVariant != isDarkVariant else { return }
        note.isDarkVariant = isDarkVariant
        note.updatedAt = Date()
        notes[id] = note
        dirtyNoteIDs.insert(id)
        scheduleAutoSave(for: id)
    }

    func updatePinned(for id: UUID, isPinned: Bool) {
        guard var note = notes[id], note.isPinned != isPinned else { return }
        note.isPinned = isPinned
        note.updatedAt = Date()
        notes[id] = note
        dirtyNoteIDs.insert(id)
        scheduleAutoSave(for: id)
    }

    /// 保留中のデバウンス保存があれば取消し、即座にディスクへ書き込む(Cmd+S / ウィンドウを閉じる時など)。
    func saveNow(id: UUID) {
        pendingSaves[id]?.cancel()
        flushSave(for: id)
    }

    /// 全付箋の保留中の保存を即座に反映する(アプリ終了時など)。
    func flushAllPendingSaves() {
        for id in Array(pendingSaves.keys) {
            pendingSaves[id]?.cancel()
            flushSave(for: id)
        }
    }

    private func scheduleAutoSave(for id: UUID) {
        pendingSaves[id]?.cancel()
        guard autoSaveEnabled else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.flushSave(for: id)
        }
        pendingSaves[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoSaveDelay, execute: work)
    }

    private func flushSave(for id: UUID) {
        pendingSaves.removeValue(forKey: id)
        dirtyNoteIDs.remove(id)
        guard let note = notes[id] else { return }
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
        pendingSaves[id]?.cancel()
        pendingSaves.removeValue(forKey: id)
        dirtyNoteIDs.remove(id)
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
            var merged = Dictionary(uniqueKeysWithValues: loadedNotes.map { ($0.id, $0) })
            // 未保存(デバウンス待ち/手動保存待ち)の付箋は、ディスクの内容で上書きせず
            // メモリ上の最新内容を保持する(他Macの変更検知による全件再読込との競合を防ぐ)。
            for id in dirtyNoteIDs {
                if let currentNote = self.notes[id] {
                    merged[id] = currentNote
                }
            }
            self.notes = merged
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
