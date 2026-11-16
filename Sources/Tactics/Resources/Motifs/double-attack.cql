// Double attack (fork by any piece).
//
// Matches the position after a move whose moving piece attacks two or more
// enemy pieces, counting the king, pieces worth more than the moving piece,
// and undefended knights, bishops, rooks and queens. Castling is ignored.
// The moving piece must be safe: no cheaper enemy piece attacks it, and if
// it is attacked at all, it is defended. A king can only fork undefended
// pieces. Knight forks are a special case of this motif.
//
// Written for White; flipcolor finds the same pattern for Black.
cql()
flipcolor {
  btm
  not castle
  F = to
  Targets = square T in ([kqrbn] <- F) {
    T & k
    or (not (F & K) and power T > power F)
    or not (a -> T)
  }
  #Targets >= 2
  if (a -> F) {
    A -> F
    not square S in ([qrbnp] -> F) { power S < power F }
  }
  comment ("double attack: " F " attacks " Targets)
}
