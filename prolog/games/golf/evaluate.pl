:- module(golf_evaluate, [ evaluate_hole/3,
                           board_results/5
                         ]).

/** <module> GOLF hole evaluation

Validators the generator uses to accept or reject a hole. Everything
here follows golf_rules:shot/6, but precomputed for speed: one ray per
cell and direction yields the result for every shot distance at once
(tests/graphite.plt cross-checks the two).

evaluate_hole/3 reports:

  - `unplayable` if some lie reachable in Dice GOLF has no legal putt
    (the ball could get trapped) or Speed GOLF can't finish; else
  - `stats(Expected, Speed)`: optimal-play expected strokes in Dice GOLF
    (value iteration; re-rolls and Mulligans ignored, so real play trends
    lower) and the minimum strokes in Speed GOLF.
*/

:- use_module(rules).

%!  evaluate_hole(+Hole, +Tee, -Stats) is det.
evaluate_hole(Hole, Tee, Stats) :-
    board(Hole, Board),
    (   speed_strokes(Board, Tee, Speed),
        dice_reachable(Board, Tee, Reachable)
    ->  dice_expected(Board, Reachable, Tee, E),
        Stats = stats(E, Speed)
    ;   Stats = unplayable
    ).

% Board -------------------------------------------------------------------

%   board(Hole, N, Next, Settle):
%     Next:   per cell, n(N, NE, E, SE, S, SW, W, NW) neighbour indexes (0 = off grid)
%     Settle: per resting cell, where the ball ends after slopes (`in` or `at(J)`)
board(Hole, board(Hole, N, Next, Settle)) :-
    Hole = hole(W, H, _, _, _),
    N is W*H,
    functor(Next, next, N),
    functor(Settle, settle, N),
    forall(between(1, N, I),
           ( neighbours(Hole, I, Ns), nb_setarg(I, Next, Ns) )),
    forall(between(1, N, I),
           (   resting(Hole, I),
               roll_slopes(Hole, I, R)
           ->  nb_setarg(I, Settle, R)
           ;   nb_setarg(I, Settle, none)
           )).

neighbours(Hole, I, Ns) :-
    Hole = hole(W, _, _, _, _),
    X is (I - 1) mod W, Y is (I - 1) // W,
    findall(J,
            ( member(D, [n, ne, e, se, s, sw, w, nw]),
              direction(D, DX, DY),
              X1 is X + DX, Y1 is Y + DY,
              ( hole_index(Hole, X1-Y1, J) -> true ; J = 0 ) ),
            Js),
    Ns =.. [n|Js].

resting(hole(_, _, T, _, _), I) :-
    arg(I, T, C), C \== 0'w, C \== 0't.

%!  board_results(+Board, +From, +OverTrees, +Distances, -Results) is det.
%
%   Results for shots of each distance in Distances (ascending) from
%   From, in all 8 directions, as Distance-Result pairs.
board_results(Board, From, OverTrees, Distances, Results) :-
    last(Distances, Max),
    findall(D-R,
            ( between(1, 8, Dir),
              ray(Board, From, Dir, OverTrees, Max, Ray),
              member(D-R, Ray),
              memberchk(D, Distances) ),
            Results).

%   Walk one direction up to Max cells, emitting the result for every
%   distance that is a legal shot. Stops at the grid edge, or at trees
%   when the shot can't fly over them.
ray(board(Hole, _, Next, Settle), From, Dir, OverTrees, Max, Ray) :-
    Hole = hole(_, _, T, _, Cup),
    ray_(1, Max, From, 0, Dir, OverTrees, Next, Settle, T, Cup, Ray).

ray_(K, Max, _, _, _, _, _, _, _, _, []) :- K > Max, !.
ray_(K, Max, At, Prev, Dir, OverTrees, Next, Settle, T, Cup, Ray) :-
    arg(At, Next, Ns), arg(Dir, Ns, J),
    (   J =:= 0
    ->  Ray = []
    ;   (   J =:= Cup -> Ray = [K-in|Ray1]
        ;   Prev =:= Cup -> Ray = [K-in|Ray1]       % overshoot by one counts
        ;   arg(J, Settle, R), R \== none -> Ray = [K-R|Ray1]
        ;   Ray = Ray1
        ),
        arg(J, T, C),
        (   C == 0't, OverTrees == false
        ->  Ray1 = []
        ;   K1 is K + 1,
            ray_(K1, Max, J, J, Dir, OverTrees, Next, Settle, T, Cup, Ray1)
        )
    ).

% Speed GOLF --------------------------------------------------------------

speed_strokes(Board, Tee, Strokes) :-
    Board = board(_, N, _, _),
    functor(Seen, seen, N),
    nb_setarg(Tee, Seen, true),
    bfs([Tee], Seen, 1, Board, Strokes).

