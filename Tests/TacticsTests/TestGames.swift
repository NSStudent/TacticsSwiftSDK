import FischerCore
import Foundation
import Testing

/// Small hand-made games used by the tests. Most start from a FEN so that the
/// key move is the first or second move. Every game is checked to be legal by
/// fischer-core in strict mode (see `LegalityTests`).
enum TestGames {
    static func pgn(_ name: String, fen: String? = nil, _ moves: String) -> String {
        var text = "[Event \"\(name)\"]\n"
        if let fen { text += "[FEN \"\(fen)\"]\n[SetUp \"1\"]\n" }
        return text + "\n\(moves)\n"
    }

    // MARK: Forks

    static let knightForkWhite = pgn("Knight fork (White)", fen: "r3k3/8/8/1N6/8/8/8/4K3 w - - 0 1", "1. Nc7+ *")
    static let knightForkBlack = pgn("Knight fork (Black)", fen: "4k3/8/8/8/1n6/8/8/R3K3 b - - 0 1", "1... Nc2+ *")
    /// The knight attacks king and rook but the bishop on b8 takes it.
    static let knightForkRefuted = pgn("Fork refuted by a bishop", fen: "rb2k3/8/8/1N6/8/8/8/4K3 w - - 0 1", "1. Nc7+ *")
    static let queenFork = pgn("Queen fork", fen: "r3k3/8/8/8/8/8/8/4K2Q w - - 0 1", "1. Qe4+ *")
    static let pawnFork = pgn("Pawn fork", fen: "4k3/8/8/2n1b3/8/2PP4/8/4K3 w - - 0 1", "1. d4 *")
    /// The Blackburne Shilling trap: a knight fork on f7, then a smothered mate.
    static let blackburneShilling = pgn("Blackburne Shilling", """
        1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4 4. Nxe5 Qg5 5. Nxf7 Qxg2 6. Rf1 Qxe4+ 7. Be2 Nf3# 0-1
        """)

    // MARK: Pins and skewers

    static let absolutePinWhite = pgn("Absolute pin (White)", fen: "4k3/8/2n5/8/8/8/8/4KB2 w - - 0 1", "1. Bb5 *")
    static let absolutePinBlack = pgn("Absolute pin (Black)", fen: "4kb2/8/8/8/8/2N5/8/4K3 b - - 0 1", "1... Bb4 *")
    /// The pinned knight is defended by a pawn and attacked only by the bishop.
    static let pinOfDefendedKnight = pgn("Pin of a defended knight", fen: "4k3/1p6/2n5/8/8/8/8/4KB2 w - - 0 1", "1. Bb5 *")
    /// The pawn on d7 stands between the bishop and the king: no pin.
    static let blockedPin = pgn("Blocked pin", fen: "4k3/3p4/2n5/8/8/8/8/4KB2 w - - 0 1", "1. Bb5 *")
    /// Re1 pins the rook to the king, but the pinned rook can take the
    /// undefended pinner along the line.
    static let pinnerCanBeTaken = pgn("Pinner can be taken", fen: "4k3/8/8/4r3/8/8/8/R5K1 w - - 0 1", "1. Re1 *")
    static let relativePin = pgn("Relative pin", fen: "3qk3/8/5n2/4P3/8/8/8/2B1K3 w - - 0 1", "1. Bg5 *")
    /// Bg5 pins the knight to the queen, but the knight is defended and only
    /// attacked by the bishop.
    static let relativePinNotUnderFire = pgn("Relative pin, knight not under fire", fen: "3qk3/8/5n2/8/8/8/8/2B1K3 w - - 0 1", "1. Bg5 *")
    static let skewer = pgn("Skewer", fen: "q3k3/8/8/8/8/8/8/4K2R w - - 0 1", "1. Rh8+ *")
    /// The rook behind the king is defended by the bishop: the queen cannot win it.
    static let skewerOfDefendedRook = pgn("Skewer of a defended rook", fen: "r3k3/1b6/8/8/8/8/8/4K2Q w - - 0 1", "1. Qh8+ *")

    // MARK: Discoveries

    /// Nc5 uncovers the rook's attack on the queen and attacks the rook on d7.
    static let discoveredAttack = pgn("Discovered attack", fen: "q3k3/3r4/8/8/N7/8/8/R3K3 w - - 0 1", "1. Nc5 *")
    /// Nc5 uncovers an attack on the queen but makes no second threat.
    static let discoveryWithoutSecondThreat = pgn("Discovery without a second threat",
                                                  fen: "q3k3/8/8/8/N7/8/8/R3K3 w - - 0 1", "1. Nc5 *")
    static let noDiscovery = pgn("Knight move without discovery", fen: "q3k3/8/8/8/N7/8/8/4K2R w - - 0 1", "1. Nc5 *")
    static let discoveredCheck = pgn("Discovered check", fen: "4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1", "1. Nc5+ *")
    static let doubleCheck = pgn("Double check", fen: "4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1", "1. Nf6+ *")
    static let directCheck = pgn("Direct check", fen: "4k3/8/8/8/8/8/8/R3K3 w - - 0 1", "1. Ra8+ *")

