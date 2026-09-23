import Foundation

enum PointerMessage: Codable {
    case move(dx: Double, dy: Double)
    case scroll(dx: Double, dy: Double)
    case leftClick
    case rightClick

    private enum CodingKeys: String, CodingKey { case type, dx, dy }
    private enum Kind: String, Codable { case move, scroll, leftClick, rightClick }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .move: self = .move(dx: try container.decode(Double.self, forKey: .dx), dy: try container.decode(Double.self, forKey: .dy))
        case .scroll: self = .scroll(dx: try container.decode(Double.self, forKey: .dx), dy: try container.decode(Double.self, forKey: .dy))
        case .leftClick: self = .leftClick
        case .rightClick: self = .rightClick
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .move(dx, dy):
            try container.encode(Kind.move, forKey: .type); try container.encode(dx, forKey: .dx); try container.encode(dy, forKey: .dy)
        case let .scroll(dx, dy):
            try container.encode(Kind.scroll, forKey: .type); try container.encode(dx, forKey: .dx); try container.encode(dy, forKey: .dy)
        case .leftClick: try container.encode(Kind.leftClick, forKey: .type)
        case .rightClick: try container.encode(Kind.rightClick, forKey: .type)
        }
    }
}
