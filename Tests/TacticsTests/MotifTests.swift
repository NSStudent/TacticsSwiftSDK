import Tactics
import Testing

/// A game and the moves (as ``MotifOccurrence/moveText``) where a motif must
/// be found. An empty list is a negative case.
struct MotifCase: Sendable, CustomTestStringConvertible {
    let motif: Motif
    let pgn: String
    let expected: [String]

    init(_ motif: Motif, _ pgn: String, _ expected: [String]) {
        self.motif = motif
        self.pgn = pgn
        self.expected = expected
    }

    var testDescription: String {
        let event = pgn.split(separator: "\"").dropFirst().first.map(String.init) ?? "?"
        return "\(motif.id): \(event) → \(expected.isEmpty ? "none" : expected.joined(separator: ", "))"
    }
}

typealias G = TestGames

let positiveCases: [MotifCase] = [
    MotifCase(.knightFork, G.knightForkWhite, ["1. Nc7+"]),
    MotifCase(.knightFork, G.knightForkBlack, ["1... Nc2+"]),
    MotifCase(.knightFork, G.blackburneShilling, ["5. Nxf7"]),
    MotifCase(.doubleAttack, G.queenFork, ["1. Qe4+"]),
    MotifCase(.doubleAttack, G.pawnFork, ["1. d4"]),
    MotifCase(.doubleAttack, G.knightForkBlack, ["1... Nc2+"]),
    MotifCase(.absolutePin, G.absolutePinWhite, ["1. Bb5"]),
    MotifCase(.absolutePin, G.absolutePinBlack, ["1... Bb4"]),
    MotifCase(.relativePin, G.relativePin, ["1. Bg5"]),
    MotifCase(.skewer, G.skewer, ["1. Rh8+"]),
    MotifCase(.discoveredAttack, G.discoveredAttack, ["1. Nc5"]),
    MotifCase(.discoveredCheck, G.discoveredCheck, ["1. Nc5+"]),
    MotifCase(.discoveredCheck, G.doubleCheck, ["1. Nf6+"]),
    MotifCase(.doubleCheck, G.doubleCheck, ["1. Nf6+"]),
    MotifCase(.backRankMate, G.backRankMateWhite, ["1. Ra8#"]),
    MotifCase(.backRankMate, G.backRankMateBlack, ["1... Ra1#"]),
    MotifCase(.backRankMate, G.queenSacrifice, ["2. Rxd8#"]),
    MotifCase(.smotheredMate, G.smotheredMate, ["1. Nf7#"]),
    MotifCase(.smotheredMate, G.blackburneShilling, ["7... Nf3#"]),
    MotifCase(.anastasiaMate, G.anastasiaMate, ["1. Rh5#"]),
    MotifCase(.anastasiaMate, G.anastasiaMateAFile, ["1. Ra5#"]),
    MotifCase(.arabianMate, G.arabianMate, ["1. Rh7#"]),
    MotifCase(.arabianMate, G.arabianMateOnRank, ["1. Rg8#"]),
    MotifCase(.promotion, G.queenPromotion, ["1. a8=Q"]),
    MotifCase(.promotion, G.rookUnderpromotionBlack, ["1... a1=R"]),
    MotifCase(.underpromotion, G.knightUnderpromotion, ["1. a8=N"]),
    MotifCase(.underpromotion, G.rookUnderpromotionBlack, ["1... a1=R"]),
    MotifCase(.sacrifice, G.queenSacrifice, ["1. Qd8+"]),
    MotifCase(.sacrifice, G.queenSacrificeBlack, ["1... Qd1+"]),
]

let negativeCases: [MotifCase] = [
    MotifCase(.knightFork, G.knightForkRefuted, []),
    MotifCase(.knightFork, G.queenFork, []),
    MotifCase(.doubleAttack, G.knightForkRefuted, []),
    MotifCase(.doubleAttack, G.plainExchange, []),
    MotifCase(.absolutePin, G.pinOfDefendedKnight, []),
    MotifCase(.absolutePin, G.blockedPin, []),
    MotifCase(.absolutePin, G.pinnerCanBeTaken, []),
    MotifCase(.absolutePin, G.relativePin, []),
    MotifCase(.relativePin, G.relativePinNotUnderFire, []),
    MotifCase(.relativePin, G.absolutePinWhite, []),
    MotifCase(.skewer, G.skewerOfDefendedRook, []),
    MotifCase(.skewer, G.directCheck, []),
    MotifCase(.discoveredAttack, G.noDiscovery, []),
    MotifCase(.discoveredAttack, G.discoveryWithoutSecondThreat, []),
    MotifCase(.discoveredAttack, G.discoveredCheck, []),
    MotifCase(.discoveredCheck, G.directCheck, []),
    MotifCase(.discoveredCheck, G.noDiscovery, []),
    MotifCase(.doubleCheck, G.discoveredCheck, []),
    MotifCase(.backRankMate, G.backRankWithLuft, []),
    MotifCase(.backRankMate, G.smotheredMate, []),
    MotifCase(.smotheredMate, G.backRankMateWhite, []),
    MotifCase(.smotheredMate, G.arabianMate, []),
    MotifCase(.anastasiaMate, G.arabianMate, []),
    MotifCase(.anastasiaMate, G.backRankMateWhite, []),
    MotifCase(.arabianMate, G.anastasiaMate, []),
    MotifCase(.arabianMate, G.smotheredMate, []),
    MotifCase(.promotion, G.pawnPush, []),
    MotifCase(.underpromotion, G.queenPromotion, []),
    MotifCase(.sacrifice, G.unsoundSacrifice, []),
    MotifCase(.sacrifice, G.plainExchange, []),
    MotifCase(.sacrifice, G.blackburneShilling, []),
]

@Suite struct MotifTests {
    func moves(of motif: Motif, in pgn: String) throws -> [String] {
        let scanner = try TacticsScanner(motifs: [motif])
        let report = try scanner.scan(pgn: pgn)
        #expect(report.gamesExamined == 1)
        #expect(report.skippedGames.isEmpty)
        #expect(report.partiallyReadGames.isEmpty)
        return report.games.flatMap(\.occurrences).compactMap(\.moveText)
    }

    @Test(arguments: positiveCases)
    func positive(_ test: MotifCase) throws {
        #expect(try moves(of: test.motif, in: test.pgn) == test.expected)
    }

    @Test(arguments: negativeCases)
    func negative(_ test: MotifCase) throws {
        #expect(try moves(of: test.motif, in: test.pgn) == [])
    }

    @Test func everyMotifHasPositiveAndNegativeCases() {
        for motif in Motif.all {
            #expect(positiveCases.contains { $0.motif.id == motif.id }, "no positive case for \(motif.id)")
            #expect(negativeCases.contains { $0.motif.id == motif.id }, "no negative case for \(motif.id)")
        }
    }
}
