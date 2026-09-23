import Foundation

enum PointerMessage: Codable {
    case move(dx: Double, dy: Double)
    case scroll(dx: Double, dy: Double)
    case leftClick
    case rightClick
    case text(String)
    case key(UInt16, UInt64, Bool)

    private enum CodingKeys: String, CodingKey { case type, dx, dy, text, keyCode, flags, isDown }
    private enum Kind: String, Codable { case move, scroll, leftClick, rightClick, text, key }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .move: self = .move(dx: try c.decode(Double.self, forKey: .dx), dy: try c.decode(Double.self, forKey: .dy))
        case .scroll: self = .scroll(dx: try c.decode(Double.self, forKey: .dx), dy: try c.decode(Double.self, forKey: .dy))
        case .leftClick: self = .leftClick
        case .rightClick: self = .rightClick
        case .text: self = .text(try c.decode(String.self, forKey: .text))
        case .key:
            self = .key(
                try c.decode(UInt16.self, forKey: .keyCode),
                try c.decode(UInt64.self, forKey: .flags),
                try c.decode(Bool.self, forKey: .isDown)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .move(dx, dy): try c.encode(Kind.move, forKey:.type); try c.encode(dx,forKey:.dx); try c.encode(dy,forKey:.dy)
        case let .scroll(dx, dy): try c.encode(Kind.scroll, forKey:.type); try c.encode(dx,forKey:.dx); try c.encode(dy,forKey:.dy)
        case .leftClick: try c.encode(Kind.leftClick,forKey:.type)
        case .rightClick: try c.encode(Kind.rightClick,forKey:.type)
        case let .text(text): try c.encode(Kind.text,forKey:.type); try c.encode(text,forKey:.text)
        case let .key(code, flags, isDown):
            try c.encode(Kind.key, forKey:.type)
            try c.encode(code, forKey:.keyCode)
            try c.encode(flags, forKey:.flags)
            try c.encode(isDown, forKey:.isDown)
        }
    }
}
