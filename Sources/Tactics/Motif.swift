import Foundation

/// A tactical motif: a small CQL 6.2 program that matches the positions
/// where the motif occurs.
///
/// Built-in motifs match the position *after* the key move (the fork, the
/// pinning move, the mating move…), so ``MotifOccurrence/san`` is the move
/// that creates the motif. Custom motifs can be created from any CQL source;
/// they report whatever positions their program matches.
public struct Motif: Sendable, Hashable, Identifiable, CustomStringConvertible {
    /// A broad family of motifs, useful to group results.
    public enum Category: String, Sendable, Hashable, CaseIterable {
        case fork
        case pin
        case skewer
        case discovery
        case mate
        case promotion
        case sacrifice
        case custom
    }

    /// A stable identifier, such as `"knightFork"`. Results are keyed by it.
    public let id: String
    /// A human-readable name, such as `"Knight fork"`.
    public let name: String
    public let category: Category
    /// An English description of what the CQL program matches.
    public let summary: String
    /// The CQL 6.2 program.
    public let source: String

    public init(id: String, name: String, category: Category = .custom, summary: String, source: String) {
        self.id = id
        self.name = name
        self.category = category
        self.summary = summary
        self.source = source
    }

    /// Reads a custom motif from a `.cql` file. The identifier defaults to the
    /// file name without its extension.
    public init(contentsOf url: URL, id: String? = nil, name: String? = nil, summary: String = "") throws {
        let source = try String(contentsOf: url, encoding: .utf8)
        let identifier = id ?? url.deletingPathExtension().lastPathComponent
        self.init(id: identifier, name: name ?? identifier, category: .custom, summary: summary, source: source)
    }

    public var description: String { id }
}

// MARK: - Built-in catalogue

public extension Motif {
    /// Every built-in motif, in catalogue order.
    static let all: [Motif] = [
        .knightFork, .doubleAttack,
        .absolutePin, .relativePin, .skewer,
        .discoveredAttack, .discoveredCheck, .doubleCheck,
        .backRankMate, .smotheredMate, .anastasiaMate, .arabianMate,
        .promotion, .underpromotion,
        .sacrifice,
    ]

    /// The built-in motif with the given identifier.
    static func builtIn(id: String) -> Motif? {
        all.first { $0.id == id }
    }

    static let knightFork = bundled(
        "knightFork", file: "knight-fork", name: "Knight fork", category: .fork,
        summary: """
        A knight move that attacks two or more enemy pieces worth more than a knight \
        (king, queen, rook) or undefended bishops and knights, from a square where it \
        cannot be taken by a pawn or minor piece and is defended if attacked.
        """)

    static let doubleAttack = bundled(
        "doubleAttack", file: "double-attack", name: "Double attack", category: .fork,
        summary: """
        A move (castling excluded) whose piece attacks two or more enemy targets: the \
        king, pieces worth more than the moving piece, or undefended pieces other than \
        pawns. No cheaper enemy piece attacks the moving piece, and it is defended if \
        attacked. Includes knight, pawn, bishop, rook, queen and king forks.
        """)

    static let absolutePin = bundled(
        "absolutePin", file: "absolute-pin", name: "Absolute pin", category: .pin,
        summary: """
        An enemy knight, bishop, rook or queen pinned to its king and under fire \
        (attacked by a cheaper piece, or attacked and undefended), where the moving \
        piece is the pinning piece or one of the attackers.
        """)

    static let relativePin = bundled(
        "relativePin", file: "relative-pin", name: "Relative pin", category: .pin,
        summary: """
        An enemy knight, bishop, rook or queen pinned to a more valuable queen or rook \
        that would be lost if the pinned piece moved, with the pinned piece under fire \
        and the moving piece as the pinner or one of the attackers.
        """)

    static let skewer = bundled(
        "skewer", file: "skewer", name: "Skewer", category: .skewer,
        summary: """
        A bishop, rook or queen move that attacks an enemy king, queen or rook with a \
        less valuable piece behind it on the same line; the rear piece is undefended \
        or worth more than the skewering piece, which is safe.
        """)

    static let discoveredAttack = bundled(
        "discoveredAttack", file: "discovered-attack", name: "Discovered attack", category: .discovery,
        summary: """
        A move that uncovers an attack by another bishop, rook or queen on an enemy \
        knight, bishop, rook or queen worth more than the line piece or undefended.
        """)

    static let discoveredCheck = bundled(
        "discoveredCheck", file: "discovered-check", name: "Discovered check", category: .discovery,
        summary: "A move that gives check with a piece other than the one that moved.")

    static let doubleCheck = bundled(
        "doubleCheck", file: "double-check", name: "Double check", category: .discovery,
        summary: "A move that checks the king with two pieces at once.")

    static let backRankMate = bundled(
        "backRankMate", file: "back-rank-mate", name: "Back-rank mate", category: .mate,
        summary: """
        Checkmate of a king on its first rank by a rook or queen along that rank, with \
        every square in front of the king occupied by its own pieces.
        """)

    static let smotheredMate = bundled(
        "smotheredMate", file: "smothered-mate", name: "Smothered mate", category: .mate,
        summary: """
        Checkmate by a single knight, with every square next to the king occupied by \
        its own pieces.
        """)

    static let anastasiaMate = bundled(
        "anastasiaMate", file: "anastasia-mate", name: "Anastasia's mate", category: .mate,
        summary: """
        Checkmate of a king on the a- or h-file by a rook or queen along the file, with \
        an own piece beside the king and a knight covering its diagonal flight squares.
        """)

    static let arabianMate = bundled(
        "arabianMate", file: "arabian-mate", name: "Arabian mate", category: .mate,
        summary: """
        Checkmate of a cornered king by a rook on an adjacent square, protected by a \
        knight.
        """)

    static let promotion = bundled(
        "promotion", file: "promotion", name: "Promotion", category: .promotion,
        summary: "A pawn promotes, to any piece.")

    static let underpromotion = bundled(
        "underpromotion", file: "underpromotion", name: "Underpromotion", category: .promotion,
        summary: "A pawn promotes to a rook, bishop or knight.")

    static let sacrifice = bundled(
        "sacrifice", file: "sacrifice", name: "Sacrifice", category: .sacrifice,
        summary: """
        A piece is given up: it is captured on the next move, leaving its side at \
        least two points behind, and is not regained at once. Within 10 plies the \
        sacrificing side mates, recovers the material or wins the game.
        """)

    /// The number of plies within which a ``sacrifice`` must pay off.
    static let sacrificeHorizon = 10
}

extension Motif {
    /// Loads a built-in motif from the package resources.
    static func bundled(_ id: String, file: String, name: String, category: Category, summary: String) -> Motif {
        guard let url = Bundle.module.url(forResource: file, withExtension: "cql", subdirectory: "Motifs"),
              let source = try? String(contentsOf: url, encoding: .utf8)
        else {
            fatalError("TacticsSwiftSDK: missing bundled motif Motifs/\(file).cql")
        }
        return Motif(id: id, name: name, category: category, summary: summary, source: source)
    }
}
