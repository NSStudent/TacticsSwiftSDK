@_exported import struct CQL.GameReadError
@_exported import enum CQL.InvalidGameDecision
import CQL
import FischerCore
import Foundation

/// Finds tactical motifs in PGN games by running each motif's CQL program
/// with CQLSwiftSDK.
///
/// ```swift
/// let scanner = try TacticsScanner()                 // every built-in motif
/// let report = try scanner.scan(contentsOf: pgnURL)
/// for game in report.games {
///     for occurrence in game.occurrences {
///         print(game.gameNumber, occurrence.motifID, occurrence.moveText ?? "")
///     }
/// }
/// ```
///
/// Each game is read once and every motif runs on the same position tree.
/// Batches of games are searched in parallel (see ``Options/concurrency``);
/// results are delivered in input order. A scanner is not thread-safe: use
/// it from one thread at a time, or create one scanner per thread.
public final class TacticsScanner {
    public struct Options: Sendable {
        /// Whether to search variations as well as the main line.
        public var variations = false
        /// Whether to compute ``MotifOccurrence/fen`` and ``MotifOccurrence/fenBefore``.
        public var includeFEN = true
        /// Number of batches searched in parallel.
        public var concurrency = max(1, ProcessInfo.processInfo.activeProcessorCount)
        /// Number of games in a batch.
        public var batchSize = 32
        /// Decides what happens when a game cannot be read. The default skips
        /// it (see ``TacticsReport/skippedGames``); return `.abort` to stop the
        /// run with ``TacticsError/aborted(_:)``.
        public var onInvalidGame: @Sendable (GameReadError) -> InvalidGameDecision = { _ in .skip }

        public init() {}
    }

    /// The motifs searched, in reporting order.
    public let motifs: [Motif]
    public let options: Options
    private let programs: [CQLProgram]
    /// One set of engines per parallel worker, created on demand.
    private var workers: [Worker] = []

    /// Compiles the CQL program of every motif.
    ///
    /// - Throws: ``TacticsError/invalidMotif(id:_:)`` or ``TacticsError/duplicateMotif(id:)``.
    public init(motifs: [Motif] = Motif.all, options: Options = Options()) throws(TacticsError) {
        var seen = Set<String>()
        var programs: [CQLProgram] = []
        for motif in motifs {
            guard seen.insert(motif.id).inserted else { throw .duplicateMotif(id: motif.id) }
            do {
                programs.append(try Parser.parse(motif.source))
            } catch {
                throw .invalidMotif(id: motif.id, error)
            }
        }
        self.motifs = motifs
        self.options = options
        self.programs = programs
        // Building the first worker also checks that every program can run.
        workers = [try Worker(motifs: motifs, programs: programs, options: options)]
    }

    // MARK: - Collections

    /// Scans every game of a PGN document.
    public func scan(pgn: String) throws(TacticsError) -> TacticsReport {
        try scan(pgnData: Data(pgn.utf8))
    }

    /// Scans PGN bytes (UTF-8, or Latin-1 line by line).
    public func scan(pgnData: Data) throws(TacticsError) -> TacticsReport {
        var report = TacticsReport()
        try typed { try process(PGNGameSplitter.chunks(in: pgnData), into: &report, keepGames: true) { _ in } }
        return report
    }

    /// Scans a PGN file, reading it incrementally. The report keeps every
    /// game with at least one occurrence.
    public func scan(contentsOf url: URL, blockSize: Int = 1 << 20) throws(TacticsError) -> TacticsReport {
        try typed { try scanFile(url, blockSize: blockSize, keepGames: true) { _ in } }
    }

    /// Scans a PGN file and hands each examined game (with or without
    /// occurrences) to `onGame`, in input order, as soon as its batch is done.
    ///
    /// Memory use does not grow with the file: the returned report holds the
    /// counts and the skipped games, but ``TacticsReport/games`` is empty.
    /// An error thrown by `onGame` stops the scan and is rethrown.
    public func scan(contentsOf url: URL, blockSize: Int = 1 << 20,
                     onGame: (GameTactics) throws -> Void) throws -> TacticsReport {
        try scanFile(url, blockSize: blockSize, keepGames: false, onGame: onGame)
    }

    // MARK: - Single games

    /// Scans one game read with fischer-core.
    public func scan(game: AnnotatedPGNGame, gameNumber: Int = 1) throws(TacticsError) -> GameTactics {
        try scan(gameTree: GameTree(game: game, gameNumber: gameNumber))
    }

    /// Scans the move history of a fischer-core `Game`.
    public func scan(game: Game, tags: [PGNTag: String] = [:]) throws(TacticsError) -> GameTactics {
        try scan(game: AnnotatedPGNGame(game: game, tags: tags))
    }

    /// Scans a game already expanded by CQLSwiftSDK.
    public func scan(gameTree: GameTree) throws(TacticsError) -> GameTactics {
        try workers[0].scan(trees: [gameTree])[0]
    }

