// Arabian mate.
//
// Matches checkmate of a king in a corner by a rook on an adjacent square,
// when the rook is protected by a knight.
//
// Written for White mating Black on h8; flipcolor and flip find the same
// pattern for Black and in every corner.
cql()
mate
flipcolor flip {
  btm
  k & h8
  R & h7
  N -> h7
  comment ("Arabian mate by " R & h7)
}
