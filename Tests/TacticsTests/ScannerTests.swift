import CQL
import FischerCore
import Foundation
import Tactics
import Testing

@Suite struct CatalogueTests {
    @Test func builtInMotifsLoadAndCompile() throws {
        let ids = Motif.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for motif in Motif.all {
            #expect(motif.source.contains("cql("))
            #expect(!motif.summary.isEmpty)
            #expect(Motif.builtIn(id: motif.id) == motif)
        }
        _ = try TacticsScanner()
    }

    @Test func duplicateIdentifiersAreRejected() {
        #expect(throws: TacticsError.self) {
            try TacticsScanner(motifs: [.skewer, .skewer])
        }
    }

    @Test func invalidCustomMotifIsRejected() {
        let broken = Motif(id: "broken", name: "Broken", summary: "", source: "cql() {")
        #expect(throws: TacticsError.self) {
            try TacticsScanner(motifs: [broken])
        }
    }
}

@Suite struct ScannerTests {
    /// The test games as one PGN collection.
    static let collection = TestGames.all.joined(separator: "\n")

    @Test func occurrenceDetails() throws {
        let scanner = try TacticsScanner()
        let report = try scanner.scan(pgn: TestGames.blackburneShilling)
        let game = try #require(report.games.first)
        #expect(game.gameNumber == 1)
        #expect(game.tags["Event"] == "Blackburne Shilling")

        let fork = try #require(game.occurrences(of: .knightFork).first)
        #expect(fork.ply == 9)
        #expect(fork.positionID == 9)
        #expect(fork.side == .white)
        #expect(fork.moveNumber == 5)
        #expect(fork.san == "Nxf7")
        #expect(fork.uci == "e5f7")
        #expect(fork.path == MovePath([0, 0, 0, 0, 0, 0, 0, 0, 0]))
        #expect(fork.isMainline)
        #expect(fork.comments == ["knight fork: f7 attacks [g5,h8]"])
        #expect(fork.fenBefore?.hasPrefix("r1b1kbnr/pppp1ppp/8/4N1q1/2BnP3/8/PPPP1PPP/RNBQK2R w") == true)
        #expect(fork.fen?.hasPrefix("r1b1kbnr/pppp1Npp/8/6q1/2BnP3/8/PPPP1PPP/RNBQK2R b") == true)

        let mate = try #require(game.occurrences(of: .smotheredMate).first)
        #expect(mate.moveText == "7... Nf3#")
        #expect(mate.side == .black)
        // Occurrences are in game order.
        #expect(game.occurrences.map(\.ply) == game.occurrences.map(\.ply).sorted())
    }

    @Test func fischerCoreGame() throws {
        let annotated = try AnnotatedPGNGame(pgn: TestGames.blackburneShilling)
        let game = try #require(annotated.tree.game(at: annotated.tree.mainlineEnd()))
        let scanner = try TacticsScanner(motifs: [.smotheredMate, .knightFork])

        let fromGame = try scanner.scan(game: game)
        #expect(fromGame.occurrences.compactMap(\.moveText) == ["5. Nxf7", "7... Nf3#"])

        let fromAnnotated = try scanner.scan(game: annotated, gameNumber: 7)
        #expect(fromAnnotated.gameNumber == 7)
        #expect(fromAnnotated.occurrences.map(\.motifID) == ["knightFork", "smotheredMate"])
    }

    @Test func gameWithoutMotifs() throws {
        let scanner = try TacticsScanner()
        let tactics = try scanner.scan(game: AnnotatedPGNGame(pgn: "1. e4 e5 2. Nf3 Nc6 *"))
        #expect(tactics.occurrences.isEmpty)
        let report = try scanner.scan(pgn: "1. e4 e5 2. Nf3 Nc6 *")
        #expect(report.gamesExamined == 1)
        #expect(report.games.isEmpty)
    }

    @Test func countsOverTheCollection() throws {
        let report = try TacticsScanner().scan(pgn: Self.collection)
        #expect(report.gamesExamined == TestGames.all.count)
        #expect(report.occurrenceCounts["knightFork"] == 3)
        #expect(report.gameCounts["promotion"] == 3)
        #expect(report.occurrenceCounts["backRankMate"] == 4)
        #expect(report.games.map(\.gameNumber) == report.games.map(\.gameNumber).sorted())
    }

    @Test func parallelAndSerialRunsAgree() throws {
        func signature(_ report: TacticsReport) -> [String] {
            report.games.flatMap { game in
                game.occurrences.map { "\(game.gameNumber) \($0.motifID) \($0.positionID) \($0.comments)" }
            }
        }
        var serial = TacticsScanner.Options()
        serial.concurrency = 1
        var parallel = TacticsScanner.Options()
        parallel.concurrency = 4
        parallel.batchSize = 2
        let a = try TacticsScanner(options: serial).scan(pgn: Self.collection)
        let b = try TacticsScanner(options: parallel).scan(pgn: Self.collection)
        #expect(!signature(a).isEmpty)
        #expect(signature(a) == signature(b))
        #expect(a.occurrenceCounts == b.occurrenceCounts)
    }

    @Test func fileInputAndStreaming() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tactics-\(UUID().uuidString).pgn")
        try Self.collection.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let scanner = try TacticsScanner()
        let whole = try scanner.scan(contentsOf: url, blockSize: 256)
        #expect(whole.gamesExamined == TestGames.all.count)

