// Anastasia's mate.
//
// Matches checkmate of a king on the h-file (or, mirrored, the a-file) by a
// single rook or queen checking along that file, while one of the king's
// own pieces blocks the square beside it on the g-file and a knight covers
// at least one of the king's diagonal flight squares on the g-file.
//
// Written for White mating Black; flipcolor and flipvertical find the same
// pattern for Black and on the a-file.
cql()
mate
flipcolor flipvertical {
  btm
  k & h1-8
  Checkers = A -> k
  #Checkers == 1
  Checkers & [QR] & h1-8
  left 1 k & a
  (g1-8 & ~left 1 k & (. <- k)) <- N
  comment ("Anastasia's mate by " Checkers)
}
