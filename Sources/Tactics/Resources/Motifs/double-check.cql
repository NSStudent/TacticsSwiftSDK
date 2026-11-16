// Double check.
//
// Matches the position after a move that checks the king with two pieces
// at once. Only a king move can answer it.
//
// Written for White; flipcolor finds the same pattern for Black.
cql()
flipcolor {
  btm
  check
  Checkers = A -> k
  #Checkers >= 2
  comment ("double check by " Checkers)
}
