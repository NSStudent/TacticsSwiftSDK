// Smothered mate.
//
// Matches checkmate given by a single knight when every square next to the
// mated king is occupied by the king's own pieces.
//
// Written for White mating Black; flipcolor finds the same pattern for Black.
cql()
mate
flipcolor {
  btm
  Checkers = A -> k
  #Checkers == 1
  Checkers & N
  (. <- k) in a
  comment ("smothered mate by " Checkers)
}
