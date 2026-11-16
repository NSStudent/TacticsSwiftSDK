// Back-rank mate.
//
// Matches checkmate of a king on its first rank by a rook or queen checking
// along that rank, when every square in front of the king (on its second
// rank) is occupied by the king's own pieces.
//
// Written for White mating Black; flipcolor finds the same pattern for Black.
cql()
mate
flipcolor {
  btm
  k & a-h8
  Checkers = [QR] & a-h8 & (A -> k)
  Checkers
  (a-h7 <- k) in a
  comment ("back-rank mate by " Checkers)
}
