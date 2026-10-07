:- module(labyrinth_maze, [ maze//1,
                            size/2,
                            levels/1,
                            start/1,
                            cells/1,
                            linked/3,
                            step/3,
                            distances/3,
                            reachable/3
                          ]).

/** <module> LABYRINTH maze

Rooms are cells `c(Level, X, Y)` on a 5 x 5 grid per level, with Y growing
southwards (row 0 is the top of the master map). A maze is a list of
doorways `A-B` (A @< B): the corridors on each level plus ladders between
levels at the same X, Y.

Each level is a random spanning tree with a few extra doorways to make
loops. Room 1 is the bottom-left cell of level 1; the boss lair is one of
the farthest rooms on the top level. Two doors on the way there are locked:
key A opens the first and lies before it, key B opens the second and lies
between the two. Both doors are bridges, so the lair can't be reached
without them, and neither key is ever behind its own door.
*/

:- use_module(library(assoc)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module('../../rng').

size(5, 5).
levels(2).
start(c(1, 0, 4)).
attempts(40).

%!  cells(-Cells) is det.
cells(Cells) :-
    size(W, H), levels(NL),
    W1 is W - 1, H1 is H - 1,
    findall(c(L, X, Y), ( between(1, NL, L), between(0, H1, Y), between(0, W1, X) ), Cells).

%!  maze(-Maze)// is det.
%
%   Maze = maze(Doors, Lair, Locks, Keys), where Locks is a list of
%   `Door-Key` and Keys a list of `Key-Room`, for keys "A" and "B".
maze(Maze) -->
    { attempts(K) },
    maze(K, Maze).

maze(K, Maze) -->
    candidate(Doors),
    { start(S), distances(S, Doors, Ds) },
    lair(Ds, Lair),
    locks(Doors, Ds, Lair, Result),
    (   { Result = ok(Locks, Keys) }
    ->  { Maze = maze(Doors, Lair, Locks, Keys) }
    ;   { K > 1 }
    ->  { K1 is K - 1 },
        maze(K1, Maze)
    ;   { domain_error(placeable_locks, Doors) }
    ).

candidate(Doors) -->
    { levels(NL) },
    levels(1, NL, Corridors),
    ladders(Ladders),
    { append(Corridors, Ladders, Ds0), msort(Ds0, Doors) }.

levels(L, NL, []) --> { L > NL }, !.
levels(L, NL, Doors) -->
    spanning_tree(L, Tree),
    loops(L, Tree, Loops),
    { L1 is L + 1 },
    levels(L1, NL, Rest),
    { append([Tree, Loops, Rest], Doors) }.

%   Recursive backtracker: carve to a random unvisited neighbour, back up
%   when there is none. Long winding corridors with dead ends.
spanning_tree(L, Doors) -->
    { size(W, H) },
    rand_int(0, W - 1, X),
    rand_int(0, H - 1, Y),
    carve([c(L, X, Y)], [c(L, X, Y)], [], Doors).

carve([], _, Doors, Doors) --> [].
carve([C|Stack], Seen, Doors0, Doors) -->
    { findall(N, ( step(C, _, N), N = c(L, _, _), C = c(L, _, _),
                   \+ memberchk(N, Seen) ), Ns) },
    (   { Ns == [] }
    ->  carve(Stack, Seen, Doors0, Doors)
    ;   rand_member(N, Ns),
        { door(C, N, D) },
        carve([N, C|Stack], [N|Seen], [D|Doors0], Doors)
    ).

loops(L, Tree, Loops) -->
    { cells(Cells),
      findall(D, ( member(A, Cells), A = c(L, _, _),
                   step(A, Dir, B), memberchk(Dir, [e, s]),
                   door(A, B, D), \+ memberchk(D, Tree) ), Free) },
    rand_int(3, 5, K),
    shuffle(Free, Shuffled),
    { length(Shuffled, NF), K1 is min(K, NF), length(Loops, K1),
      append(Loops, _, Shuffled) }.

%   One ladder, sometimes two, never in room 1's spot.
ladders(Ladders) -->
    { size(W, H), start(c(_, SX, SY)),
      W1 is W - 1, H1 is H - 1,
      findall(X-Y, ( between(0, W1, X), between(0, H1, Y), X-Y \== SX-SY ), Spots) },
    rand_chance(0.4, Two),
    { Two == true -> N = 2 ; N = 1 },
    shuffle(Spots, Shuffled),
    { length(Picked, N), append(Picked, _, Shuffled),
      findall(c(1, X, Y)-c(2, X, Y), member(X-Y, Picked), Ladders) }.

%   The lair is on the top level, among the three farthest rooms from room 1.
lair(Ds, Lair) -->
    { levels(Top),
      findall(D-C, ( member(C-D, Ds), C = c(Top, _, _) ), Pairs),
      msort(Pairs, Sorted), reverse(Sorted, Far),
      length(Far, NF), K is min(3, NF), length(Best, K), append(Best, _, Far),
      pairs_values(Best, Rooms) },
    rand_member(Lair, Rooms).

% Locks and keys ------------------------------------------------------------

%   Each lock must leave enough maze to explore before it: at least
%   `region(Before, Between)` rooms before lock A and between the two.
region(8, 6).

locks(Doors, Ds, Lair, Result) -->
    { start(S),
      path(S, Lair, Doors, Path),
      include(lockable(Doors, S, Lair), Path, Bridges),
      region(MinA, MinB),
      findall(DoorA-DoorB-Before-Between,
              ( append(_, [DoorA|Later], Bridges), member(DoorB, Later),
                exclude(==(DoorA), Doors, WithoutA),
                exclude(==(DoorB), Doors, WithoutB),
                reachable(S, WithoutA, Before), length(Before, NA), NA >= MinA,
                reachable(S, WithoutB, BeforeB),
                subtract(BeforeB, Before, Between), length(Between, NB), NB >= MinB ),
              Options) },
    (   { Options == [] }
    ->  { Result = none }
    ;   rand_member(DoorA-DoorB-Before-Between, Options),
        { findall(C, ( member(C, Before), C \== S, memberchk(C-D, Ds), D >= 2 ), SpotsA),
          findall(C, ( member(C, Between), C \== Lair ), SpotsB) },
        key_spot(SpotsA, KeyA),
        key_spot(SpotsB, KeyB),
        { (   KeyA \== none, KeyB \== none
          ->  Result = ok([DoorA-"A", DoorB-"B"], ["A"-KeyA, "B"-KeyB])
          ;   Result = none
          ) }
    ).

key_spot([], none) --> !.
key_spot(Spots, Room) --> rand_member(Room, Spots).

%   A door worth locking: a corridor (not a ladder) that the lair can't be
%   reached without, and not room 1's own door.
lockable(Doors, S, Lair, A-B) :-
    A = c(L, _, _), B = c(L, _, _),
    A \== S, B \== S,
    exclude(==(A-B), Doors, Rest),
    reachable(S, Rest, R),
    \+ memberchk(Lair, R).

%   The doors along a shortest path, in order from From.
path(From, To, Doors, Path) :-
    parents(From, Doors, Parents),
    walk_back(To, From, Parents, [], Path).

walk_back(From, From, _, Path, Path) :- !.
walk_back(C, From, Parents, Acc, Path) :-
    get_assoc(C, Parents, P),
    door(P, C, D),
    walk_back(P, From, Parents, [D|Acc], Path).

parents(S, Doors, Parents) :-
    list_to_assoc([S-root], P0),
    bfs_parents([S], Doors, P0, Parents).

bfs_parents([], _, P, P).
bfs_parents([C|Q], Doors, P0, P) :-
    findall(N, ( linked(Doors, C, N), \+ get_assoc(N, P0, _) ), Ns0),
    sort(Ns0, Ns),
    foldl([N, A0, A]>>put_assoc(N, A0, C, A), Ns, P0, P1),
    append(Q, Ns, Q1),
    bfs_parents(Q1, Doors, P1, P).

% Graph helpers -------------------------------------------------------------

%!  step(?From, ?Dir, ?To) is nondet.
%
%   Grid neighbours on the same level; Dir is n, e, s or w.
step(c(L, X, Y), Dir, c(L, X1, Y1)) :-
    size(W, H),
    member(Dir-(DX-DY), [n-(0-(-1)), e-(1-0), s-(0-1), w-((-1)-0)]),
    X1 is X + DX, Y1 is Y + DY,
    X1 >= 0, X1 < W, Y1 >= 0, Y1 < H.

door(A, B, A-B) :- A @< B, !.
door(A, B, B-A).

%!  linked(+Doors, +A, -B) is nondet.
linked(Doors, A, B) :- member(A-B, Doors).
linked(Doors, A, B) :- member(B-A, Doors).

%!  distances(+Start, +Doors, -Pairs) is det.
%
%   Room-Steps for every room reachable from Start.
distances(S, Doors, Pairs) :-
    list_to_assoc([S-0], A0),
    bfs([S], Doors, A0, A),
    assoc_to_list(A, Pairs).

bfs([], _, A, A).
bfs([C|Q], Doors, A0, A) :-
    get_assoc(C, A0, D),
    D1 is D + 1,
    findall(N, ( linked(Doors, C, N), \+ get_assoc(N, A0, _) ), Ns0),
    sort(Ns0, Ns),
    foldl([N, B0, B]>>put_assoc(N, B0, D1, B), Ns, A0, A1),
    append(Q, Ns, Q1),
    bfs(Q1, Doors, A1, A).

%!  reachable(+Start, +Doors, -Rooms) is det.
reachable(S, Doors, Rooms) :-
    distances(S, Doors, Pairs),
    pairs_keys(Pairs, Rooms).