    // MARK: - Pipeline

    /// Runs a throwing body whose only possible error is a ``TacticsError``.
    private func typed<T>(_ body: () throws -> T) throws(TacticsError) -> T {
        do {
            return try body()
        } catch let error as TacticsError {
            throw error
        } catch {
            preconditionFailure("unexpected error \(error)")
        }
    }

    private func scanFile(_ url: URL, blockSize: Int, keepGames: Bool,
                          onGame: (GameTactics) throws -> Void) throws -> TacticsReport {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw TacticsError.input("cannot open \(url.path): \(error.localizedDescription)")
        }
        defer { try? handle.close() }
        var chunker = PGNByteChunker()
        var report = TacticsReport()
        while true {
            let block: Data
            do {
                block = try handle.read(upToCount: blockSize) ?? Data()
            } catch {
                throw TacticsError.input("cannot read \(url.path): \(error.localizedDescription)")
            }
            if block.isEmpty { break }
            try process(chunker.consume(block), into: &report, keepGames: keepGames, onGame: onGame)
        }
        try process(chunker.finish(), into: &report, keepGames: keepGames, onGame: onGame)
        return report
    }

    /// Searches `chunks` in parallel batches and merges the results in order.
    private func process(_ chunks: [PGNGameChunk], into report: inout TacticsReport, keepGames: Bool,
                         onGame: (GameTactics) throws -> Void) throws {
        guard !chunks.isEmpty else { return }
        let size = max(1, options.batchSize)
        let batches = stride(from: 0, to: chunks.count, by: size).map { chunks[$0 ..< min($0 + size, chunks.count)] }
        let workerCount = min(max(1, options.concurrency), batches.count)
        while workers.count < workerCount {
            workers.append(try Worker(motifs: motifs, programs: programs, options: options))
        }

        let results = BatchResults(count: batches.count)
        if workerCount == 1 {
            for (index, batch) in batches.enumerated() { results[index] = workers[0].process(batch) }
        } else {
            let workers = self.workers
            DispatchQueue.concurrentPerform(iterations: workerCount) { worker in
                for index in stride(from: worker, to: batches.count, by: workerCount) {
                    results[index] = workers[worker].process(batches[index])
                }
            }
        }

        for outcome in results.all.joined() {
            switch outcome {
            case .unreadable(let failure):
                report.skippedGames.append(failure)
                if options.onInvalidGame(failure) == .abort { throw TacticsError.aborted(failure) }
            case .game(let tactics, let partial):
                if let partial { report.partiallyReadGames.append(partial) }
                report.add(tactics, keep: keepGames)
                try onGame(tactics)
            case .failure(let error):
                throw error
            }
        }
    }
}

// MARK: - Workers

/// The result of reading and searching one PGN game.
enum GameOutcome: @unchecked Sendable {
    case game(GameTactics, partial: GameReadError?)
    case unreadable(GameReadError)
    case failure(TacticsError)
}

/// Collects the outcome of each batch from several threads.
private final class BatchResults: @unchecked Sendable {
    private var storage: [[GameOutcome]]
    private let lock = NSLock()

    init(count: Int) { storage = Array(repeating: [], count: count) }

    subscript(index: Int) -> [GameOutcome] {
        get { lock.withLock { storage[index] } }
        set { lock.withLock { storage[index] = newValue } }
    }

    var all: [[GameOutcome]] { lock.withLock { storage } }
}

/// A private set of CQL engines, one per motif. Engines keep per-game state,
/// so each parallel worker needs its own.
final class Worker: @unchecked Sendable {
    let motifs: [Motif]
    let engines: [CQLEngine]
    let includeFEN: Bool

    init(motifs: [Motif], programs: [CQLProgram], options: TacticsScanner.Options) throws(TacticsError) {
        var engineOptions = CQLEngine.Options()
        engineOptions.variations = options.variations
        engineOptions.headerComments = false
        engineOptions.silent = true
        var engines: [CQLEngine] = []
        for (motif, program) in zip(motifs, programs) {
            do {
                engines.append(try CQLEngine(program: program, options: engineOptions))
            } catch {
                throw .invalidMotif(id: motif.id, error)
            }
        }
        self.motifs = motifs
        self.engines = engines
        self.includeFEN = options.includeFEN
    }

