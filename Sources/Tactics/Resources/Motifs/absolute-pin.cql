// Absolute pin that wins material.
//
// Matches the position after a move where an enemy knight, bishop, rook or
// queen is pinned to its own king and is "under fire": it is attacked by a
// cheaper piece of the moving side, or it is attacked and undefended. The
// moving piece must take part, either as the pinning piece or as one of
// the attackers of the pinned piece, and it must be safe (no cheaper enemy
// piece attacks it, and it is defended if attacked). Pins that merely
// restrict a defended piece (such as an early Bb5 against Nc6) are not
// reported.
//
// Written for White; flipcolor finds the same pattern for Black.
cql()
flipcolor {
  btm
  F = to
  Pinned = square T in (pin through [qrbn] to k) {
    // the pinned piece is under fire
    not (a -> T)
    or square S in ([QRBNP] -> T) { power S < power T }
    // the moving piece is the pinner or one of the attackers
    (pin from F through T to k) or (F -> T)
  }
  Pinned
  // the moving piece is safe: no cheaper enemy piece attacks it, and it
  // is defended if attacked (the pinned piece may capture along the line)
  if (a -> F) {
    A -> F
    not square S in ([qrbnp] -> F) { power S < power F }
  }
  comment ("absolute pin of " Pinned)
}
