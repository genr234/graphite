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
