:- use_module('../graphite').
:- use_module('../rng').

:- begin_tests(rng).

test(fnv1a_known_value) :-
    seed_state("abc", S),
    assertion(S =:= 0x1A47E90B).

test(rand_int_in_range, [forall(member(Seed, [a, b, c, 1, 42]))]) :-
    seed_state(Seed, S0),
    phrase(rolls(200, Xs), [S0], [_]),
    forall(member(X, Xs), assertion(between(1, 6, X))).

test(same_seed_same_sequence) :-
    seed_state(pencil, S0),
    phrase(rolls(50, A), [S0], [_]),
    phrase(rolls(50, B), [S0], [_]),
    assertion(A =@= B).

rolls(0, []) --> !.
rolls(N, [X|Xs]) --> rand_int(1, 6, X), { N1 is N - 1 }, rolls(N1, Xs).

:- end_tests(rng).

:- begin_tests(golf).

:- use_module('../games/golf/rules').
:- use_module('../games/golf/evaluate').

% One full notebook is slow-ish (~3s), so most tests work on single holes.
test(notebook_shape) :-
    generate(golf, "shape", Doc),
    assertion(Doc.game == golf),
    length(Doc.courses, 3),
    forall(member(C, Doc.courses), assertion(length(C.holes, 18))),
    findall(N, ( member(C, Doc.courses), N = C.name ), Names),
    sort(Names, Unique),
    assertion(length(Unique, 3)).

test(hole_deterministic) :-
    hole_doc("fore", A),
    hole_doc("fore", B),
    assertion(A =@= B).

test(holes_differ) :-
    hole_doc("one", A),
    hole_doc("two", B),
    assertion(A \=@= B).

