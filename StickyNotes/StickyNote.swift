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
        frame: CGRect = CGRect(origin: .zero, size: StickyNote.defaultSize),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.colorName = colorName
        self.isDarkVariant = isDarkVariant
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        text = try container.decode(String.self, forKey: .text)
        colorName = try container.decode(NoteColor.self, forKey: .colorName)
        isDarkVariant = try container.decodeIfPresent(Bool.self, forKey: .isDarkVariant) ?? false
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
