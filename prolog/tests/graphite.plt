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
