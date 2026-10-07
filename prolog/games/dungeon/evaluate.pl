:- module(dungeon_evaluate, [ evaluate_floor/4,
                               state_id/2
                             ]).

/** <module> DUNGEON floor evaluation

Validators the generator uses to accept or reject a floor layout,
following dungeon_rules:turn/4.

evaluate_floor/4 reports:

  - `unplayable` if the stairs can't be reached from the start, or if
    some position the player can get into has no way out at all; else
  - `too_long` if optimal play is sure to take more than Cap turns on
    average (checked early: it saves most of the work on floors the
    generator would throw away); else
  - `stats(Expected, States, Analysis)`: optimal-play expected turns to
    reach the stairs (value iteration over every roll), how many
    positions are reachable, and
    `analysis(Visits, Reachable, Values)`, per cell (compounds of W*H
    args): how often a player rushing for the stairs walks over it on
    average, and whether any move can cross it at all; and per position
    id (see state_id/2) its expected turns to the stairs.

The generator uses Visits to put enemies where players will walk and
loot where they'd have to go out of their way for it.
*/

:- use_module(rules).

%!  evaluate_floor(+Floor, +Start, +Cap, -Stats) is det.
evaluate_floor(Floor, Start, Cap, Stats) :-
    Floor = floor(W, H, _, _, _, _),
    Max is W*H*18,
    state_id(at(Start, none, false), S0),
    reachable(Floor, Max, S0, Table, Paths, Moves),
    length(Table, N),
    (   escapable(Table, Max, Rounds)
    ->  (   expected(Table, Rounds, Max, S0, Cap, E, V)
        ->  analyse(Floor, Table, Paths, Moves, V, S0, Analysis),
            Stats = stats(E, N, Analysis)
        ;   Stats = too_long
        )
    ;   Stats = unplayable
    ).

%!  state_id(?State, ?Id) is det.
%
%   Positions are numbered 1..W*H*18 (cell x 9 last directions x key) so
%   the searches below can use flat arrays instead of assoc lookups.
state_id(at(I, Last, Key), Id) :-
    last_index(Last, L),
    ( Key == true -> K = 1 ; K = 0 ),
    Id is ((I - 1) * 9 + L) * 2 + K + 1.