    /// Reads and searches a batch of PGN games.
    func process(_ chunks: ArraySlice<PGNGameChunk>) -> [GameOutcome] {
        var trees: [GameTree] = []
        var slots: [Result<Int, GameReadError>] = []
        for chunk in chunks {
            let gameNumber = chunk.index + 1
            do {
                let game = try chunk.annotatedGame()
                trees.append(GameTree(game: game, gameNumber: gameNumber, byteOffset: chunk.startByteOffset))
                slots.append(.success(trees.count - 1))
            } catch {
                slots.append(.failure(GameReadError(gameNumber: gameNumber, byteOffset: chunk.startByteOffset,
                                                    reason: String(describing: error))))
            }
        }
        let tactics: [GameTactics]
        do {
            tactics = try scan(trees: trees)
        } catch {
            return [.failure(error)]
        }
        return slots.map { slot in
            switch slot {
            case .failure(let failure):
                return .unreadable(failure)
            case .success(let index):
                let tree = trees[index]
                let partial = tree.source.issues.first.map {
                    GameReadError(gameNumber: tree.gameNumber, byteOffset: tree.byteOffset,
                                  reason: "stopped at \($0); later moves were ignored")
                }
                return .game(tactics[index], partial: partial)
            }
        }
    }

    /// Runs every motif over `trees` and returns one result per tree.
    func scan(trees: [GameTree]) throws(TacticsError) -> [GameTactics] {
        guard !trees.isEmpty else { return [] }
        // Match results to trees by identity: game numbers need not be unique.
        var indexOfTree: [ObjectIdentifier: Int] = [:]
        for (index, tree) in trees.enumerated() { indexOfTree[ObjectIdentifier(tree)] = index }
        var matches = Array(repeating: [(motif: Int, match: GameMatch)](), count: trees.count)
        for (motifIndex, engine) in engines.enumerated() {
            let result: CQLResult
            do {
                result = try engine.run(games: trees)
            } catch {
                throw .runtime(motifID: motifs[motifIndex].id, error)
            }
            for match in result.matches {
                guard let index = indexOfTree[ObjectIdentifier(match.game)] else { continue }
                matches[index].append((motifIndex, match))
            }
        }
        return trees.indices.map { build(trees[$0], matches[$0]) }
    }

    /// Turns the CQL matches of one game into occurrences.
    private func build(_ tree: GameTree, _ matches: [(motif: Int, match: GameMatch)]) -> GameTactics {
        guard !matches.isEmpty else {
            return GameTactics(gameNumber: tree.gameNumber, tags: tree.tags, occurrences: [])
        }
        var order: [Int: Int] = [:]
        var nodes: [Int: PositionNode] = [:]
        for (index, node) in tree.nodes.enumerated() {
            order[node.id] = index
            nodes[node.id] = node
        }

        var found: [(order: Int, motif: Int, node: PositionNode, comments: [String])] = []
        for (motif, match) in matches {
            var comments: [Int: [String]] = [:]
            for comment in match.comments { comments[comment.positionID, default: []].append(comment.text) }
            for id in match.matchedPositions {
                guard let node = nodes[id], let position = order[id] else { continue }
                found.append((position, motif, node, comments[id] ?? []))
            }
        }
        found.sort { ($0.order, $0.motif) < ($1.order, $1.motif) }

        var fens: [[Int]: String] = [:]
        if includeFEN {
            var paths = Set<[Int]>()
            for item in found {
                paths.insert(item.node.path)
                if !item.node.path.isEmpty { paths.insert(Array(item.node.path.dropLast())) }
            }
            fens = Self.fens(at: paths, in: tree.source.tree)
        }

        let occurrences = found.map { item -> MotifOccurrence in
            let node = item.node
            let move = node.path.isEmpty ? nil : tree.source.tree.node(at: MovePath(node.path))
            return MotifOccurrence(
                motifID: motifs[item.motif].id,
                positionID: node.id,
                ply: node.ply,
                path: MovePath(node.path),
                isMainline: node.isMainline,
                moveNumber: move.map { Int($0.moveNumber) },
                side: move?.color,
                san: move.map { String(describing: $0.san) },
                uci: move?.uci,
                fen: fens[node.path],
                fenBefore: node.path.isEmpty ? nil : fens[Array(node.path.dropLast())],
                comments: item.comments)
        }
        return GameTactics(gameNumber: tree.gameNumber, tags: tree.tags, occurrences: occurrences)
    }

    /// FENs of the positions at `paths`, replaying only the moves needed.
    static func fens(at paths: Set<[Int]>, in tree: AnnotatedMoveTree) -> [[Int]: String] {
        var prefixes = Set<[Int]>()
        for path in paths {
            for length in 0 ... path.count { prefixes.insert(Array(path.prefix(length))) }
        }
        var result: [[Int]: String] = [:]
        let start = tree.initialGame
        if paths.contains([]) { result[[]] = start.position.fen() }
        var work: [([Int], Game, [AnnotatedMoveNode])] = [([], start, tree.children)]
        while let (path, game, children) = work.popLast() {
            for (index, child) in children.enumerated() {
                let childPath = path + [index]
                guard prefixes.contains(childPath) else { continue }
                var next = game
                guard (try? next.execute(resolvedMove: child.move, considerHalfmoves: false)) != nil else { continue }
                if paths.contains(childPath) { result[childPath] = next.position.fen() }
                work.append((childPath, next, child.children))
            }
        }
        return result
    }
}