bfs([], _, _, _, _) :- !, fail.
bfs(Frontier, Seen, Depth, Board, Strokes) :-
    findall(R, ( member(I, Frontier), speed_shot(Board, I, R) ), Rs),
    (   memberchk(in, Rs)
    ->  Strokes = Depth
    ;   findall(J, ( member(at(J), Rs), arg(J, Seen, S), S \== true,
                     nb_setarg(J, Seen, true) ), Js),
        D1 is Depth + 1,
        bfs(Js, Seen, D1, Board, Strokes)
    ).

speed_shot(Board, I, R) :-
    Board = board(hole(_, _, T, _, _), _, _, _),
    arg(I, T, Lie),
    speed_clubs(Lie, Clubs),
    member(D-OverTrees, Clubs),
    board_results(Board, I, OverTrees, [D], Rs),
    member(D-R, Rs).

% Dice GOLF ---------------------------------------------------------------

%   Targets (0 = holed) for a putt, and for each d6 roll the extra
%   targets that distance opens up. Putting is always an alternative.
dice_options(Board, I, options(Putts, Rolls)) :-
    Board = board(hole(_, _, T, _, _), _, _, _),
    arg(I, T, Lie),
    ( Lie == 0'f -> OverTrees = true ; OverTrees = false ),
    findall(D, ( between(1, 6, Roll), dice_distance(Lie, Roll, D), D > 0 ), Ds0),
    sort([1|Ds0], Ds),
    board_results(Board, I, OverTrees, Ds, Results),
    findall(P, ( member(1-R, Results), target(R, P) ), Putts0),
    sort(Putts0, Putts),
    findall(Ps,
            ( between(1, 6, Roll),
              dice_distance(Lie, Roll, D),
              findall(P, ( member(D-R, Results), target(R, P) ), Ps0),
              sort(Ps0, Ps) ),
            Rolls).

target(in, 0).
target(at(J), J).

%   Breadth-first over every lie the ball can reach. Fails if any of them
%   has no legal move at all. Returns Cell-Options pairs.
dice_reachable(Board, Tee, Reachable) :-
    Board = board(_, N, _, _),
    functor(Seen, seen, N),
    nb_setarg(Tee, Seen, true),
    reach([Tee], Seen, Board, [], Reachable).

reach([], _, _, Acc, Acc) :- !.
reach(Frontier, Seen, Board, Acc0, Acc) :-
    findall(I-Opts,
            ( member(I, Frontier), dice_options(Board, I, Opts) ),
            New),
    \+ member(_-options([], _), New),
    findall(J, ( member(_-options(Putts, Rolls), New),
                 ( member(J, Putts) ; member(Ts, Rolls), member(J, Ts) ),
                 J > 0, arg(J, Seen, S), S \== true,
                 nb_setarg(J, Seen, true) ), Js),
    append(New, Acc0, Acc1),
    reach(Js, Seen, Board, Acc1, Acc).

%   In-place (Gauss-Seidel) value iteration over the reachable lies.
%   E has one extra slot, N+1, fixed at 0 for "holed".
dice_expected(Board, Reachable, Tee, Expected) :-
    Board = board(_, N, _, _),
    N1 is N + 1,
    functor(E, e, N1),
    forall(between(1, N1, I), nb_setarg(I, E, 0.0)),
    findall(I-options(Putts1, Rolls1),
            ( member(I-options(Putts, Rolls), Reachable),
              maplist(slot(N1), Putts, Putts1),
              maplist(maplist(slot(N1)), Rolls, Rolls1) ),
            Table),
    sweep(100, Table, E),
    arg(Tee, E, Expected).

slot(N1, 0, N1) :- !.
slot(_, J, J).

sweep(0, _, _) :- !.
sweep(K, Table, E) :-
    foldl(update(E), Table, 0.0, Delta),
    (   Delta < 0.01
    ->  true
    ;   K1 is K - 1,
        sweep(K1, Table, E)
    ).

update(E, I-options(Putts, Rolls), D0, D) :-
    min_slots(Putts, E, 99.0, PuttBest),
    sum_rolls(Rolls, E, PuttBest, 0.0, Sum),
    V is 1 + Sum / 6,
    arg(I, E, Old),
    nb_setarg(I, E, V),
    D is max(D0, abs(V - Old)).

sum_rolls([], _, _, S, S).
sum_rolls([Ts|Rest], E, PuttBest, S0, S) :-
    min_slots(Ts, E, PuttBest, Best),
    S1 is S0 + Best,
    sum_rolls(Rest, E, PuttBest, S1, S).

min_slots([], _, M, M).
min_slots([J|Js], E, M0, M) :-
    arg(J, E, V),
    ( V < M0 -> min_slots(Js, E, V, M) ; min_slots(Js, E, M0, M) ).
