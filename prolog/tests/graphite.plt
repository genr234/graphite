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

test(deterministic) :-
    generate(golf, "fore", A),
    generate(golf, "fore", B),
    assertion(A =@= B).

test(seeds_differ) :-
    generate(golf, "one", A),
    generate(golf, "two", B),
    assertion(A \=@= B).

test(tee_and_cup_on_fairway) :-
    generate(golf, "fairway", Doc),
    forall(member(Hole, Doc.holes),
           ( terrain(Hole, Hole.tee, T), assertion(T == 0'f),
             terrain(Hole, Hole.cup, C), assertion(C == 0'f) )).

test(rows_have_width) :-
    generate(golf, "width", Doc),
    forall(member(Hole, Doc.holes),
           ( length(Hole.rows, Hole.height),
             forall(member(Row, Hole.rows),
                    assertion(string_length(Row, Hole.width))) )).

test(json_roundtrip) :-
    generate_json("golf", "json", Json),
    atom_json_dict(Json, Dict, []),
    assertion(Dict.game == "golf").

terrain(Hole, [X, Y], Code) :-
    nth0(Y, Hole.rows, Row),
    I is X + 1,
    string_code(I, Row, Code).

:- end_tests(golf).
