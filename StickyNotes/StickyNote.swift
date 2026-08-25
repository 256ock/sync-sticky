import CoreGraphics
import Foundation

enum NoteColor: String, CaseIterable, Codable, Identifiable {
    case yellow
    case blue
    case green
    case pink
    case purple

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

struct StickyNote: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var text: String
    var colorName: NoteColor
    var isDarkVariant: Bool
    var isPinned: Bool
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var updatedAt: Date

    static let defaultSize = CGSize(width: 280, height: 240)

    init(
        id: UUID = UUID(),
        title: String = "",
        text: String = "",
        colorName: NoteColor = .yellow,
        isDarkVariant: Bool = false,
        isPinned: Bool = true,
        frame: CGRect = CGRect(origin: .zero, size: StickyNote.defaultSize),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.colorName = colorName
        self.isDarkVariant = isDarkVariant
        self.isPinned = isPinned
        self.x = frame.origin.x
        self.y = frame.origin.y
        self.width = frame.width
        self.height = frame.height
        self.updatedAt = updatedAt
    }

    var frame: CGRect {
        get { CGRect(x: x, y: y, width: width, height: height) }
        set {
            x = newValue.origin.x
            y = newValue.origin.y
            width = newValue.size.width
            height = newValue.size.height
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, text, colorName, isDarkVariant, isPinned, x, y, width, height, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        text = try container.decode(String.self, forKey: .text)
        colorName = try container.decode(NoteColor.self, forKey: .colorName)
        isDarkVariant = try container.decodeIfPresent(Bool.self, forKey: .isDarkVariant) ?? false
        // 旧形式ファイルには無い項目。これまで全付箋が常に最前面固定だったため、
        // 後方互換としてデフォルトはtrue(最前面)にする。
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? true
        // ウィンドウ位置/サイズはMacごとのローカル情報。同期ファイルには含めない。
        // 旧形式ファイルに残っていれば初回移行のシード値として読み込む。
        let legacyFrame = CGRect(
            x: try container.decodeIfPresent(Double.self, forKey: .x) ?? 0,
            y: try container.decodeIfPresent(Double.self, forKey: .y) ?? 0,
            width: try container.decodeIfPresent(Double.self, forKey: .width) ?? StickyNote.defaultSize.width,
            height: try container.decodeIfPresent(Double.self, forKey: .height) ?? StickyNote.defaultSize.height
        )
        x = legacyFrame.origin.x
        y = legacyFrame.origin.y
        width = legacyFrame.width
        height = legacyFrame.height
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(text, forKey: .text)
        try container.encode(colorName, forKey: .colorName)
        try container.encode(isDarkVariant, forKey: .isDarkVariant)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
