import Foundation
import Tactics

let usage = """
usage: tactics-swift [options] <file.pgn>

Prints the tactical motifs found in every game of a PGN file, followed by a
table of counts.

options:
  -m, --motifs id,id,...   search only these built-in motifs (default: all)
  --cql file.cql           also search a custom motif (repeatable; its id is the file name)
  -c, --counts             print only the table of counts
  --fen                    print the FEN before each key move
  --variations             search variations as well as the main line
  -j, --jobs N             number of batches searched in parallel
  --strict                 stop at the first unreadable game instead of skipping it
  -l, --list               list the built-in motifs and exit
  -h, --help               show this help
"""

struct CommandLineError: Error, CustomStringConvertible {
    let description: String
}

func standardError(_ text: String) {
    FileHandle.standardError.write(Data((text + "\n").utf8))
}

func padded(_ text: String, _ width: Int, right: Bool = false) -> String {
    let padding = String(repeating: " ", count: max(0, width - text.count))
    return right ? padding + text : text + padding
}

func listMotifs() {
    let width = Motif.all.map(\.id.count).max() ?? 0
    for motif in Motif.all {
        print("\(padded(motif.id, width))  \(motif.name): \(motif.summary)")
    }
}

func run() throws -> Int32 {
    var arguments = Array(CommandLine.arguments.dropFirst())
    var motifIDs: [String]?
    var customFiles: [String] = []
    var countsOnly = false
    var showFEN = false
    var options = TacticsScanner.Options()
    var input: String?

    func value(for option: String) throws -> String {
        guard !arguments.isEmpty else { throw CommandLineError(description: "\(option) needs a value") }
        return arguments.removeFirst()
    }

    while !arguments.isEmpty {
        let argument = arguments.removeFirst()
        switch argument {
        case "-h", "--help":
            print(usage)
            return 0
        case "-l", "--list":
            listMotifs()
            return 0
        case "-m", "--motifs":
            motifIDs = try value(for: argument).split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        case "--cql":
            customFiles.append(try value(for: argument))
        case "-c", "--counts":
            countsOnly = true
        case "--fen":
            showFEN = true
        case "--variations":
            options.variations = true
        case "-j", "--jobs":
            guard let jobs = Int(try value(for: argument)), jobs > 0 else {
                throw CommandLineError(description: "\(argument) needs a positive number")
            }
            options.concurrency = jobs
        case "--strict":
            options.onInvalidGame = { _ in .abort }
        default:
            if argument.hasPrefix("-") { throw CommandLineError(description: "unknown option \(argument)") }
            guard input == nil else { throw CommandLineError(description: "only one PGN file can be given") }
            input = argument
        }
    }
    guard let input else {
        standardError(usage)
        return 2
    }

    var motifs = try (motifIDs ?? Motif.all.map(\.id)).map { id in
        guard let motif = Motif.builtIn(id: id) else {
            throw CommandLineError(description: "unknown motif \(id) (see --list)")
        }
        return motif
    }
    for path in customFiles {
        motifs.append(try Motif(contentsOf: URL(fileURLWithPath: path)))
    }
    options.includeFEN = showFEN

    let scanner = try TacticsScanner(motifs: motifs, options: options)
    let start = Date()
    let report = try scanner.scan(contentsOf: URL(fileURLWithPath: input)) { game in
        guard !countsOnly, !game.occurrences.isEmpty else { return }
        print("Game \(game.gameNumber): \(game.title)")
        for occurrence in game.occurrences {
            var line = "  \(padded(occurrence.moveText ?? "start", 12)) \(occurrence.motifID)"
            if !occurrence.isMainline { line += " (variation)" }
            if !occurrence.comments.isEmpty { line += "  {\(occurrence.comments.joined(separator: "; "))}" }
            print(line)
            if showFEN, let fen = occurrence.fenBefore { print("      \(fen)") }
        }
    }
    let elapsed = Date().timeIntervalSince(start)

    for failure in report.skippedGames { standardError("warning: skipped \(failure)") }
    for failure in report.partiallyReadGames { standardError("warning: \(failure)") }

    if !countsOnly { print("") }
    let width = max(5, motifs.map(\.id.count).max() ?? 0)
    print("\(padded("motif", width))  occurrences   games")
    for motif in motifs {
        let occurrences = String(report.occurrenceCounts[motif.id] ?? 0)
        let games = String(report.gameCounts[motif.id] ?? 0)
        print("\(padded(motif.id, width))  \(padded(occurrences, 11, right: true))  \(padded(games, 6, right: true))")
    }
    print(String(format: "%d games examined, %d skipped, %.1f s", report.gamesExamined,
                 report.skippedGames.count, elapsed))
    return 0
}

do {
    exit(try run())
} catch {
    standardError("error: \(error)")
    exit(1)
}
