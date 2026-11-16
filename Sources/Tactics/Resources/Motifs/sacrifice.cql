// Sacrifice.
//
// Matches the position after a move whose piece is captured on the next
// move, leaving the moving side at least two points of material worse off
// than before the move (pawn 1, knight 3, bishop 3, rook 5, queen 9). The
// sacrifice must not be regained at once: after the moving side's next
// move it is still behind. It must pay off within 10 plies of the
// sacrifice: the opponent is checkmated, the material balance after an
// opponent move is back to its level before the sacrifice, or the game
// ends there with a win for the sacrificing side.
//
// Written for White; flipcolor finds the same pattern for Black.
cql()
flipcolor {
  btm
  not mate
  Before = parent:(power A - power a)
  S = to
  [x]S
  child:{
    power A - power a <= Before - 2
    child:(power A - power a < Before)
  }
  Limit = ply + 10
  find quiet {
    ply <= Limit
    {btm mate}
    or {wtm power A - power a >= Before}
    or {terminal result 1-0 }
  }
  comment ("sacrifice on " S)
}
