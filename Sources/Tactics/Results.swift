import CQL
import FischerCore

/// One position of a game where a motif occurs.
public struct MotifOccurrence: Sendable, Hashable {
    /// The ``Motif/id`` of the motif.
    public let motifID: String
    /// The CQL `positionid` of the matched position. Mainline positions are
    /// numbered by ply; variation positions follow.
    public let positionID: Int
    /// Number of plies from the initial position.
    public let ply: Int
    /// Path of the move in the fischer-core annotated move tree
    /// (`AnnotatedMoveTree`); empty for the initial position.
    public let path: MovePath
    /// Whether the position is on the main line.
    public let isMainline: Bool
    /// Fullmove number of the move that led to the position (`nil` at the
    /// initial position).
    public let moveNumber: Int?
    /// The side that played the move (`nil` at the initial position).
    public let side: PlayerColor?
    /// The move that led to the position, in SAN (`nil` at the initial position).
    public let san: String?
    /// The same move in UCI notation.
    public let uci: String?
    /// FEN of the matched position (after the move), when
    /// ``TacticsScanner/Options/includeFEN`` is set.
    public let fen: String?
    /// FEN of the position before the move: the starting point of a puzzle.
    public let fenBefore: String?
    /// Comments the motif's CQL program placed at this position.
    public let comments: [String]

    /// The move in a readable form, such as `"23. Nc7+"` or `"23... Nc2+"`.
    public var moveText: String? {
        guard let san, let moveNumber, let side else { return nil }
        return side == .white ? "\(moveNumber). \(san)" : "\(moveNumber)... \(san)"
    }
}

/// The motifs found in one game.
public struct GameTactics: Sendable {
    /// 1-based position of the game in its input.
    public let gameNumber: Int
    /// The PGN tags of the game.
    public let tags: [String: String]
    /// Every occurrence, ordered by position (PGN order) and then by catalogue order.
    public let occurrences: [MotifOccurrence]

    /// The occurrences of one motif.
    public func occurrences(of motif: Motif) -> [MotifOccurrence] {
        occurrences(ofID: motif.id)
    }

    /// The occurrences of the motif with the given identifier.
    public func occurrences(ofID id: String) -> [MotifOccurrence] {
        occurrences.filter { $0.motifID == id }
    }

    /// The identifiers of the motifs found in the game, without repetition.
    public var motifIDs: Set<String> { Set(occurrences.map(\.motifID)) }

    /// A short description such as `"Carlsen, M - Caruana, F"`.
    public var title: String {
        "\(tags["White"] ?? "?") - \(tags["Black"] ?? "?")"
    }
}

/// The outcome of scanning a PGN collection.
public struct TacticsReport: Sendable {
    /// Games with at least one occurrence, in input order. Empty when the
    /// games were delivered through a handler instead.
    public internal(set) var games: [GameTactics] = []
    /// Number of games read and searched.
    public internal(set) var gamesExamined = 0
    /// Games that could not be read and were skipped.
    public internal(set) var skippedGames: [GameReadError] = []
    /// Games that were searched only up to an unreadable or illegal move.
    public internal(set) var partiallyReadGames: [GameReadError] = []
    /// Number of occurrences of each motif, keyed by ``Motif/id``.
    public internal(set) var occurrenceCounts: [String: Int] = [:]
    /// Number of games in which each motif occurs, keyed by ``Motif/id``.
    public internal(set) var gameCounts: [String: Int] = [:]

    public init() {}

    mutating func add(_ game: GameTactics, keep: Bool) {
        gamesExamined += 1
        guard !game.occurrences.isEmpty else { return }
        for occurrence in game.occurrences { occurrenceCounts[occurrence.motifID, default: 0] += 1 }
        for id in game.motifIDs { gameCounts[id, default: 0] += 1 }
        if keep { games.append(game) }
    }
}

/// Errors raised by ``TacticsScanner``.
public enum TacticsError: Error, Sendable, CustomStringConvertible {
    /// A motif's CQL program could not be compiled.
    case invalidMotif(id: String, CQLError)
    /// Two motifs share the same identifier.
    case duplicateMotif(id: String)
    /// A CQL program failed while running.
    case runtime(motifID: String, CQLError)
    /// The input could not be opened or read.
    case input(String)
    /// The run was stopped by ``TacticsScanner/Options/onInvalidGame``.
    case aborted(GameReadError)

    public var description: String {
        switch self {
        case .invalidMotif(let id, let error): "motif \(id): \(error)"
        case .duplicateMotif(let id): "duplicate motif identifier \(id)"
        case .runtime(let id, let error): "motif \(id): \(error)"
        case .input(let message): message
        case .aborted(let error): "cannot read PGN \(error)"
        }
    }
}