        var streamed: [Int] = []
        let summary = try scanner.scan(contentsOf: url, blockSize: 512) { game in
            streamed.append(game.gameNumber)
        }
        #expect(streamed == Array(1 ... TestGames.all.count))
        #expect(summary.games.isEmpty)
        #expect(summary.occurrenceCounts == whole.occurrenceCounts)
    }

    @Test func handlerErrorsStopTheScan() throws {
        struct Stop: Error {}
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tactics-\(UUID().uuidString).pgn")
        try Self.collection.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: Stop.self) {
            try TacticsScanner().scan(contentsOf: url) { _ in throw Stop() }
        }
    }

    @Test func pgnDataInput() throws {
        let report = try TacticsScanner(motifs: [.skewer]).scan(pgnData: Data(TestGames.skewer.utf8))
        #expect(report.games.first?.occurrences.first?.moveText == "1. Rh8+")
    }

    @Test func unreadableGamesAreSkipped() throws {
        let broken = TestGames.pgn("Broken", fen: "not a fen", "1. e4 *")
        let pgn = [TestGames.skewer, broken, TestGames.doubleCheck].joined(separator: "\n")
        let report = try TacticsScanner(motifs: [.skewer, .doubleCheck]).scan(pgn: pgn)
        #expect(report.gamesExamined == 2)
        #expect(report.skippedGames.map(\.gameNumber) == [2])
        #expect(report.games.map(\.gameNumber) == [1, 3])

        var strict = TacticsScanner.Options()
        strict.onInvalidGame = { _ in .abort }
        #expect(throws: TacticsError.self) {
            try TacticsScanner(motifs: [.skewer], options: strict).scan(pgn: pgn)
        }
    }

    @Test func partiallyReadGamesAreReported() throws {
        // 3. Nxf9 is not a move: the game is searched up to it.
        let pgn = "[Event \"Partial\"]\n\n1. e4 e5 2. Nf3 Nc6 3. Nxf9 Nf6 *\n"
        let report = try TacticsScanner().scan(pgn: pgn)
        #expect(report.gamesExamined == 1)
        #expect(report.partiallyReadGames.map(\.gameNumber) == [1])
    }

    @Test func variationsAreSearchedOnRequest() throws {
        let pgn = TestGames.pgn("Variation", fen: "r3k3/8/8/1N6/8/8/8/4K3 w - - 0 1", "1. Kd2 (1. Nc7+ Kd7) 1... Kd8 *")
        let mainline = try TacticsScanner(motifs: [.knightFork]).scan(pgn: pgn)
        #expect(mainline.games.isEmpty)

        var options = TacticsScanner.Options()
        options.variations = true
        let all = try TacticsScanner(motifs: [.knightFork], options: options).scan(pgn: pgn)
        let occurrence = try #require(all.games.first?.occurrences.first)
        #expect(occurrence.moveText == "1. Nc7+")
        #expect(!occurrence.isMainline)
        #expect(occurrence.path == MovePath([1]))
        #expect(occurrence.positionID > 2)
    }

    @Test func customMotif() throws {
        let checks = Motif(id: "check", name: "Check", summary: "Any check.",
                           source: "cql() check comment(\"check\")")
        let scanner = try TacticsScanner(motifs: [checks, .doubleCheck])
        let tactics = try scanner.scan(game: AnnotatedPGNGame(pgn: TestGames.doubleCheck))
        #expect(tactics.occurrences.map(\.motifID) == ["check", "doubleCheck"])
        #expect(tactics.occurrences.first?.comments == ["check"])
    }

    @Test func customMotifWithPathRunsPerBatch() throws {
        // A ⊢ filter makes the engine run over whole batches on a large stack.
        let checkNext = Motif(id: "checkNext", name: "Check next", summary: "The next move checks.",
                              source: "cql() ⊢ ――(check)")
        let pgn = [TestGames.doubleCheck, TestGames.pawnPush, TestGames.directCheck].joined(separator: "\n")
        var options = TacticsScanner.Options()
        options.concurrency = 1
        let report = try TacticsScanner(motifs: [checkNext, .doubleCheck], options: options).scan(pgn: pgn)
        #expect(report.games.map(\.gameNumber) == [1, 3])
        #expect(report.games[0].occurrences.map(\.motifID) == ["checkNext", "doubleCheck"])
        #expect(report.games[0].occurrences.first?.ply == 0)
        #expect(report.games[1].occurrences(ofID: "checkNext").map(\.ply) == [0])
    }

    @Test func headerGameFiltersAreHonoured() throws {
        let whiteMates = Motif(id: "whiteMates", name: "White mates", summary: "", source: "cql(result 1-0) mate")
        let firstGameOnly = Motif(id: "firstGame", name: "First game", summary: "", source: "cql(gamenumber 1) mate")
        // `result` compares with the Result tag, as in CQLSwiftSDK.
        let pgn = [("1-0", TestGames.backRankMateWhite), ("0-1", TestGames.backRankMateBlack)]
            .map { "[Result \"\($0.0)\"]\n" + $0.1 }
            .joined(separator: "\n")
        let report = try TacticsScanner(motifs: [whiteMates, firstGameOnly, .backRankMate]).scan(pgn: pgn)
        #expect(report.occurrenceCounts["whiteMates"] == 1)
        #expect(report.occurrenceCounts["firstGame"] == 1)
        #expect(report.occurrenceCounts["backRankMate"] == 2)
        #expect(report.games.first?.occurrences(ofID: "whiteMates").first?.moveText == "1. Ra8#")
    }

    @Test func fenCanBeDisabled() throws {
        var options = TacticsScanner.Options()
        options.includeFEN = false
        let tactics = try TacticsScanner(motifs: [.skewer], options: options)
            .scan(game: AnnotatedPGNGame(pgn: TestGames.skewer))
        let occurrence = try #require(tactics.occurrences.first)
        #expect(occurrence.fen == nil)
        #expect(occurrence.fenBefore == nil)
    }
}