    // MARK: Mates

    static let backRankMateWhite = pgn("Back-rank mate (White)", fen: "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1", "1. Ra8# 1-0")
    static let backRankMateBlack = pgn("Back-rank mate (Black)", fen: "r5k1/8/8/8/8/8/5PPP/6K1 b - - 0 1", "1... Ra1# 0-1")
    /// Same position with luft on h6: the rook check is not mate.
    static let backRankWithLuft = pgn("Back rank with luft", fen: "6k1/5pp1/7p/8/8/8/8/R5K1 w - - 0 1", "1. Ra8+ Kh7 *")
    static let smotheredMate = pgn("Smothered mate", fen: "6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1", "1. Nf7# 1-0")
    static let anastasiaMate = pgn("Anastasia's mate", fen: "8/4N1pk/8/3R4/8/8/8/6K1 w - - 0 1", "1. Rh5# 1-0")
    static let anastasiaMateAFile = pgn("Anastasia's mate on the a-file", fen: "8/kp1N4/8/4R3/8/8/8/1K6 w - - 0 1", "1. Ra5# 1-0")
    static let arabianMate = pgn("Arabian mate", fen: "7k/8/5N2/8/8/8/8/K6R w - - 0 1", "1. Rh7# 1-0")
    static let arabianMateOnRank = pgn("Arabian mate along the rank", fen: "7k/8/5N2/8/8/8/8/K5R1 w - - 0 1", "1. Rg8# 1-0")

    // MARK: Promotions

    static let queenPromotion = pgn("Queen promotion", fen: "8/P7/8/8/8/8/8/2k1K3 w - - 0 1", "1. a8=Q *")
    static let knightUnderpromotion = pgn("Knight underpromotion", fen: "8/P7/8/8/8/8/8/2k1K3 w - - 0 1", "1. a8=N *")
    static let rookUnderpromotionBlack = pgn("Rook underpromotion (Black)", fen: "4K3/8/8/8/8/8/p7/2k5 b - - 0 1", "1... a1=R *")
    static let pawnPush = pgn("Pawn push", fen: "8/8/P7/8/8/8/8/2k1K3 w - - 0 1", "1. a7 *")

    // MARK: Sacrifices

    static let queenSacrifice = pgn("Queen sacrifice", fen: "2r3k1/5ppp/8/3Q4/8/8/1q3PPP/3R2K1 w - - 0 1",
                                    "1. Qd8+ Rxd8 2. Rxd8# 1-0")
    static let queenSacrificeBlack = pgn("Queen sacrifice (Black)", fen: "3r2k1/1Q3ppp/8/8/3q4/8/5PPP/2R3K1 b - - 0 1",
                                         "1... Qd1+ 2. Rxd1 Rxd1# 0-1")
    /// The queen is simply lost: no mate and no material back.
    static let unsoundSacrifice = pgn("Unsound sacrifice", fen: "2r3k1/5ppp/8/3Q4/8/8/1q3PPP/6K1 w - - 0 1",
                                      "1. Qd8+ Rxd8 2. h3 *")
    /// Nxd5 Nxd5 Qxd5 wins a pawn: the knight is regained at once.
    static let plainExchange = pgn("Plain exchange", fen: "4k3/8/5n2/3p4/8/4N3/3Q4/4K3 w - - 0 1",
                                   "1. Nxd5 Nxd5 2. Qxd5 *")

    /// Every game above, for the legality check.
    static let all: [String] = [
        knightForkWhite, knightForkBlack, knightForkRefuted, queenFork, pawnFork, blackburneShilling,
        absolutePinWhite, absolutePinBlack, pinOfDefendedKnight, blockedPin, pinnerCanBeTaken, relativePin, relativePinNotUnderFire,
        skewer, skewerOfDefendedRook,
        discoveredAttack, discoveryWithoutSecondThreat, noDiscovery, discoveredCheck, doubleCheck, directCheck,
        backRankMateWhite, backRankMateBlack, backRankWithLuft, smotheredMate, anastasiaMate, anastasiaMateAFile,
        arabianMate, arabianMateOnRank,
        queenPromotion, knightUnderpromotion, rookUnderpromotionBlack, pawnPush,
        queenSacrifice, queenSacrificeBlack, unsoundSacrifice, plainExchange,
    ]
}

/// Checks that every test game is legal according to fischer-core.
@Suite struct LegalityTests {
    @Test(arguments: TestGames.all)
    func gameIsLegal(_ pgn: String) throws {
        // Strict reading throws on the first illegal or unreadable move.
        let game = try AnnotatedPGNGame(pgn: pgn, strict: true)
        #expect(game.issues.isEmpty)
        // Every SAN token of the movetext was played.
        let movetext = pgn.split(separator: "\n").last { !$0.hasPrefix("[") && !$0.isEmpty } ?? ""
        let sanTokens = movetext.split(separator: " ").filter { token in
            !token.hasSuffix(".") && !["*", "1-0", "0-1", "1/2-1/2"].contains(token)
        }
        #expect(game.tree.mainline.count == sanTokens.count)
    }
}