test(hole_shape, [forall(member(Seed, [p, q, r, s]))]) :-
    hole_doc(Seed, Hole),
    terrain(Hole, Hole.tee, T), assertion(T == 0'f),
    terrain(Hole, Hole.cup, C), assertion(C == 0'f),
    length(Hole.rows, Hole.height),
    forall(member(Row, Hole.rows), assertion(string_length(Row, Hole.width))),
    assertion(number(Hole.expected)),
    assertion(between(1, 10, Hole.speed)).

% The fast evaluator must agree with the readable rules in golf_rules.
test(rays_match_rules, [forall(member(Seed, [x, y, z]))]) :-
    seed_state(Seed, S0),
    phrase(golf:candidate(Hole, _), [S0], [_]),
    golf_evaluate:board(Hole, Board),
    Hole = hole(W, H, _, _, _),
    N is W*H,
    forall(( between(1, N, I), member(OverTrees, [true, false]) ),
           ( findall(D-R, ( between(1, 7, D), shot(Hole, I, D, OverTrees, _, R) ), Slow0),
             board_results(Board, I, OverTrees, [1, 2, 3, 4, 5, 6, 7], Fast0),
             msort(Slow0, Slow), msort(Fast0, Fast),
             assertion(Slow == Fast) )).

test(overshoot_by_one) :-
    % 1x5 strip: ball at the bottom, cup in the middle.
    Hole = hole(1, 5, t(0'r, 0'f, 0'f, 0'f, 0'f), s(none, none, none, none, none), 3),
    assertion(shot(Hole, 5, 2, false, n, in)),      % lands on the cup
    assertion(shot(Hole, 5, 3, false, n, in)),      % one past: counts
    assertion(shot(Hole, 5, 4, false, n, at(1))).   % two past: carries on

test(trees_block_unless_over) :-
    Hole = hole(1, 4, t(0'f, 0'r, 0't, 0'f), s(none, none, none, none), 1),
    assertion(\+ shot(Hole, 4, 2, false, n, _)),
    assertion(shot(Hole, 4, 2, true, n, at(2))),
    assertion(\+ shot(Hole, 4, 1, true, n, _)).     % can't land in trees

test(slope_rolls_on) :-
    Hole = hole(1, 4, t(0'f, 0'r, 0'r, 0'f), s(none, n, n, none), 1),
    assertion(shot(Hole, 4, 1, false, n, in)).      % rolls up both arrows into the cup

test(json_roundtrip) :-
    generate_json("golf", "json", Json),
    atom_json_dict(Json, Dict, []),
    assertion(Dict.game == "golf").

hole_doc(Seed, Hole) :-
    seed_state(Seed, S0),
    phrase(golf:hole(60, 1, Hole), [S0], [_]).

terrain(Hole, [X, Y], Code) :-
    nth0(Y, Hole.rows, Row),
    I is X + 1,
    string_code(I, Row, Code).

:- end_tests(golf).

:- begin_tests(labyrinth).

:- use_module('../games/labyrinth/maze').
:- use_module('../games/labyrinth/encounters').

seeds([a, b, c, d, e, f, g, h]).

test(deterministic) :-
    generate(labyrinth, "maze", A),
    generate(labyrinth, "maze", B),
    assertion(A =@= B).

test(rooms_numbered_once, [forall(( seeds(Ss), member(Seed, Ss) ))]) :-
    generate(labyrinth, Seed, Doc),
    findall(N, ( member(R, Doc.rooms), get_dict(number, R, N) ), Ns),
    numlist(1, 50, All),
    assertion(Ns == All),
    member(R1, Doc.rooms), R1.number == 1, !,
    assertion([R1.x, R1.y, R1.level] == [0, 4, 1]),
    assertion(R1.kind == start).

% Every doorway shows up in both rooms, with the same lock.
test(exits_symmetric, [forall(( seeds(Ss), member(Seed, Ss) ))]) :-
    generate(labyrinth, Seed, Doc),
    findall(A-B-L, ( member(R, Doc.rooms), get_dict(number, R, A),
                     get_dict(exits, R, Es), member(E, Es),
                     get_dict(to, E, B), get_dict(lock, E, L) ), Doors),
    forall(member(A-B-L, Doors), assertion(memberchk(B-A-L, Doors))).

test(one_lair_two_keys, [forall(( seeds(Ss), member(Seed, Ss) ))]) :-
    generate(labyrinth, Seed, Doc),
    findall(R, ( member(R, Doc.rooms), get_dict(boss, R, true) ), Lairs),
    assertion(length(Lairs, 1)),
    findall(K, ( member(R, Doc.rooms), get_dict(key, R, K) ), Keys),
    msort(Keys, Sorted),
    assertion(Sorted == ["A", "B"]).

% Play the locks: key A is reachable with no keys, key B with key A,
% and the lair (and so every room) with both.
test(keys_before_locks, [forall(( seeds(Ss), member(Seed, Ss) ))]) :-
    seed_state(Seed, S0),
    phrase(maze(maze(Doors, Lair, Locks, Keys)), [S0], [_]),
    start(S),
    memberchk("A"-KA, Keys), memberchk("B"-KB, Keys),
    open_doors(Doors, Locks, [], D0), reachable(S, D0, R0),
    open_doors(Doors, Locks, ["A"], D1), reachable(S, D1, R1),
    open_doors(Doors, Locks, ["A", "B"], D2), reachable(S, D2, R2),
    assertion(memberchk(KA, R0)),
    assertion(\+ memberchk(KB, R0)),
    assertion(memberchk(KB, R1)),
    assertion(\+ memberchk(Lair, R1)),
    cells(Cells0),
    msort(Cells0, Cells),
    assertion(R2 == Cells).

open_doors(Doors, Locks, Held, Open) :-
    exclude([D]>>( memberchk(D-K, Locks), \+ memberchk(K, Held) ), Doors, Open).

% Seeds 11, 19 and 29 once left no room for the first armoury.
test(always_generates) :-
    forall(between(1, 40, Seed), assertion(generate(labyrinth, Seed, _))).

% Enemies without a fixed look get a random monster; the rest keep theirs.
test(random_monsters, [forall(( seeds(Ss), member(Seed, Ss) ))]) :-
    generate(labyrinth, Seed, Doc),
    forall(( member(R, Doc.rooms), get_dict(art, R, monster) ),
           ( get_dict(monster, R, M),
             assertion(memberchk(M.body, ["A", "B", "C", "D", "E", "F"])),
             assertion(memberchk(M.eyes, [1, 2, 3])) )),
    forall(( member(R, Doc.rooms), get_dict(enemy, R, "GIANT RAT") ),
           assertion(R.art == rat)).

test(battle_cost) :-
    % Hits on 3-4, -1 HP on 1 and 6: 3 hearts at 1 DMG need 3 hits, each
    % costing on average (1+1)/2 = 1 HP.
    battle_cost([hp(-1), miss, hit, hit, miss, hp(-1)], 3, 1, HP),
    assertion(HP =:= 3).

test(table_runs) :-
    table_dict([bust, add, add, add, add, add], Cells),
    assertion(Cells = [_{from: 1, to: 1, label: "BUST"},
                       _{from: 2, to: 6, label: _}]).

test(json_roundtrip) :-
    generate_json("labyrinth", "json", Json),
    atom_json_dict(Json, Dict, []),
    assertion(Dict.game == "labyrinth"),
    Rooms = Dict.rooms,
    assertion(length(Rooms, 50)).

:- end_tests(labyrinth).


:- begin_tests(dungeon).

:- use_module('../games/dungeon/rules').
:- use_module('../games/dungeon/evaluate').
:- use_module('../games/dungeon/simulate').
:- use_module('../games/dungeon/stock').

% A full notebook takes a few seconds, so each seed is generated once.
doc(Seed, Doc) :-
    format(atom(Key), "dungeon_test_~w", [Seed]),
    (   nb_current(Key, Doc) -> true
    ;   generate(dungeon, Seed, Doc), nb_setval(Key, Doc)
    ).

test(deterministic) :-
    doc("crypt", A),
    generate(dungeon, "crypt", B),
    assertion(A =@= B).

test(notebook_shape, [forall(member(Seed, ["crypt", 7]))]) :-
    doc(Seed, Doc),
    length(Doc.floors, 30),
    assertion(Doc.shops == [5, 10, 15, 20, 25]),
    forall(member(F, Doc.floors),
           ( length(F.rows, 13),
             forall(member(R, F.rows), assertion(string_length(R, 13))),
             assertion(open_cell(F, F.start)),
             assertion(open_cell(F, F.stairs)),
             findall([X, Y], ( member(O, F.objects), X = O.x, Y = O.y ), Spots),
             forall(member(P, Spots), assertion(open_cell(F, P))),
             msort([F.start, F.stairs|Spots], Sorted), sort(Sorted, Unique),
             assertion(Sorted == Unique),
             assertion(number(F.expected)) )).

% Every floor can be finished and has no traps, checked again from the JSON.
test(floors_playable) :-
    doc("crypt", Doc),
    forall(member(F, Doc.floors),
           ( doc_floor(F, Floor, Start),
             evaluate_floor(Floor, Start, 1000, Stats),
             assertion(Stats = stats(_, _, _)) )).

% Every locked door has its key on the same floor.
test(keys_with_locks, [forall(member(Seed, ["crypt", 7]))]) :-
    doc(Seed, Doc),
    forall(( member(F, Doc.floors), member(L, F.objects), L.kind == "lock" ),
           assertion(( member(K, F.objects), K.kind == "key" ))).

% Floors offer a choice: most of the loot is off the quick way down, and
% rushing costs about as much HP as the floor's band says.
test(stocked_for_choices, [forall(member(Seed, ["crypt", 7]))]) :-
    doc(Seed, Doc),
    length(Doc.floors, NF),
    findall(F, ( member(F, Doc.floors), B = F.balance,
                 B.route_loot =< 0.4 * B.loot,
                 T is (F.number - 1) / (NF - 1),
                 damage_band(T, Lo, Hi),
                 B.damage >= Lo - 0.5, B.damage =< Hi + 0.5 ), Good),
    length(Good, NG),
    assertion(NG >= NF - 2).

% Chests always have a guard next to them.
test(chests_guarded, [forall(member(Seed, ["crypt", 7]))]) :-
    doc(Seed, Doc),
    forall(( member(F, Doc.floors), get_dict(objects, F, Os),
             member(C, Os), get_dict(kind, C, chest) ),
           assertion(guarded(C, Os))).

guarded(C, Os) :-
    member(E, Os), get_dict(kind, E, enemy),
    abs(E.x - C.x) =< 1, abs(E.y - C.y) =< 1, !.

% The simulated explorer gets through a notebook without dying every
% other floor, and finishes floors in a sensible number of turns.
test(simulated_play) :-
    doc("crypt", Doc),
    play_notebook(Doc, explorer, 1, R),
    assertion(R.deaths =< 8),
    forall(member(F, R.floors), assertion(F.turns =< 60)).

test(diagonal_example) :-
    % Odd roll from the bottom row: NE, a wall, SE, a wall, then NE.
    floor_from(["######",
                 ".....S",
                 "......"], F),
    floor_index(F, 0-2, Start), floor_index(F, 3-1, End),
    findall(R, turn(F, at(Start, none, false), 3, R), Rs),
    assertion(memberchk(at(End, ne, false), Rs)).

test(orthogonal_example) :-
    % A 6 east: two squares, a wall, south to the edge, then east again.
    floor_from(["...#..S",
                "...#...",
                "......."], F),
    floor_index(F, 0-0, Start), floor_index(F, 4-2, End),
    findall(R, turn(F, at(Start, none, false), 6, R), Rs),
    assertion(memberchk(at(End, e, false), Rs)).

test(full_move_forced) :-
    floor_from([".........S"], F),
    floor_index(F, 1-0, Start), floor_index(F, 3-0, End),
    findall(R, turn(F, at(Start, none, false), 2, R), Rs),
    assertion(Rs == [at(End, e, false)]).

test(no_going_back) :-
    floor_from([".........S"], F),
    floor_index(F, 4-0, Start),
    findall(R, turn(F, at(Start, e, false), 2, R), Rs),
    floor_index(F, 6-0, End),
    assertion(Rs == [at(End, e, false)]).

test(web_stops) :-
    floor_from(["..W......S"], F),
    floor_index(F, 0-0, Start), floor_index(F, 2-0, Web),
    findall(R, turn(F, at(Start, none, false), 4, R), Rs),
    assertion(Rs == [at(Web, e, false)]).

test(teleporter_carries_on) :-
    floor_from(["..T...T....S"], F),
    floor_index(F, 0-0, Start), floor_index(F, 8-0, End),
    findall(R, turn(F, at(Start, none, false), 4, R), Rs),
    assertion(Rs == [at(End, e, false)]).

test(lock_needs_key) :-
    floor_from(["..L..S"], F),
    floor_index(F, 0-0, Start),
    assertion(\+ turn(F, at(Start, none, false), 4, exit)),
    assertion(turn(F, at(Start, none, true), 4, exit)).

test(stairs_in_passing) :-
    floor_from(["..S......."], F),
    floor_index(F, 0-0, Start),
    assertion(turn(F, at(Start, none, false), 6, exit)).

test(json_roundtrip) :-
    generate_json("dungeon", "crypt", Json),
    atom_json_dict(Json, Dict, []),
    assertion(Dict.game == "dungeon").

open_cell(F, [X, Y]) :-
    nth0(Y, F.rows, Row),
    sub_string(Row, X, 1, _, ".").

floor_from(Rows, Floor) :-
    Rows = [R0|_], string_length(R0, W), length(Rows, H),
    atomic_list_concat(Rows, All), atom_codes(All, Codes),
    G =.. [g|Codes],
    findall(I, nth1(I, Codes, 0'T), Ts),
    ( Ts = [A, B] -> Tele = tp(A, B) ; Tele = none ),
    nth1(S, Codes, 0'S), !,
    make_floor(W, H, G, Tele, S, Floor).

:- end_tests(dungeon).
