import CoreGraphics
import Foundation

final class LocalFrameStore {
    private struct Entry: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        var frame: CGRect { CGRect(x: x, y: y, width: width, height: height) }

        init(frame: CGRect) {
            x = frame.origin.x
            y = frame.origin.y
            width = frame.size.width
            height = frame.size.height
        }
    }

    private let fileManager = FileManager.default
    private let fileURL: URL
    private var entries: [UUID: Entry] = [:]
    private let queue = DispatchQueue(label: "com.example.StickyNotes.local-frame-store")

    init(directoryURL: URL? = nil) {
        let baseDirectory = directoryURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("StickyNotes", isDirectory: true)
        fileURL = baseDirectory.appendingPathComponent("window-positions.json", isDirectory: false)
        load()
    }

    func frame(for id: UUID) -> CGRect? {
        queue.sync { entries[id]?.frame }
    }

    func setFrame(_ frame: CGRect, for id: UUID) {
        queue.sync {
            entries[id] = Entry(frame: frame)
            save()
        }
    }

    func removeFrame(for id: UUID) {
        queue.sync {
            guard entries.removeValue(forKey: id) != nil else { return }
            save()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return }
        entries = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value) }
        })
    }

    private func save() {
        let encoded = Dictionary(uniqueKeysWithValues: entries.map { ($0.key.uuidString, $0.value) })
        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(encoded)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("StickyNotes: unable to write local window positions: %@", error.localizedDescription)
        }
    }
}
