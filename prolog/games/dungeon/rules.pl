:- module(dungeon_rules, [ direction/3,
                          roll_dirs/2,
                          opposite/2,
                          turn/4,
                          turn/5,
                          first_moves/5,
                          avoid_reverse/3,
                          move/6,
                          move/7,
                          finish/5,
                          near_stairs/2,
                          floor_index/3,
                          make_floor/6
                        ]).

/** <module> DUNGEON movement

The movement rules from the DUNGEON rules reference, shared by the
generator's validators and the tests. A floor is
`floor(W, H, Grid, Teleporters, Stairs, Adjacent)`, built by
make_floor/6:

  - Grid: compound with W*H args of cell codes. Only codes that change
    movement matter here: `#` wall, `L` locked door, `K` key, `T`
    teleporter, `W` spiderweb, `S` stairs; anything else is open floor.
  - Teleporters: `tp(A, B)` cell indexes, or `none`
  - Stairs: cell index
  - Adjacent: per cell, `n(N, NE, E, SE, S, SW, W, NW, Near)`: the
    neighbour indexes, 0 for wall or off the grid, and whether the cell
    is next to the stairs (precomputed: the validators ask hundreds of
    thousands of times)

Cells are addressed by a 1-based index `I = Y*W + X + 1`. Outside the
grid is wall (the stone border on the page).

A player state is `at(I, Last, Key)`: the cell, the direction last
travelled (`none` at the start of a floor) and whether the floor's key
has been picked up.
*/

%!  direction(?Name, ?DX, ?DY) is nondet.
%
%   Y grows downwards (row 0 is the top of the page).
direction(n,   0, -1).
direction(ne,  1, -1).
direction(e,   1,  0).
direction(se,  1,  1).
direction(s,   0,  1).
direction(sw, -1,  1).
direction(w,  -1,  0).
direction(nw, -1, -1).

%!  roll_dirs(+Roll, -Dirs) is det.
%
%   Odd rolls move diagonally, even rolls orthogonally.
roll_dirs(R, Dirs) :-
    (   R mod 2 =:= 0
    ->  Dirs = [n, e, s, w]
    ;   Dirs = [ne, se, sw, nw]
    ).

opposite(n, s).   opposite(s, n).   opposite(e, w).   opposite(w, e).
opposite(ne, sw). opposite(sw, ne). opposite(nw, se). opposite(se, nw).

%!  make_floor(+W, +H, +Grid, +Teleporters, +Stairs, -Floor) is det.
make_floor(W, H, G, Tele, Stairs, floor(W, H, G, Tele, Stairs, Adj)) :-
    N is W*H,
    functor(Adj, adj, N),
    forall(between(1, N, I),
           ( findall(J, ( member(D, [n, ne, e, se, s, sw, w, nw]),
                          step(W, H, G, I, D, J) ), Js),
             ( near(W, Stairs, I) -> Near = true ; Near = false ),
             append(Js, [Near], Args),
             Ns =.. [n|Args],
             nb_setarg(I, Adj, Ns) )).

step(W, H, G, I, D, J) :-
    direction(D, DX, DY),
    X is (I - 1) mod W + DX, Y is (I - 1) // W + DY,
    (   X >= 0, X < W, Y >= 0, Y < H,
        J0 is Y*W + X + 1,
        arg(J0, G, C), C \== 0'#
    ->  J = J0
    ;   J = 0
    ).

dir_index(n, 1). dir_index(ne, 2). dir_index(e, 3). dir_index(se, 4).
dir_index(s, 5). dir_index(sw, 6). dir_index(w, 7). dir_index(nw, 8).

floor_index(floor(W, H, _, _, _, _), X-Y, I) :-
    X >= 0, X < W, Y >= 0, Y < H,
    I is Y*W + X + 1.

cell(floor(_, _, G, _, _, _), I, C) :- arg(I, G, C).

