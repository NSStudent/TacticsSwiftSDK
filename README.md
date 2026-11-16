# TacticsSwiftSDK

A Swift package (SPM) that tags **tactical motifs** in real chess games: forks, pins, skewers, discovered attacks, typical mating patterns, promotions and sacrifices. Each motif is a small [CQL 6.2](https://www.gadycosteff.com/cql/) program, run with [CQLSwiftSDK](https://github.com/NSStudent/CQLSwiftSDK) over games read by [fischer-core](https://github.com/NSStudent/fischer-core).

For each game, the scanner reports where each motif occurs: the position (`positionid`, ply, move path), the move that created it (SAN and UCI), the FEN before and after the move, and any comments the CQL program generated.

## Installation

```swift
.package(url: "https://github.com/NSStudent/TacticsSwiftSDK.git", from: "0.1.0")
```

Then add `.product(name: "Tactics", package: "TacticsSwiftSDK")` to your target's dependencies. Requires Swift 6.0 or later, macOS 13 or iOS 16.

## Products

| Product | Kind | Description |
|---|---|---|
| `Tactics` | library | Motif catalogue (`Motif`) and scanner (`TacticsScanner`) |
| `tactics-swift` | executable | Prints the motifs found in a PGN file and a table of counts |

## Motif catalogue

Every built-in motif is a bundled `.cql` file in [`Sources/Tactics/Resources/Motifs`](Sources/Tactics/Resources/Motifs), exposed as a static `Motif` with an identifier, a name, a category and an English summary. `Motif.all` lists them in this order.

| Identifier | File | Definition |
|---|---|---|
| `knightFork` | `knight-fork.cql` | A knight move that attacks two or more enemy pieces worth more than a knight (king, queen, rook) or undefended bishops and knights. The knight is not attacked by a pawn or minor piece and is defended if attacked. |
| `doubleAttack` | `double-attack.cql` | Any move (castling excluded) whose piece attacks two or more targets: the king, pieces worth more than the moving piece, or undefended pieces other than pawns. No cheaper enemy piece attacks the moving piece and it is defended if attacked. Includes knight, pawn, bishop, rook, queen and king forks. |
| `absolutePin` | `absolute-pin.cql` | An enemy knight, bishop, rook or queen pinned to its king and *under fire* (attacked by a cheaper piece, or attacked and undefended). The moving piece is the pinner or one of the attackers, and is safe. |
| `relativePin` | `relative-pin.cql` | An enemy knight, bishop, rook or queen pinned to a more valuable queen or rook that would be lost if it moved (the rear piece is worth more than the pinner, or undefended). The pinned piece is under fire; the moving piece is the pinner or an attacker, and is safe. |
| `skewer` | `skewer.cql` | A bishop, rook or queen move that attacks an enemy king, queen or rook with a less valuable knight, bishop, rook or queen behind it on the same line. The rear piece is undefended or worth more than the skewering piece, which is safe. |
| `discoveredAttack` | `discovered-attack.cql` | A move that uncovers an attack by another bishop, rook or queen on an enemy knight, bishop, rook or queen (worth more than the line piece, or undefended), while the moving piece makes a second threat: check, or an attack on another piece worth more than it or undefended. King moves and castling are ignored. |
| `discoveredCheck` | `discovered-check.cql` | A move that gives check with a piece other than the one that moved. |
| `doubleCheck` | `double-check.cql` | A move that checks the king with two pieces at once. |
| `backRankMate` | `back-rank-mate.cql` | Checkmate of a king on its first rank by a rook or queen checking along that rank, with every square in front of the king occupied by its own pieces. |
| `smotheredMate` | `smothered-mate.cql` | Checkmate by a single knight, with every square next to the king occupied by its own pieces. |
| `anastasiaMate` | `anastasia-mate.cql` | Checkmate of a king on the a- or h-file by a single rook or queen along the file, with an own piece beside the king and a knight covering a diagonal flight square. |
| `arabianMate` | `arabian-mate.cql` | Checkmate of a cornered king by a rook on an adjacent square, protected by a knight. |
| `promotion` | `promotion.cql` | A pawn promotes, to any piece. |
| `underpromotion` | `underpromotion.cql` | A pawn promotes to a rook, bishop or knight. |
| `sacrifice` | `sacrifice.cql` | A piece is captured on the next move, leaving its side at least two points behind, and is not regained at once (the side is still behind after its next move). Within 10 plies (`Motif.sacrificeHorizon`) the sacrificing side mates, gets the material back (balance after an opponent move at least the level before the sacrifice), or the game ends there with its win. |

### How the motifs are written

- **Where a motif is reported.** Built-in motifs match the position *after* the key move (the forking move, the pinning move, the mating move, the sacrifice). `MotifOccurrence.san` is that move and `fenBefore` is the position where it was played: the starting point of a puzzle.
- **Both colours.** Each program is written for White and wrapped in `flipcolor`, which also finds the pattern for Black. Mating patterns add `flipvertical` (Anastasia, a- and h-file) or `flip` (Arabian, all four corners).
- **Material values** are CQL's `power`: pawn 1, knight 3, bishop 3, rook 5, queen 9, king 0.
- **"Safe" piece**: no cheaper enemy piece (pawn, knight, bishop, rook or queen) attacks it, and if anything attacks it, it is defended. A pinned enemy piece counts as an attacker, so a pin where the pinned piece can take an undefended pinner along the line is not reported.
- **Undefended**: not attacked by a piece of its own side. Attacks follow CQL: pinned pieces still attack, and attacks ignore whose turn it is.
- **Pins are only reported when they win something** (the pinned piece is under fire). Positional pins such as an early Bb5 against a defended Nc6, or Bg5 against Nf6 defended by the g7 pawn, are not reported.
- The motifs are **static heuristics**, not engine-verified puzzles: a fork whose victim has a stronger reply, or a sacrifice that "pays off" because the opponent later blunders, is still reported. Use them to find candidate positions, not to judge them.

Custom motifs are plain CQL. `Motif(id:name:summary:source:)` builds one from source text and `Motif(contentsOf:)` reads a `.cql` file; they run exactly like the built-in ones.

## Using the library

```swift
import Tactics

// Every built-in motif; pass `motifs:` to choose.
let scanner = try TacticsScanner()

let report = try scanner.scan(contentsOf: pgnURL)          // or scan(pgn:) / scan(pgnData:)
for game in report.games {                                 // games with at least one motif
    print("Game \(game.gameNumber): \(game.title)")
    for occurrence in game.occurrences {
        print(occurrence.moveText ?? "", occurrence.motifID, occurrence.comments)
        // occurrence.positionID, .ply, .path, .san, .uci, .side, .fen, .fenBefore
    }
}
print(report.occurrenceCounts["knightFork"] ?? 0, "knight forks in", report.gameCounts["knightFork"] ?? 0, "games")
```

`TacticsReport` also has `gamesExamined`, `skippedGames` and `partiallyReadGames`.

### Large files

`scan(contentsOf:onGame:)` reads the file incrementally and hands every game to a closure, in input order, without keeping the games in memory:

```swift
let summary = try scanner.scan(contentsOf: pgnURL) { game in
    for occurrence in game.occurrences(of: .smotheredMate) {
        savePuzzle(fen: occurrence.fenBefore!, solution: occurrence.uci!)
    }
}
print(summary.gamesExamined, summary.occurrenceCounts)
```

### fischer-core games

```swift
let fromPGN = try scanner.scan(game: annotatedPGNGame)                 // AnnotatedPGNGame
let fromGame = try scanner.scan(game: game, tags: [.white: "Morphy"])  // Game (its move history)
```

### Options

```swift
var options = TacticsScanner.Options()
options.variations = true          // also search variations (default: main line only)
options.includeFEN = false         // skip computing fen / fenBefore
options.concurrency = 4            // batches searched in parallel (default: all cores)
options.batchSize = 32             // games per batch
options.onInvalidGame = { error in
    print("skipping \(error)")
    return .skip                   // or .abort: the scan throws TacticsError.aborted
}
let scanner = try TacticsScanner(motifs: [.knightFork, .skewer, .sacrifice], options: options)
```

### Unreadable games

As in CQLSwiftSDK, a game that cannot be read (for example, an invalid `FEN` tag) is skipped and listed in `TacticsReport.skippedGames` with its game number, byte offset and reason; game numbers keep their position in the input. A game with an illegal or unreadable move is searched up to that move and listed in `partiallyReadGames`.

### How a scan runs

Each game is read once into a CQLSwiftSDK `GameTree`, and every motif's `CQLEngine` runs over the same tree. Games are processed in batches: each worker thread has its own set of engines (engines keep per-game state) and searches whole batches, and the results are merged in input order. A `TacticsScanner` is not thread-safe; use one per thread.

## Command line

```bash
swift run -c release tactics-swift games.pgn                 # occurrences, then counts
swift run -c release tactics-swift -c games.pgn              # counts only
swift run -c release tactics-swift -m knightFork,skewer --fen games.pgn
swift run -c release tactics-swift --cql my-motif.cql games.pgn
swift run tactics-swift --list
```

```
Game 21: ? - ?
  5. Nxf7      knightFork  {knight fork: f7 attacks [g5,h8]}
  5. Nxf7      doubleAttack  {double attack: f7 attacks [g5,h8]}
  7... Nf3#    smotheredMate  {smothered mate by f3}

motif             occurrences   games
knightFork                  3       3
...
```

Options: `-m/--motifs`, `--cql` (repeatable), `-c/--counts`, `--fen`, `--variations`, `-j/--jobs`, `--strict` (stop at the first unreadable game), `-l/--list`, `-h/--help`.

## Implementation status

**Done**

- 15 built-in motifs (table above), each with positive and negative tests on hand-made games whose legality is checked by fischer-core in strict mode, for both colours where the pattern is colour-flipped.
- Input from a PGN string, PGN bytes, a PGN file (read incrementally, with or without a per-game handler), a fischer-core `AnnotatedPGNGame` or `Game`, or a CQLSwiftSDK `GameTree`.
- Per occurrence: `positionid`, ply, move path, main line or variation, move number, side, SAN, UCI, FEN after and before the move, CQL comments.
- Parallel batches, results in input order; unreadable games skipped (or abort on request); optional variation search.
- Custom motifs from CQL source or `.cql` files.
- `tactics-swift` command-line tool.

On a sample of 5,789 games from the Lumbras Gigabase (OTB 2025), all 15 motifs ran in about 22 s of CPU time (16 s on 10 cores, release build). Most hits checked by hand were genuine tactics: Bxf7+ and Bxg6+ sacrifices, pawn forks, skewers of king and rook, pins of a queen by a rook. Occurrences (games): knight fork 707 (642), double attack 3,169 (2,302), absolute pin 728 (642), relative pin 480 (453), skewer 484 (433), discovered attack 556 (521), discovered check 455 (404), double check 67 (66), back-rank mate 17, smothered mate 3, Anastasia's mate 5, Arabian mate 4, promotion 776 (620), underpromotion 33 (32), sacrifice 874 (799).

**Not included**

- **Zugzwang** (optional in the brief): deciding that every move worsens the position needs evaluation, which CQL does not have.
- Motifs that need an engine to be meaningful (hanging pieces, "only move", defensive resources, interference, deflection, attraction, overloading, trapped pieces). They can be added as custom CQL motifs, but static rules would be noisy.
- The sacrifice horizon is fixed in the CQL file (10 plies); edit `sacrifice.cql` or use a custom copy to change it.

**CQLSwiftSDK gaps**

None of the motifs needed a CQL feature that CQLSwiftSDK 0.1.1 lacks (`line`, `move`, `rotate45`, `similarposition`, `hhdb`, `writefile`): moves are expressed with `――`/`currentmove`, sequences with `child`/`find`, and symmetry with `flipcolor`, `flipvertical` and `flip`.

Two limitations of the CQLSwiftSDK API affect performance, not results:

- Generated comments are only available through `CQLEngine` (`Evaluator`'s comment buffer is internal), and `CQLEngine` writes an annotated PGN for every matching game, which this package does not use.
- Each `CQLEngine.run` call starts a thread with a 512 MB stack; this package amortises it by running each engine over a batch of games.

## Development

```bash
swift build
swift test
```

## License

MIT. See [LICENSE](LICENSE).

Everything in this repository, including the bundled `.cql` motif files, is original work under the MIT license. No third-party code or data is bundled: the motifs were written from the CQL 6.2 documentation, and no lichess-puzzler code (AGPL) was used. Dependencies (CQLSwiftSDK, fischer-core) are fetched by Swift Package Manager under their own licenses.
