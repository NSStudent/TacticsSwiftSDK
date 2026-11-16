// Skewer.
//
// Matches the position after a move by a bishop, rook or queen that attacks
// an enemy king, queen or rook, behind which (on the same line, with nothing
// in between) stands a less valuable enemy knight, bishop, rook or queen.
// When the front piece moves away the rear piece can be taken: it is
// undefended or worth more than the skewering piece. The skewering piece
// must be safe (see double-attack.cql).
//
// Written for White; flipcolor finds the same pattern for Black.
cql()
flipcolor {
  btm
  F = to & [QRB]
  Rear = square Y in [qrbn] {
    square X in ([kqr] <- F) {
      F -> X -> Y
      X & k or power X > power Y
    }
    not (a -> Y) or power Y > power F
  }
  Rear
  if (a -> F) {
    A -> F
    not square S in ([qrbnp] -> F) { power S < power F }
  }
  comment ("skewer by " F ", winning " Rear)
}
