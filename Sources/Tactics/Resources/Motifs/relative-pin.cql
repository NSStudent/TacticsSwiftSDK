// Relative pin that wins material.
//
// Matches the position after a move where an enemy knight, bishop, rook or
// queen stands in front of a more valuable enemy queen or rook (not the
// king) on the line of a bishop, rook or queen of the moving side. Moving
// the pinned piece would lose the piece behind it: that piece is worth more
// than the pinning piece, or it is undefended. The pinned piece is under
// fire (attacked by a cheaper piece, or attacked and undefended) and the
// moving piece is the pinner or one of the attackers. The moving piece must
// be safe (no cheaper enemy piece attacks it, and it is defended if
// attacked).
//
// Written for White; flipcolor finds the same pattern for Black.
cql()
flipcolor {
  btm
  F = to
  Pinned = square T in [qrbn] {
    // a pinner, the pinned piece T and a more valuable piece behind it
    square Rear in [qr] {
      power Rear > power T
      square Pinner in (pin from [QRB] through T to Rear) {
        power Rear > power Pinner or not (a -> Rear)
      }
      (pin from F through T to Rear) or (F -> T)
    }
    // the pinned piece is under fire
    A -> T
    not (a -> T)
    or square S in ([QRBNP] -> T) { power S < power T }
  }
  Pinned
  // the moving piece is safe: no cheaper enemy piece attacks it, and it
  // is defended if attacked (the pinned piece may capture along the line)
  if (a -> F) {
    A -> F
    not square S in ([qrbnp] -> F) { power S < power F }
  }
  comment ("relative pin of " Pinned)
}
