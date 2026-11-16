// Discovered attack.
//
// Matches the position after a move that uncovers an attack by another
// bishop, rook or queen of the moving side: the moving piece left a square
// between that line piece and an enemy knight, bishop, rook or queen, which
// is now attacked. The target is worth more than the line piece or is
// undefended. The moving piece makes a second threat at the same time: it
// gives check, or it attacks another enemy piece that is worth more than it
// or is undefended. King moves and castling are ignored. Discovered checks
// are reported by discovered-check.cql.
//
// Written for White; flipcolor finds the same pattern for Black.
cql()
flipcolor {
  btm
  not castle
  F = to & ~K
  Attackers = square L in ([QRB] & ~F) {
    square T in ([qrbn] <- L) {
      from & between(L T)
      power T > power L or not (a -> T)
      // the second threat, by the moving piece
      check
      or square U in ([qrbn] & ~T & (. <- F)) {
        power U > power F or not (a -> U)
      }
    }
  }
  Attackers
  comment ("discovered attack by " Attackers)
}
