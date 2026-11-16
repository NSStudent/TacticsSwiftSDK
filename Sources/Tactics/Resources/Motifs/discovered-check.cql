// Discovered check.
//
// Matches the position after a move that gives check with a piece other
// than the one that moved (including double checks and checks uncovered by
// an en passant capture).
//
// Written for White; flipcolor finds the same pattern for Black.
cql()
flipcolor {
  btm
  check
  Checkers = (A & ~to) -> k
  Checkers
  comment ("discovered check by " Checkers)
}
