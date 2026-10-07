:- module(labyrinth, [notebook//1]).

/** <module> LABYRINTH generator

A gamebook: one page per room of a hidden two-level maze, which the player
maps on the master map as they explore. See docs/rules/labyrinth.md.

The generator builds the maze (labyrinth/maze.pl), numbers the rooms in a
random order (room 1 is always the entrance), gives every room a facing
for its picture, then hands out roles: the entrance, the BULLGRIM's lair,
two key guardians, two armouries, snack shops, and a mix of battles,
traps, choices and games for the rest. Enemies toughen with distance from
the entrance (labyrinth/encounters.pl).

Each room's exits are given relative to its facing, the way the picture
shows them: front, left, right, back, up or down.
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module('../rng').
:- use_module(labyrinth/maze).
:- use_module(labyrinth/encounters).

broken_compasses(4).

notebook(_{width: W, height: H, levels: NL, start: [SX, SY], rooms: Rooms,
           weapons: Weapons}) -->
    maze(maze(Doors, Lair, Locks, Keys)),
    { size(W, H), levels(NL), start(S), S = c(_, SX, SY),
      cells(Cells), subtract(Cells, [S], Others),
      length(Others, NO), Last is NO + 1, numlist(2, Last, Nums) },
    shuffle(Nums, Shuffled),
    { pairs_keys_values(Numbers0, Others, Shuffled), Numbers = [S-1|Numbers0] },
    facings(Others, Facings0),
    { Facings = [S-n|Facings0] },
    broken(Others, Lair, Broken),
    roles(Doors, Lair, Locks, Keys, Roles),
    { distances(S, Doors, Ds),
      pairs_values(Ds, Steps), max_list(Steps, Far) },
    rooms(Cells, Roles, Ds, Far, Encounters),
    { maplist(room(Doors, Locks, Numbers, Facings, Broken), Cells, Encounters, Rooms0),
      sort(number, @<, Rooms0, Rooms),
      findall(_{name: N, damage: D, price: P}, weapon(N, D, P), Weapons) }.

facings([], []) --> [].
facings([C|Cs], [C-F|Fs]) -->
    rand_member(F, [n, e, s, w]),
    facings(Cs, Fs).

%   A few rooms have a broken compass: the player has to work out which way
%   the picture faces from the way they came in.
broken(Others, Lair, Broken) -->
    { exclude(==(Lair), Others, Candidates), broken_compasses(N) },
    shuffle(Candidates, Shuffled),
    { length(Broken, N), append(Broken, _, Shuffled) }.

% Roles ---------------------------------------------------------------------

roles(Doors, Lair, Locks, Keys, Roles) -->
    { start(S),
      memberchk("A"-KeyA, Keys), memberchk("B"-KeyB, Keys),
      Fixed = [S-start, Lair-boss, KeyA-key("A"), KeyB-key("B")],
      pairs_keys(Locks, Locked),
      subtract(Doors, Locked, Open),
      distances(S, Open, Before),
      cells(Cells),
      pairs_keys(Fixed, Taken0) },
    % The first armoury is before the first lock, so a sword is in reach
    % before the tougher fights; the second is on level 2.
    pick([ ( member(C-D, Before), C = c(1, _, _), D >= 2 ),
           member(C-_, Before) ], C, Taken0, Armory1),
    pick([ ( member(C, Cells), C = c(2, _, _) ) ], C, [Armory1|Taken0], Armory2),
    pick([ ( member(C, Cells), C = c(1, _, _) ) ], C, [Armory2, Armory1|Taken0], Shop1),
    pick([ ( member(C, Cells), C = c(2, _, _) ) ], C, [Shop1, Armory2, Armory1|Taken0], Shop2),
    pick([ member(C, Cells) ], C, [Shop2, Shop1, Armory2, Armory1|Taken0], Camp),
    { Placed = [Armory1-armory, Armory2-armory, Shop1-shop, Shop2-shop, Camp-camp|Fixed],
      pairs_keys(Placed, Taken),
      subtract(Cells, Taken, Rest) },
    fill(Rest, Filled),
    { append(Placed, Filled, Roles) }.

%   A random cell that isn't Taken, from the first of Goals (each run on
%   Template) that offers one.
pick([Goal|Goals], Template, Taken, Cell) -->
    { findall(Template, ( call(Goal), \+ memberchk(Template, Taken) ), Cs0),
      sort(Cs0, Cs) },
    (   { Cs == [], Goals \== [] }
    ->  pick(Goals, Template, Taken, Cell)
    ;   rand_member(Cell, Cs)
    ).

fill([], []) --> [].
fill([C|Cs], [C-Role|Rs]) -->
    rand_member(Role, [battle, battle, battle, battle, battle, battle, battle, battle,
                       roll, roll, roll, choice, choice, choice,
                       dice, dice, chest, chest, shop]),
    fill(Cs, Rs).

% Rooms ---------------------------------------------------------------------

rooms([], _, _, _, []) --> [].
rooms([C|Cs], Roles, Ds, Far, [E|Es]) -->
    { memberchk(C-Role, Roles), memberchk(C-D, Ds),
      Tier is min(4, 1 + (D * 4) // (Far + 1)) },
    encounter(Role, Tier, E0),
    { E = E0.put(tier, Tier) },
    rooms(Cs, Roles, Ds, Far, Es).

room(Doors, Locks, Numbers, Facings, Broken, C, Encounter, Room) :-
    C = c(L, X, Y),
    memberchk(C-N, Numbers),
    memberchk(C-F, Facings),
    (   memberchk(C, Broken) -> Shown = "?" ; atom_string(F, Shown) ),
    findall(Exit, exit(Doors, Locks, Numbers, C, F, Exit), Exits0),
    sort(order, @<, Exits0, Exits1),
    maplist([E0, E]>>del_dict(order, E0, _, E), Exits1, Exits),
    Room = Encounter.put(_{number: N, level: L, x: X, y: Y,
                           facing: Shown, exits: Exits}).

exit(Doors, Locks, Numbers, C, Facing, _{side: Side, to: To, lock: Lock, order: O}) :-
    linked(Doors, C, Next),
    memberchk(Next-To, Numbers),
    side(C, Next, Facing, Side),
    nth0(O, [front, left, right, back, up, down], Side),
    (   ( memberchk((C-Next)-Lock, Locks) ; memberchk((Next-C)-Lock, Locks) )
    ->  true
    ;   Lock = null
    ).

%   Where an exit shows up in the picture, given which way it faces.
side(c(L1, _, _), c(L2, _, _), _, Side) :-
    L1 \== L2, !,
    (   L2 > L1 -> Side = up ; Side = down ).
side(C, Next, Facing, Side) :-
    step(C, Dir, Next),
    Compass = [n, e, s, w],
    nth0(I, Compass, Facing),
    nth0(J, Compass, Dir),
    Turn is (J - I) mod 4,
    nth0(Turn, [front, right, back, left], Side).