id_state(Id, at(I, Last, Key)) :-
    Id0 is Id - 1,
    K is Id0 mod 2, L is (Id0 // 2) mod 9, I is Id0 // 18 + 1,
    last_index(Last, L),
    ( K =:= 1 -> Key = true ; Key = false ).

last_index(none, 0). last_index(n, 1). last_index(ne, 2). last_index(e, 3).
last_index(se, 4). last_index(s, 5). last_index(sw, 6). last_index(w, 7).
last_index(nw, 8).

array(N, Init, A) :-
    functor(A, a, N),
    forall(between(1, N, I), nb_setarg(I, A, Init)).

% Reachable positions -----------------------------------------------------

%   Breadth-first over every position the player can reach. Returns
%   Id-Rolls pairs, where Rolls lists, for each roll 1..6, the sorted
%   position ids that roll can end in (0 for taking the stairs). Paths
%   holds, per position id, the same per roll as Id-Path pairs, with the
%   cells each way of moving crosses.
%
%   Positions that differ only in the direction last travelled share
%   almost all their moves, so each start direction's results are worked
%   out once per cell, key and roll (Moves) and only the no-going-back
%   rule is applied per position. Same results as turn/5.
reachable(Floor, Max, S0, Table, Paths, Moves) :-
    array(Max, false, Seen),
    nb_setarg(S0, Seen, true),
    array(Max, none, Paths),
    Floor = floor(W, H, _, _, _, _),
    N is W*H*12,
    array(N, none, Moves),
    reach([S0], Seen, Floor, Moves, Paths, [], Table).

reach([], _, _, _, _, Acc, Acc) :- !.
reach(Frontier, Seen, Floor, Moves, Paths, Acc0, Acc) :-
    findall(S-Rolls,
            ( member(S, Frontier),
              id_state(S, State),
              findall(Rs-Outs, ( between(1, 6, Roll),
                                 outcomes(Floor, Moves, State, Roll, Rs, Outs) ),
                      Both),
              pairs_keys_values(Both, Rolls, ByRoll),
              nb_setarg(S, Paths, ByRoll) ),
            New),
    findall(T, ( member(_-Rolls, New), member(Rs, Rolls), member(T, Rs),
                 T > 0, arg(T, Seen, false), nb_setarg(T, Seen, true) ),
            Next),
    append(New, Acc0, Acc1),
    reach(Next, Seen, Floor, Moves, Paths, Acc1, Acc).

%   Sorted result ids for one roll from one position, and every way of
%   getting there as Id-Path.
outcomes(Floor, Moves, at(I, Last, Key), Roll, Rs, Outs) :-
    ( Key == true -> K = 1 ; K = 0 ),
    Slot is ((I - 1) * 2 + K) * 6 + Roll,
    arg(Slot, Moves, Cached),
    (   Cached == none
    ->  first_moves(Floor, I, Key, Roll, Pool0),
        findall(D-DOuts, ( member(D, Pool0),
                           findall(Id-Path, ( move(Floor, I, Key, Roll, D, R, Path),
                                              result_id(R, Id) ), DOuts) ),
                ByDir),
        nb_setarg(Slot, Moves, ByDir)
    ;   ByDir = Cached
    ),
    pairs_keys(ByDir, Pool0),
    avoid_reverse(Pool0, Last, Pool),
    (   Pool == []
    ->  findall(Id-[], ( finish(Floor, I, Last, Key, R), result_id(R, Id) ), Outs)
    ;   findall(O, ( member(D, Pool), memberchk(D-DOuts, ByDir), member(O, DOuts) ), Outs)
    ),
    pairs_keys(Outs, Rs0),
    sort(Rs0, Rs).

result_id(exit, 0) :- !.
result_id(State, Id) :- state_id(State, Id).

% Escape ------------------------------------------------------------------

%   Every reachable position has some sequence of rolls and choices that
%   leads to the stairs. Grows the set of positions known to escape until
%   it stops changing; Rounds holds the round each joined, roughly how
%   many turns it is from the stairs.
escapable(Table, Max, Rounds) :-
    array(Max, none, Rounds),
    grow(Table, 0, Rounds),
    forall(member(S-_, Table), \+ arg(S, Rounds, none)).

grow(Table, K, Rounds) :-
    findall(S, ( member(S-Rolls, Table),
                 arg(S, Rounds, none),
                 once(( member(Rs, Rolls), member(R, Rs),
                        ( R =:= 0 ; arg(R, Rounds, KR), KR \== none, KR < K ) )) ),
            Joined),
    (   Joined == []
    ->  true
    ;   forall(member(S, Joined), nb_setarg(S, Rounds, K)),
        K1 is K + 1,
        grow(Table, K1, Rounds)
    ).

% Expected turns ----------------------------------------------------------

%   In-place (Gauss-Seidel) value iteration: each turn costs 1, the player
%   picks the best ending for each roll. Sweeping outwards from the stairs
%   lets each sweep carry values a long way, so few are needed. V has one
%   extra slot, Max+1, fixed at 0 for the stairs.
%
%   Values only ever rise towards the answer, so this fails as soon as
%   the start's value passes Cap.
expected(Table, Rounds, Max, S0, Cap, E, V) :-
    Max1 is Max + 1,
    array(Max1, 0.0, V),
    % Start from the fewest turns each position could possibly take: a
    % lower bound, close enough that few sweeps are needed.
    forall(member(S-_, Table), ( arg(S, Rounds, K), V0 is K + 1.0, nb_setarg(S, V, V0) )),
    map_list_to_pairs(round(Rounds), Table, Keyed),
    keysort(Keyed, Sorted),
    pairs_values(Sorted, Ordered),
    maplist(exit_slot(Max1), Ordered, Rows),
    arg(S0, V, E0),
    E0 =< Cap,
    sweep(200, Rows, V, S0, Cap),
    arg(S0, V, E).

round(Rounds, S-_, K) :- arg(S, Rounds, K).

exit_slot(Max1, S-Rolls, S-Slots) :-
    maplist(maplist(slot(Max1)), Rolls, Slots).

slot(Max1, 0, Max1) :- !.
slot(_, S, S).

sweep(0, _, _, _, _) :- !.
sweep(K, Rows, V, S0, Cap) :-
    sweep_rows(Rows, V, 0.0, Delta),
    arg(S0, V, E),
    E =< Cap,
    (   Delta < 0.05
    ->  true
    ;   K1 is K - 1,
        sweep(K1, Rows, V, S0, Cap)
    ).

%   Plain recursion rather than foldl/maplist: this is the inner loop.
sweep_rows([], _, D, D).
sweep_rows([I-Rolls|Rows], V, D0, D) :-
    sum_best(Rolls, V, 0.0, Sum),
    X is 1 + Sum / 6,
    arg(I, V, Old),
    nb_setarg(I, V, X),
    D1 is max(D0, abs(X - Old)),
    sweep_rows(Rows, V, D1, D).

sum_best([], _, S, S).
sum_best([[J|Js]|Rolls], V, S0, S) :-
    arg(J, V, X),
    min_value(Js, V, X, M),
    S1 is S0 + M,
    sum_best(Rolls, V, S1, S).

min_value([], _, M, M).
min_value([J|Js], V, M0, M) :-
    arg(J, V, X),
    (   X < M0 -> min_value(Js, V, X, M) ; min_value(Js, V, M0, M) ).

% Where players walk ------------------------------------------------------

%   Follow the optimal (rush for the stairs) policy as a probability flow:
%   each turn, every position's share of players splits six ways by roll
%   and takes that roll's best move. Visits sums the share crossing each
%   cell. Reachable marks every cell any move can cross.
analyse(Floor, Table, Paths, Moves, V, S0, analysis(Visits, Reachable, V)) :-
    Floor = floor(W, H, _, _, _, _),
    id_state(S0, at(Start0, _, _)),
    Cells is W*H,
    array(Cells, 0.0, Visits),
    array(Cells, false, Reachable),
    % Moves holds every way of moving from every reached cell, once.
    forall(( arg(_, Moves, ByDir), ByDir \== none, member(_-Outs, ByDir),
             member(_-Path, Outs), member(C, Path) ),
           nb_setarg(C, Reachable, true)),
    forall(member(S-_, Table), ( id_state(S, at(C, _, _)), nb_setarg(C, Reachable, true) )),
    nb_setarg(Start0, Reachable, true),
    functor(V, _, Max1),
    flow(80, [S0-1.0], Paths, V, Max1, Visits).

flow(0, _, _, _, _, _) :- !.
flow(_, [], _, _, _, _) :- !.
flow(K, Dist, Paths, V, Max1, Visits) :-
    foldl(spread(Paths, V, Max1, Visits), Dist, [], Moved),
    keysort(Moved, Sorted),
    merge_mass(Sorted, Next0),
    include(heavy, Next0, Next),
    K1 is K - 1,
    flow(K1, Next, Paths, V, Max1, Visits).

heavy(_-M) :- M > 0.0005.

spread(Paths, V, Max1, Visits, S-M, Acc0, Acc) :-
    arg(S, Paths, ByRoll),
    Share is M / 6,
    foldl(take_best(V, Max1, Visits, Share), ByRoll, Acc0, Acc).

take_best(V, Max1, Visits, Share, [O|Os], Acc0, Acc) :-
    best_out(Os, V, Max1, O, Id-Path),
    sort(Path, Cells),
    forall(member(C, Cells), ( arg(C, Visits, X0), X is X0 + Share, nb_setarg(C, Visits, X) )),
    (   Id =:= 0 -> Acc = Acc0 ; Acc = [Id-Share|Acc0] ).

best_out([], _, _, Best, Best).
best_out([O|Os], V, Max1, Best0, Best) :-
    out_value(O, V, Max1, X),
    out_value(Best0, V, Max1, X0),
    (   X < X0 -> best_out(Os, V, Max1, O, Best) ; best_out(Os, V, Max1, Best0, Best) ).

out_value(0-_, _, _, 0.0) :- !.
out_value(Id-_, V, _, X) :- arg(Id, V, X).

merge_mass([], []).
merge_mass([S-M|Rest], Merged) :-
    merge_same(Rest, S, M, Total, Rest1),
    Merged = [S-Total|Merged1],
    merge_mass(Rest1, Merged1).

merge_same([S-M|Rest], S, M0, Total, Rest1) :- !,
    M1 is M0 + M,
    merge_same(Rest, S, M1, Total, Rest1).
merge_same(Rest, _, Total, Total, Rest).
