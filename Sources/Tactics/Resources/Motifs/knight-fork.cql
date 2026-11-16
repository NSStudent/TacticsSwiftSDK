// Knight fork.
//
// Matches the position after a knight move that attacks two or more enemy
// pieces that are either worth more than a knight (king, queen, rook) or
// undefended bishops and knights. The forking knight must be safe: it is not
// attacked by a pawn, bishop or knight, and if anything else attacks it, it
// is defended.
//
// Written for White; flipcolor finds the same pattern for Black.
cql()
flipcolor {
  btm
  currentmove N--
  F = to
  Targets = square T in ([kqrbn] <- F) {
    T & [kqr] or not (a -> T)
  }
  #Targets >= 2
  not ([pbn] -> F)
  if (a -> F) then (A -> F)
  comment ("knight fork: " F " attacks " Targets)
}