%   The cell one step from I in direction D, if it can be entered: not a
%   wall, and not a locked door unless the key has been picked up.
next(F, I, D, Key, J) :-
    F = floor(_, _, G, _, _, Adj),
    dir_index(D, K),
    arg(I, Adj, Ns),
    arg(K, Ns, J),
    J > 0,
    (   arg(J, G, 0'L) -> Key == true ; true ).

passable(F, I, Key, D) :- next(F, I, D, Key, _).

%   N steps straight from I in direction D without meeting a wall.
straight(_, _, _, 0, _) :- !.
straight(F, I, Key, N, D) :-
    next(F, I, D, Key, J),
    N1 is N - 1,
    straight(F, J, Key, N1, D).

%   Drop the reverse of Last unless it's the only choice.
avoid_reverse(Dirs, Last, Pool) :-
    (   opposite(Last, Back), Dirs \== [Back]
    ->  exclude(==(Back), Dirs, Pool)
    ;   Pool = Dirs
    ).

%!  turn(+Floor, +State, +Roll, -Result) is nondet.
%
%   Every way a turn with this roll can end: `exit` (the player takes the
%   stairs) or a new `at(I, Last, Key)`. If no direction is open the
%   player stays put.
turn(F, State, Roll, Result) :-
    turn(F, State, Roll, Result, _).

%!  turn(+Floor, +State, +Roll, -Result, -Path) is nondet.
%
%   As turn/4, with the cells entered on the way, in order. Every object
%   on them is used.
turn(F, at(I, Last, Key), Roll, Result, Path) :-
    first_moves(F, I, Key, Roll, Pool0),
    avoid_reverse(Pool0, Last, Pool),
    (   Pool == []
    ->  finish(F, I, Last, Key, Result),
        Path = []
    ;   member(D, Pool),
        move(F, I, Key, Roll, D, Result, Path)
    ).

%!  first_moves(+Floor, +I, +Key, +Roll, -Dirs) is det.
%
%   Directions a move may start in, before ruling out going back: those
%   that go the full distance straight if there are any, else any open one.
first_moves(F, I, Key, Roll, Dirs) :-
    roll_dirs(Roll, All),
    include(passable(F, I, Key), All, Open),
    include(straight(F, I, Key, Roll), Open, Full),
    (   Full \== [] -> Dirs = Full ; Dirs = Open ).

%!  move(+Floor, +I, +Key, +Roll, +Dir, -Result) is nondet.
%!  move(+Floor, +I, +Key, +Roll, +Dir, -Result, -Path) is nondet.
%
%   Ways a move of Roll cells starting in direction Dir can end, and the
%   cells entered on the way.
move(F, I, Key, Roll, D, Result) :-
    move(F, I, Key, Roll, D, Result, _).

move(F, I, Key, Roll, D, Result, Path) :-
    roll_dirs(Roll, Dirs),
    walk(F, I, D, Roll, Key, Dirs, [], Result, Path).

%   Seen holds the cells entered so far, most recent first.
walk(F, I, D, 0, Key, _, Seen, Result, Path) :- !,
    finish(F, I, D, Key, Result),
    reverse(Seen, Path).
walk(F, I, D, N, Key, Dirs, Seen, Result, Path) :-
    (   next(F, I, D, Key, J)
    ->  enter(F, J, D, N, Key, Dirs, Seen, Result, Path)
    ;   % Blocked: turn to another open direction of the same kind.
        exclude(==(D), Dirs, Others),
        include(passable(F, I, Key), Others, Open),
        avoid_reverse(Open, D, Pool),
        (   Pool == []
        ->  finish(F, I, D, Key, Result),
            reverse(Seen, Path)
        ;   member(D2, Pool),
            walk(F, I, D2, N, Key, Dirs, Seen, Result, Path)
        )
    ).

%   Step onto J, which uses one cell of the move.
enter(F, J, _, _, _, _, Seen, exit, Path) :-
    cell(F, J, 0'S),                            % may take the stairs in passing
    reverse([J|Seen], Path).
enter(F, J, D, N, Key0, Dirs, Seen, Result, Path) :-
    cell(F, J, C),
    N1 is N - 1,
    (   C == 0'K -> Key = true ; Key = Key0 ),
    (   C == 0'W
    ->  finish(F, J, D, Key, Result),           % webs stop the move
        reverse([J|Seen], Path)
    ;   C == 0'T
    ->  F = floor(_, _, _, tp(A, B), _, _),
        (   J =:= A -> J2 = B ; J2 = A ),
        walk(F, J2, D, N1, Key, Dirs, [J|Seen], Result, Path)
    ;   walk(F, J, D, N1, Key, Dirs, [J|Seen], Result, Path)
    ).

%!  finish(+Floor, +I, +Last, +Key, -Result) is multi.
%
%   Stopping on I: take the stairs if they're in reach, or stay.
finish(F, I, _, _, exit) :-
    near_stairs(F, I).
finish(_, I, D, Key, at(I, D, Key)).

%!  near_stairs(+Floor, +I) is semidet.
%
%   On the stairs or one of the eight cells around them.
near_stairs(floor(_, _, _, _, _, Adj), I) :-
    arg(I, Adj, Ns),
    arg(9, Ns, true).

near(W, S, I) :-
    abs((I - 1) mod W - (S - 1) mod W) =< 1,
    abs((I - 1) // W - (S - 1) // W) =< 1.
