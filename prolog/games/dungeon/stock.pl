:- module(dungeon_stock, [ stock//7,
                          damage_band/3
                        ]).

/** <module> Stocking a DUNGEON floor

Puts the coins, chests, enemies and hearts on a floor whose layout has
already passed dungeon_evaluate, using its Visits: how often a player
rushing for the stairs walks over each cell. The aim is a real choice on
every floor, between the quick way down and the profitable one:

  - chests go in quiet corners, as far from the main route as possible,
    each with an enemy standing guard on its route side;
  - coins run in lines along walls away from the route, where sliding
    along a wall rewards reading the bounce, plus a couple of breadcrumbs
    on the route itself;
  - enemies go where players walk until the route costs a target amount
    of HP picked from damage_band/3, and the rest lurk near loot off
    the route, so greed costs HP too;
  - hearts sit off the route, half of them next to an enemy.

Each try is scored by what a rusher would meet: the HP the route costs
(it must fall in damage_band/3 for the floor) and the share of the loot
that is off it (at least min_off_share/1). The best of a few tries is
kept.

Objects are `o(Cell, Kind, Value)`, Value `null` for a mystery.
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../../rng').

route_visits(0.3).          % at least this: on the main route
quiet_visits(0.08).         % below this: off the beaten track
min_off_share(0.6).
tries(12).

%!  damage_band(+Progress, -Lo, -Hi) is det.
%
%   HP a player rushing straight for the stairs should expect to lose,
%   from the first floor (Progress 0.0) to the last (1.0).
damage_band(T, Lo, Hi) :-
    Lo is 1.0 + 2.0 * T,
    Hi is 3.0 + 3.5 * T.

%!  stock(+Progress, +Floor, +Start, +Free, +Analysis, -Objects, -Balance)// is det.
%
%   Balance is `balance(Damage, RouteLoot, Loot)`: expected HP lost and
%   coins picked up by a rusher, and the coins on the floor (chests at
%   3.5).
stock(T, Floor, Start, Free0, analysis(Visits, Reach, _), Objects, Balance) -->
    { include(reachable(Reach), Free0, Free),
      Floor = floor(W, H, G, _, _, _),
      route_visits(RV),
      include(visits_at_least(Visits, RV), Free, Route),
      Cells is W*H,
      functor(Dist, dist, Cells),
      forall(member(I, Free), ( route_distance(W, Route, I, D), nb_setarg(I, Dist, D) )),
      Ctx = ctx(W, H, G, Visits, Free, Start, Dist) },
    budget(T, Budget),
    { damage_band(T, Lo, Hi) },
    rand_int(round(Lo * 10), round(Hi * 10), Target10),
    { Target is Target10 / 10, tries(K) },
    best_try(K, T, Budget, Target, Ctx, none, best(_, Objects, Balance)).

reachable(Reach, I) :- arg(I, Reach, true).

visits_at_least(Visits, Min, I) :- arg(I, Visits, V), V >= Min.
visits_below(Visits, Max, I) :- arg(I, Visits, V), V < Max.

%   Chebyshev distance to the nearest route cell (99 with no route).
route_distance(_, [], _, 99) :- !.
route_distance(W, Route, I, D) :-
    xy(W, I, X, Y),
    foldl([J, D0, D1]>>( xy(W, J, JX, JY),
                         D1 is min(D0, max(abs(X - JX), abs(Y - JY))) ),
          Route, 99, D).

xy(W, I, X, Y) :- X is (I - 1) mod W, Y is (I - 1) // W.

% Budget ------------------------------------------------------------------

%   How much of each thing this floor gets. Enemies grow in number and
%   strength floor by floor.
budget(T, b(Coins, Chests, Enemies, Hearts)) -->
    rand_int(9, 12, Coins),
    rand_member(Chests, [1, 1, 1, 2, 2]),
    { E0 is 4 + round(T * 5) },
    rand_int(E0, E0 + 2, NE),
    { EMin is 1 + round(T), EMax is 2 + round(T * 3) },
    values(NE, EMin, EMax, 0.12, Enemies0),
    { sort(0, @>=, Enemies0, Enemies) },          % strongest stand guard
    rand_int(4, 6, NH),
    { HMax is 3 + round(T) },
    values(NH, 1, HMax, 0.15, Hearts).

%   Printed values, or null for a mystery (roll for it).
values(0, _, _, _, []) --> !.
values(N, Lo, Hi, P, [V|Vs]) -->
    rand_chance(P, Mystery),
    rand_int(Lo, Hi, V0),
    { Mystery == true -> V = null ; V = V0 },
    { N1 is N - 1 },
    values(N1, Lo, Hi, P, Vs).

% Tries -------------------------------------------------------------------

best_try(0, _, _, _, _, Best, Best) --> !.
best_try(K, T, Budget, Target, Ctx, Best0, Best) -->
    try(Budget, Target, Ctx, Objects),
    { score(T, Ctx, Objects, Penalty, Balance),
      Try = best(Penalty, Objects, Balance),
      (   Best0 = best(P0, _, _), P0 =< Penalty -> Best1 = Best0 ; Best1 = Try ) },
    (   { Penalty =:= 0 }
    ->  { Best = Best1 }
    ;   { K1 is K - 1 },
        best_try(K1, T, Budget, Target, Ctx, Best1, Best)
    ).

score(T, ctx(_, _, _, Visits, _, _, _), Objects, Penalty, balance(Damage, RouteLoot, Loot)) :-
    foldl(tally(Visits), Objects, t(0, 0, 0), t(Damage0, RouteLoot0, Loot)),
    Damage is round(Damage0 * 10) / 10,
    RouteLoot is round(RouteLoot0 * 10) / 10,
    damage_band(T, Lo, Hi),
    min_off_share(MinOff),
    (   Loot > 0 -> Off is 1 - RouteLoot0 / Loot ; Off = 1 ),
    Penalty is max(0, Lo - Damage0) + max(0, Damage0 - Hi) + 5 * max(0, MinOff - Off).

tally(Visits, o(I, Kind, V), t(D0, R0, L0), t(D, R, L)) :-
    arg(I, Visits, X), P is min(1.0, X),
    worth(V, Worth),
    (   Kind == enemy -> D is D0 + P * Worth, R = R0, L = L0
    ;   Kind == coin  -> D = D0, R is R0 + P, L is L0 + 1
    ;   Kind == chest -> D = D0, R is R0 + P * 3.5, L is L0 + 3.5
    ;   D = D0, R = R0, L = L0
    ).

worth(null, 3.5) :- !.
worth(V, V).

try(b(Coins, Chests, Enemies, Hearts), Target, Ctx, Objects) -->
    chests(Chests, Ctx, [], O1),
    coin_rows(Coins, Ctx, O1, O2, Left),
    loose_coins(Left, Ctx, O2, O3),
    guards(Enemies, Ctx, O3, O4, Rest0),
    shuffle(Rest0, Rest),
    route_enemies(Rest, Target, Ctx, O4, O5, Lurkers),
    lurkers(Lurkers, Ctx, O5, O6),
    hearts(Hearts, Ctx, O6, Objects).

% Placing -----------------------------------------------------------------

open_cells(ctx(_, _, _, _, Free, _, _), Os, Cells) :-
    exclude(taken(Os), Free, Cells).

taken(Os, I) :- memberchk(o(I, _, _), Os).

%   Chests in the quietest corners: the cells farthest from the route.
chests(0, _, Os, Os) --> !.
chests(N, Ctx, Os0, Os) -->
    { Ctx = ctx(_, _, _, Visits, _, _, Dist),
      open_cells(Ctx, Os0, Cells),
      quiet_visits(Q),
      include(visits_below(Visits, Q), Cells, Quiet0),
      ( Quiet0 == [] -> Quiet = Cells ; Quiet = Quiet0 ),
      map_list_to_pairs([I, D]>>arg(I, Dist, D), Quiet, Keyed),
      keysort(Keyed, Asc), reverse(Asc, Desc), pairs_values(Desc, Far),
      length(Far, L), K is min(4, L), length(Top, K), append(Top, _, Far) },
    (   { Top == [] }
    ->  { Os = Os0 }
    ;   rand_member(I, Top),
        { N1 is N - 1 },
        chests(N1, Ctx, [o(I, chest, null)|Os0], Os)
    ).

%   One or two lines of coins along walls, away from the route.
coin_rows(Coins, Ctx, Os0, Os, Left) -->
    (   { Coins >= 8 } -> rand_int(1, 2, Rows) ; { Rows = 1 } ),
    rows(Rows, Coins, Ctx, Os0, Os, Left).

rows(0, Left, _, Os, Os, Left) --> !.
rows(N, Coins, Ctx, Os0, Os, Left) -->
    { Ctx = ctx(W, H, G, Visits, _, _, _),
      open_cells(Ctx, Os0, Cells),
      route_visits(RV),
      include(visits_below(Visits, RV), Cells, Off),
      findall(I-Side, ( member(I, Off), wall_side(W, H, G, I, Side) ), Starts) },
    (   { Starts == [] ; Coins < 2 }
    ->  { Os = Os0, Left = Coins }
    ;   rand_member(I-Side, Starts),
        { memberchk(Side, [n, s]) -> Along = [e, w] ; Along = [n, s] },
        rand_member(D, Along),
        rand_int(2, min(4, Coins), L),
        { line(W, H, I, D, L, Off, Line),
          findall(o(C, coin, null), member(C, Line), New),
          append(New, Os0, Os1),
          length(Line, Placed),
          Coins1 is Coins - Placed, N1 is N - 1 },
        rows(N1, Coins1, Ctx, Os1, Os, Left)
    ).

%   A wall (or the border) right next to I, on side Side.
wall_side(W, H, G, I, Side) :-
    xy(W, I, X, Y),
    member(Side-(DX-DY), [n-(0-(-1)), s-(0-1), e-(1-0), w-((-1)-0)]),
    X1 is X + DX, Y1 is Y + DY,
    (   X1 < 0 ; Y1 < 0 ; X1 >= W ; Y1 >= H
    ;   J is Y1*W + X1 + 1, arg(J, G, 0'#)
    ), !.

%   Up to L cells from I going D, while they're in Allowed.
line(_, _, _, _, 0, _, []) :- !.
line(W, H, I, D, L, Allowed, [I|Is]) :-
    memberchk(I, Allowed), !,
    xy(W, I, X, Y),
    dir_step(D, DX, DY),
    X1 is X + DX, Y1 is Y + DY,
    L1 is L - 1,
    (   L1 > 0, X1 >= 0, Y1 >= 0, X1 < W, Y1 < H
    ->  J is Y1*W + X1 + 1,
        line(W, H, J, D, L1, Allowed, Is)
    ;   Is = []
    ).
line(_, _, _, _, _, _, []).

dir_step(n, 0, -1). dir_step(s, 0, 1). dir_step(e, 1, 0). dir_step(w, -1, 0).

%   The rest of the coins: two breadcrumbs on the route, others anywhere
%   off it.
loose_coins(0, _, Os, Os) --> !.
loose_coins(N, Ctx, Os0, Os) -->
    { Ctx = ctx(_, _, _, Visits, _, _, _),
      open_cells(Ctx, Os0, Cells),
      route_visits(RV),
      partition(visits_at_least(Visits, RV), Cells, Route, Off),
      Crumbs is min(2, N),
      Rest is N - Crumbs },
    pick_some(Crumbs, Route, coin, Os0, Os1),
    pick_some(Rest, Off, coin, Os1, Os).

pick_some(0, _, _, Os, Os) --> !.
pick_some(_, [], _, Os, Os) --> !.
pick_some(N, Cells, Kind, Os0, Os) -->
    rand_member(I, Cells),
    { exclude(==(I), Cells, Cells1), N1 is N - 1 },
    pick_some(N1, Cells1, Kind, [o(I, Kind, null)|Os0], Os).

%   Each chest gets the strongest enemy left, on its neighbour nearest
%   the route (the one with the most traffic).
guards(Enemies, Ctx, Os0, Os, Rest) -->
    { findall(I, member(o(I, chest, _), Os0), Chests),
      foldl(guard(Ctx), Chests, Enemies-Os0, Rest-Os) }.

guard(Ctx, Chest, Es0-Os0, Es-Os) :-
    Ctx = ctx(W, H, _, Visits, _, _, _),
    open_cells(Ctx, Os0, Cells),
    findall(V-J, ( neighbour(W, H, Chest, J), memberchk(J, Cells), arg(J, Visits, V) ), Ns),
    (   Es0 = [E|Es1], Ns \== []
    ->  max_member(_-J, Ns),
        Os = [o(J, enemy, E)|Os0], Es = Es1
    ;   Os = Os0, Es = Es0
    ).

%   Cells next to an object of Kind.
around(W, H, Kind, Os, Cells) :-
    findall(J, ( member(o(I, Kind, _), Os), neighbour(W, H, I, J) ), Cells0),
    sort(Cells0, Cells).

neighbour(W, H, I, J) :-
    xy(W, I, X, Y),
    member(DX, [-1, 0, 1]), member(DY, [-1, 0, 1]),
    (DX, DY) \== (0, 0),
    X1 is X + DX, Y1 is Y + DY,
    X1 >= 0, Y1 >= 0, X1 < W, Y1 < H,
    J is Y1*W + X1 + 1.

%   Enemies go where players walk, picked with odds by traffic and
%   never right next to the start, until the route costs Target HP. The
%   ones left over are Lurkers.
route_enemies([], _, _, Os, Os, []) --> !.
route_enemies(Es, Target, _, Os0, Os, Es) -->
    { Target =< 0 }, !,
    { Os = Os0 }.
route_enemies([E|Es], Target, Ctx, Os0, Os, Lurkers) -->
    { Ctx = ctx(W, H, _, Visits, _, Start, _),
      open_cells(Ctx, Os0, Cells0),
      findall(J, neighbour(W, H, Start, J), Near),
      exclude([I]>>( I =:= Start ; memberchk(I, Near) ), Cells0, Cells),
      findall(Wt-I, ( member(I, Cells), arg(I, Visits, V), Wt is round((V + 0.03) * 1000) ), Weighted) },
    (   { Weighted == [] }
    ->  { Os = Os0, Lurkers = [E|Es] }
    ;   weighted_member(I, Weighted),
        { arg(I, Visits, V), worth(E, Worth),
          Target1 is Target - min(1.0, V) * Worth },
        route_enemies(Es, Target1, Ctx, [o(I, enemy, E)|Os0], Os, Lurkers)
    ).

%   Leftover enemies wait off the route, next to coins when they can.
lurkers([], _, Os, Os) --> !.
lurkers([E|Es], Ctx, Os0, Os) -->
    { Ctx = ctx(W, H, _, Visits, _, _, _),
      open_cells(Ctx, Os0, Cells),
      route_visits(RV),
      include(visits_below(Visits, RV), Cells, Off),
      around(W, H, coin, Os0, Around),
      include([I]>>memberchk(I, Around), Off, Near),
      ( Near \== [] -> Pool = Near ; Pool = Off ) },
    (   { Pool == [] }
    ->  { Os = Os0 }
    ;   rand_member(I, Pool),
        lurkers(Es, Ctx, [o(I, enemy, E)|Os0], Os)
    ).

weighted_member(X, Pairs) -->
    { foldl([Wt-_, S0, S]>>(S is S0 + Wt), Pairs, 0, Total) },
    rand_int(0, Total - 1, R),
    { pick_weighted(Pairs, R, X) }.

pick_weighted([Wt-X|Rest], R, Y) :-
    (   R < Wt -> Y = X ; R1 is R - Wt, pick_weighted(Rest, R1, Y) ).

%   Hearts off the route, every other one next to an enemy.
hearts(Hs, Ctx, Os0, Os) -->
    hearts(Hs, true, Ctx, Os0, Os).

hearts([], _, _, Os, Os) --> !.
hearts([V|Vs], Guarded, Ctx, Os0, Os) -->
    { Ctx = ctx(W, H, _, Visits, _, _, _),
      open_cells(Ctx, Os0, Cells),
      route_visits(RV),
      include(visits_below(Visits, RV), Cells, Off0),
      ( Off0 == [] -> Off = Cells ; Off = Off0 ),
      (   Guarded == true,
          around(W, H, enemy, Os0, Around),
          include([I]>>memberchk(I, Around), Off, Near),
          Near \== []
      ->  Pool = Near
      ;   Pool = Off
      ),
      ( Guarded == true -> Next = false ; Next = true ) },
    (   { Pool == [] }
    ->  { Os = Os0 }
    ;   rand_member(I, Pool),
        hearts(Vs, Next, Ctx, [o(I, heart, V)|Os0], Os)
    ).
