:- module(dungeon, [notebook//1]).

/** <module> DUNGEON generator

A notebook is a run of floors with a shop after every few. Each floor is
a 13 x 13 grid inside a stone border. The generator splits it with one
wall into two sides, divides each side further, and sprinkles pillars.
The start goes on one side and the stairs on the other; on some floors
the dividing wall's only gap is a locked door, with its key on the
start side. Teleporters and spiderwebs, which change movement, go in
next, and the floor is only accepted if dungeon_evaluate says so: the
stairs are reachable, the player can't get stuck, and optimal play
takes a sensible number of turns. Coins, chests, enemies and hearts go
in last, getting tougher floor by floor. See docs/rules/dungeon.md.

Each row string uses `#` for wall and `.` for floor; everything placed
on a floor is in its `objects`.
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../rng').
:- use_module(dungeon/rules).
:- use_module(dungeon/evaluate).
:- use_module(dungeon/names).
:- use_module(dungeon/stock).

size(13, 13).
floors_per_notebook(30).
shop_every(5).
start_hp(10).
attempts_per_floor(40).

%   Optimal-play expected turns to reach the stairs. Below the band the
%   stairs are a formality; above it, a floor drags.
expected_band(4.0, 16.0).

notebook(_{floors: Floors, shops: Shops, items: Items, gem: Gem,
           start_hp: HP}) -->
    { floors_per_notebook(N), shop_every(K), start_hp(HP),
      Last is N - 1,
      findall(F, ( between(1, Last, F), F mod K =:= 0 ), Shops),
      findall(_{name: Name, price: Price, text: Text, once: Once},
              item(Name, Price, Text, Once), Items) },
    floors(1, N, Floors),
    gem(Gem).

%!  item(?Name, ?Price, ?Text, ?Once) is nondet.
%
%   Shop stock. Once items have a Used box.
item("Doubling Potion", 12, "Double one roll.", true).
item("Gambler", 10, "Roll once: on 4 or more gain 20¢, otherwise nothing.", false).
item("Scroll of Mulligan", 13, "Re-roll your die once.", true).

floors(N, Max, []) --> { N > Max }, !.
floors(N, Max, [F|Fs]) -->
    { attempts_per_floor(K) },
    floor(K, N, Max, F),
    { N1 is N + 1 },
    floors(N1, Max, Fs).

%   Keep drawing candidates until one passes. The last attempt is kept
%   if it's at least playable, so generation always terminates.
floor(K, N, Max, Dict) -->
    candidate(N, Max, Floor, Start, Sides),
    { expected_band(_, Cap), evaluate_floor(Floor, Start, Cap, Stats) },
    (   { acceptable(Stats) ; K =< 1, Stats = stats(_, _, _) }
    ->  { Stats = stats(_, _, Analysis) },
        contents(N, Max, Floor, Start, Sides, Analysis, Objects, Balance),
        { floor_dict(N, Floor, Start, Stats, Objects, Balance, Dict) }
    ;   { K1 is K - 1 },
        floor(K1, N, Max, Dict)
    ).

acceptable(stats(E, _, _)) :-
    expected_band(Lo, Hi),
    E >= Lo, E =< Hi.

%   `balance` is what a player rushing for the stairs should expect to
%   meet: HP lost, coins picked up, and the coins on the floor. Not
%   printed; it's there to check the generator.
floor_dict(N, Floor, Start, stats(E0, _, _), Objects, balance(D, RL, L),
           _{number: N, rows: Rows, start: [SX, SY], stairs: [TX, TY],
             objects: Objects, expected: E,
             balance: _{damage: D, route_loot: RL, loot: L}}) :-
    Floor = floor(W, H, G, _, Stairs, _),
    xy(W, Start, SX, SY),
    xy(W, Stairs, TX, TY),
    H1 is H - 1,
    findall(Row,
            ( between(0, H1, Y),
              findall(C, ( between(1, W, X1), I is Y*W + X1, arg(I, G, C0),
                           ( C0 == 0'# -> C = 0'# ; C = 0'. ) ), Cs),
              string_codes(Row, Cs) ),
            Rows),
    E is round(E0 * 100) / 100.

xy(W, I, X, Y) :- X is (I - 1) mod W, Y is (I - 1) // W.

index(W, X, Y, I) :- I is Y*W + X + 1.

% How each floor ramps ----------------------------------------------------

%   0.0 on the first floor, 1.0 on the last.
progress(N, Max, T) :- T is (N - 1) / max(1, Max - 1).

% Candidate floors --------------------------------------------------------

%   Sides is `sides(StartSide, OtherSide)`, lists of free cell indexes.
%   Layouts that leave a pocket cut off are drawn again.
candidate(N, Max, Floor, Start, Sides) -->
    { size(W, H), Cells is W*H,
      functor(G, g, Cells),
      forall(between(1, Cells, I), nb_setarg(I, G, 0'.)),
      progress(N, Max, T) },
    rand_chance(T * 0.5 + 0.15, Locked0),
    { N >= 4 -> Locked = Locked0 ; Locked = false },
    split(W, H, G, Locked, Split),
    { Depth is 1 + round(T * 2) },
    halves(Split, W, H, G, Depth),
    pillars(W, H, G),
    (   { connected(W, H, G) }
    ->  furnish(T, Locked, W, H, G, Split, Floor, Start, Sides)
    ;   candidate(N, Max, Floor, Start, Sides)
    ).

furnish(T, Locked, W, H, G, Split, Floor, Start, sides(A, B)) -->
    { side_cells(W, H, G, Split, Side1, Side2) },
    rand_member(First, [1, 2]),
    { First == 1 -> A0 = Side1, B0 = Side2 ; A0 = Side2, B0 = Side1 },
    rand_member(Start, A0),
    stairs(W, Start, B0, Stairs),
    { nb_setarg(Stairs, G, 0'S),
      subtract(A0, [Start], A1), subtract(B0, [Stairs], B1) },
    key(Locked, G, Start, W, A1, A2),
    teleporters(T, Locked, G, A2, B1, Tele, A3, B2),
    webs(T, G, Start, W, A3, B2, A, B),
    { make_floor(W, H, G, Tele, Stairs, Floor) }.

%   The dividing wall. Split is `v(X)` or `h(Y)`, the wall's column or row.
split(W, H, G, Locked, Split) -->
    rand_member(Dir, [v, h]),
    { Dir == v -> Len = H, Room = W ; Len = W, Room = H },
    { Lo = 4, Hi is Room - 5 },
    rand_int(Lo, Hi, At),
    { Split =.. [Dir, At] },
    (   { Locked == true }
    ->  rand_int(1, Len - 2, Gap),
        { line(Split, W, Len, G, At, Cells),
          forall(member(I, Cells), nb_setarg(I, G, 0'#)),
          nth0(Gap, Cells, Door),
          nb_setarg(Door, G, 0'L) }
    ;   { line(Split, W, Len, G, At, Cells),
          forall(member(I, Cells), nb_setarg(I, G, 0'#)) },
        gaps(Cells, G, Len)
    ).

line(v(_), W, Len, _, X, Cells) :-
    Last is Len - 1,
    findall(I, ( between(0, Last, Y), index(W, X, Y, I) ), Cells).
line(h(_), W, Len, _, Y, Cells) :-
    Last is Len - 1,
    findall(I, ( between(0, Last, X), index(W, X, Y, I) ), Cells).

%   Open one gap in a short wall, one or two in a long one, each one to
%   three cells wide.
gaps(Cells, G, Len) -->
    (   { Len =< 6 } -> { N = 1 } ; rand_int(1, 2, N) ),
    gap_list(N, Cells, G, Len).

gap_list(0, _, _, _) --> !.
gap_list(N, Cells, G, Len) -->
    rand_member(L0, [1, 1, 2, 2, 3]),
    { L is min(L0, Len - 1) },
    rand_int(0, Len - L, From),
    { To is From + L - 1,
      forall(( between(From, To, P), nth0(P, Cells, I) ), nb_setarg(I, G, 0'.)),
      N1 is N - 1 },
    gap_list(N1, Cells, G, Len).

%   Recursive division of both sides of the split, Depth levels deep.
halves(v(X), W, H, G, Depth) -->
    { XL is X - 1, XR is X + 1, X1 is W - 1, Y1 is H - 1 },
    divide(W, H, G, 0, 0, XL, Y1, Depth),
    divide(W, H, G, XR, 0, X1, Y1, Depth).
halves(h(Y), W, H, G, Depth) -->
    { YT is Y - 1, YB is Y + 1, X1 is W - 1, Y1 is H - 1 },
    divide(W, H, G, 0, 0, X1, YT, Depth),
    divide(W, H, G, 0, YB, X1, Y1, Depth).

%   Divide the chamber X0..X1, Y0..Y1 (inclusive) with a wall that has a
%   gap, then each part again. A wall never closes off an opening in the
%   wall it runs into.
divide(_, _, _, _, _, _, _, 0) --> !.
divide(W, H, G, X0, Y0, X1, Y1, Depth) -->
    { CW is X1 - X0 + 1, CH is Y1 - Y0 + 1, D1 is Depth - 1 },
    rand_chance(0.8, Go),
    (   { Go == true, CW >= CH, CW >= 5, CH >= 3 }
    ->  rand_int(X0 + 2, X1 - 2, X),
        { findall(I, ( between(Y0, Y1, Y), index(W, X, Y, I) ), Cells),
          wall(W, H, G, Cells, v) },
        gaps(Cells, G, CH),
        { XL is X - 1, XR is X + 1 },
        divide(W, H, G, X0, Y0, XL, Y1, D1),
        divide(W, H, G, XR, Y0, X1, Y1, D1)
    ;   { Go == true, CH >= 5, CW >= 3 }
    ->  rand_int(Y0 + 2, Y1 - 2, Y),
        { findall(I, ( between(X0, X1, X), index(W, X, Y, I) ), Cells),
          wall(W, H, G, Cells, h) },
        gaps(Cells, G, CW),
        { YT is Y - 1, YB is Y + 1 },
        divide(W, H, G, X0, Y0, X1, YT, D1),
        divide(W, H, G, X0, YB, X1, Y1, D1)
    ;   []
    ).

%   Wall in Cells, except an end cell next to an opening in the line.
wall(W, H, G, Cells, Dir) :-
    Cells = [First|_], last(Cells, Last),
    (   Dir == v -> Before = n, After = s ; Before = w, After = e ),
    forall(member(I, Cells),
           (   ( I == First, open_beyond(W, H, G, I, Before)
               ; I == Last, open_beyond(W, H, G, I, After) )
           ->  true
           ;   nb_setarg(I, G, 0'#)
           )).

open_beyond(W, H, G, I, D) :-
    xy(W, I, X, Y),
    direction(D, DX, DY),
    X1 is X + DX, Y1 is Y + DY,
    X1 >= 0, X1 < W, Y1 >= 0, Y1 < H,
    index(W, X1, Y1, J),
    arg(J, G, C), C \== 0'#.

%   A few free-standing blocks, 1x1 or 2x2, never touching another wall.
pillars(W, H, G) -->
    rand_int(1, 4, N),
    pillar_list(N, W, H, G).

pillar_list(0, _, _, _) --> !.
pillar_list(N, W, H, G) -->
    rand_member(S, [1, 1, 2]),
    rand_int(1, W - 1 - S, X),
    rand_int(1, H - 1 - S, Y),
    { S1 is S - 1,
      findall(I, ( between(0, S1, DX), between(0, S1, DY),
                   X1 is X + DX, Y1 is Y + DY, index(W, X1, Y1, I) ), Block),
      (   forall(( between(-1, S, DX), between(-1, S, DY),
                   X1 is X + DX, Y1 is Y + DY,
                   X1 >= 0, X1 < W, Y1 >= 0, Y1 < H, index(W, X1, Y1, I) ),
                 arg(I, G, 0'.))
      ->  forall(member(I, Block), nb_setarg(I, G, 0'#))
      ;   true
      ),
      N1 is N - 1 },
    pillar_list(N1, W, H, G).

%   Every open cell joins up orthogonally (a locked door counts as open).
connected(W, H, G) :-
    N is W*H,
    findall(I, ( between(1, N, I), arg(I, G, C), C \== 0'# ), [I0|Open]),
    flood([I0], W, H, G, [I0], Seen),
    length([I0|Open], L),
    length(Seen, L).

flood([], _, _, _, Seen, Seen).
flood([I|Is], W, H, G, Seen0, Seen) :-
    xy(W, I, X, Y),
    findall(J, ( member(DX-DY, [0-(-1), 1-0, 0-1, (-1)-0]),
                 X1 is X + DX, Y1 is Y + DY,
                 X1 >= 0, X1 < W, Y1 >= 0, Y1 < H,
                 index(W, X1, Y1, J),
                 arg(J, G, C), C \== 0'#,
                 \+ memberchk(J, Seen0) ), Js0),
    sort(Js0, Js),
    append(Js, Seen0, Seen1),
    append(Is, Js, Queue),
    flood(Queue, W, H, G, Seen1, Seen).

%   Free cells on each side of the split.
side_cells(W, H, G, Split, Side1, Side2) :-
    N is W*H,
    findall(I, ( between(1, N, I), arg(I, G, 0'.), side(Split, W, I, 1) ), Side1),
    findall(I, ( between(1, N, I), arg(I, G, 0'.), side(Split, W, I, 2) ), Side2).

side(v(At), W, I, S) :- xy(W, I, X, _), ( X < At -> S = 1 ; X > At -> S = 2 ).
side(h(At), W, I, S) :- xy(W, I, _, Y), ( Y < At -> S = 1 ; Y > At -> S = 2 ).

%   Stairs well away from the start when the far side has room.
stairs(W, Start, Cells, Stairs) -->
    { include(far_from(W, Start, 6), Cells, Far) },
    (   { Far \== [] } -> rand_member(Stairs, Far) ; rand_member(Stairs, Cells) ).

far_from(W, A, D, B) :- chebyshev(W, A, B, X), X >= D.

chebyshev(W, A, B, D) :-
    xy(W, A, AX, AY), xy(W, B, BX, BY),
    D is max(abs(AX - BX), abs(AY - BY)).

%   With a locked door, the key lies on the start side.
key(false, _, _, _, A, A) --> [].
key(true, G, Start, W, A0, A) -->
    { include(far_from(W, Start, 2), A0, Cs0), ( Cs0 == [] -> Cs = A0 ; Cs = Cs0 ) },
    rand_member(K, Cs),
    { nb_setarg(K, G, 0'K), subtract(A0, [K], A) }.

%   A teleporter pair on some floors. Behind a locked door both ends sit
%   on one side, so they never get around the lock.
teleporters(T, Locked, G, A0, B0, Tele, A, B) -->
    rand_chance(0.2 + T * 0.4, Has),
    (   { Has == false ; A0 == [] ; B0 == [] }
    ->  { Tele = none, A = A0, B = B0 }
    ;   { Locked == true }
    ->  rand_member(Side, [a, b]),
        { Side == a -> Pool = A0 ; Pool = B0 },
        shuffle(Pool, [P, Q|_]),   % both sides have far more than two cells
        { Tele = tp(P, Q) },
        { subtract(A0, [P, Q], A), subtract(B0, [P, Q], B) }
    ;   rand_member(P, A0),
        rand_member(Q, B0),
        { Tele = tp(P, Q), subtract(A0, [P], A), subtract(B0, [Q], B) }
    ),
    { Tele = tp(X, Y) -> nb_setarg(X, G, 0'T), nb_setarg(Y, G, 0'T) ; true }.

webs(T, G, Start, W, A0, B0, A, B) -->
    { N0 is 1 + round(T * 2) },
    rand_int(N0 - 1, N0, N),
    { append(A0, B0, All), include(far_from(W, Start, 2), All, Pool) },
    shuffle(Pool, Shuffled),
    { length(Shuffled, L), K is min(N, L),
      length(Webs, K), append(Webs, _, Shuffled),
      forall(member(I, Webs), nb_setarg(I, G, 0'W)),
      subtract(A0, Webs, A), subtract(B0, Webs, B) }.

% Contents ----------------------------------------------------------------

%   Everything on the floor as dicts for the template: the movement
%   objects already in the grid, then what dungeon_stock places.
contents(N, Max, Floor, Start, sides(A, B), Analysis, Objects, Balance) -->
    { Floor = floor(W, H, G, _, _, _),
      progress(N, Max, T),
      Cells is W * H,
      findall(O, ( between(1, Cells, I), arg(I, G, C), fixed(C, Kind),
                   object(W, o(I, Kind, null), O) ),
              Fixed),
      append(A, B, Free) },
    stock(T, Floor, Start, Free, Analysis, Stocked, Balance),
    { maplist(object(W), Stocked, Placed),
      append(Fixed, Placed, Objects) }.

fixed(0'L, lock).
fixed(0'K, key).
fixed(0'T, teleporter).
fixed(0'W, web).

object(W, o(I, Kind, Value), _{x: X, y: Y, kind: Kind, value: Value}) :-
    xy(W, I, X, Y).
