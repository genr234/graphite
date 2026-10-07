:- module(dungeon_simulate, [ balance_report/2,
                             play_notebook/4,
                             doc_floor/3
                           ]).

/** <module> DUNGEON playtesting by simulation

A development tool for tuning the generator: plays whole notebooks with
simple simulated players under the full rules (objects used once, webs
gone once crossed, mystery rolls, the HP cap, deaths and shops), then
reports how the run went.

    ?- balance_report([a, b, c], 20).

Two kinds of player:

  - rusher: heads for the stairs, grabbing only what's on the way;
  - explorer: weighs loot and hearts against the extra turns.

Each turn a player rolls, lists every way the move can go (turn/5, with
the cells crossed) and picks the one with the best utility:

    coins + 1.5 * min(running HP, max HP)
          - Patience * expected turns left to the stairs
          + Greed * nearby loot
          - a penalty for leaving (or heading on) with HP at 0 or less

Expected turns come from dungeon_evaluate. Players don't use shop items
(they buy them, so coins are spent realistically), which makes them a
little worse than a person.
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(assoc)).
:- use_module(library(random)).
:- use_module(library(aggregate)).
:- use_module('../../graphite', [generate/3]).
:- use_module(rules).
:- use_module(evaluate).

player(rusher,   p(4.0, 0.0)).
player(explorer, p(0.6, 0.45)).

hp_weight(1.5).
turn_cap(40).

% Report ----------------------------------------------------------------------

%!  balance_report(+Seeds, +Runs) is det.
%
%   Generate a notebook per seed, play each Runs times with each kind of
%   player, and print the averages.
balance_report(Seeds, Runs) :-
    forall(player(Kind, _),
           ( findall(R, ( member(Seed, Seeds),
                          generate(dungeon, Seed, Doc),
                          prepare(Doc, Prepared),
                          between(1, Runs, K),
                          play_prepared(Prepared, Kind, K, R) ),
                     Results),
             report(Kind, Results) )).

report(Kind, Results) :-
    length(Results, N),
    format("~n== ~w (~w runs) ==~n", [Kind, N]),
    mean(Results, deaths, Deaths),
    count(Results, deaths, =:=(0), Clean),
    mean(Results, coins, Coins),
    mean(Results, bought, Bought),
    format("deaths per run     ~2f   (no deaths in ~w of ~w)~n", [Deaths, Clean, N]),
    format("final coins        ~1f~n", [Coins]),
    format("items bought       ~2f~n", [Bought]),
    Results = [R0|_],
    get_dict(floors, R0, Fs0),
    length(Fs0, NF),
    format("~nfloor  turns  hp-in   dip  dip<=0   hp+   hp-  coins+  died~n", []),
    forall(between(1, NF, F),
           ( findall(Fl, ( member(R, Results), get_dict(floors, R, Fs), nth1(F, Fs, Fl) ), Fls),
             mean(Fls, turns, Tu),
             mean(Fls, hp_in, HI),
             mean(Fls, dip, Dip),
             count(Fls, dip, >=(0), Neg),
             mean(Fls, hp_plus, HP),
             mean(Fls, hp_minus, HM),
             mean(Fls, coins_plus, CP),
             count(Fls, died, ==(true), Died),
             length(Fls, NFl),
             NegP is 100 * Neg / NFl, DiedP is 100 * Died / NFl,
             format("~t~w~5|~t~1f~12|~t~1f~19|~t~1f~25|~t~0f%~33|~t~1f~39|~t~1f~45|~t~1f~53|~t~0f%~59|~n",
                    [F, Tu, HI, Dip, NegP, HP, HM, CP, DiedP]) )),
    findall(C, ( member(R, Results), get_dict(shops, R, Cs1), member(C, Cs1) ), Cs),
    (   Cs == []
    ->  true
    ;   length(Cs, NC),
        aggregate_all(count, ( member(C, Cs), C >= 12 ), Afford),
        sum_list(Cs, SC), MC is SC / NC,
        AP is 100 * Afford / NC,
        format("~ncoins on reaching a shop ~1f, could afford an item ~0f% of the time~n", [MC, AP])
    ).

mean(Dicts, Key, M) :-
    findall(V, ( member(D, Dicts), get_dict(Key, D, V) ), Vs),
    sum_list(Vs, Sum),
    length(Vs, N),
    (   N > 0 -> M is Sum / N ; M = 0 ).

%   How many have Key's value passing Test, e.g. =:=(0) or ==(true)
%   (called with the value as the last argument, so >=(0) is "0 >= V").
count(Dicts, Key, Test, N) :-
    aggregate_all(count, ( member(D, Dicts), get_dict(Key, D, V), call(Test, V) ), N).

% Playing a notebook ------------------------------------------------------

%!  play_notebook(+Doc, +Kind, +Seed, -Result) is det.
play_notebook(Doc, Kind, Seed, Result) :-
    prepare(Doc, Prepared),
    play_prepared(Prepared, Kind, Seed, Result).

%   Movement grids and expected-turn tables for every floor, worked out
%   once for all the runs.
prepare(Doc, prepared(Doc.start_hp, Doc.shops, Floors)) :-
    maplist(prepare_floor, Doc.floors, Floors).

prepare_floor(F, pf(F.number, Floor, Start, Objects, V, VStart)) :-
    doc_floor(F, Floor, Start),
    Floor = floor(W, _, _, _, _, _),
    evaluate_floor(Floor, Start, 1000, stats(_, _, analysis(_, _, V))),
    state_id(at(Start, none, false), S0),
    arg(S0, V, VStart),
    findall(I-(Kind-Value),
            ( member(O, F.objects), object_kind(O.kind, Kind),
              I is O.y * W + O.x + 1, Value = O.value ),
            Pairs),
    list_to_assoc(Pairs, Objects).

object_kind(K0, K) :- atom_string(K, K0), memberchk(K, [coin, chest, enemy, heart, web]).

play_prepared(prepared(MaxHP, Shops, Floors), Kind, Seed, Result) :-
    set_random(seed(Seed)),
    player(Kind, Player),
    foldl(play_floor(Player, MaxHP, Shops), Floors,
          run(MaxHP, 0, 0, 0, [], []), run(_, Coins, Deaths, Bought, ShopsR, FloorsR)),
    reverse(FloorsR, FloorStats),
    reverse(ShopsR, ShopCoins),
    Result = _{deaths: Deaths, coins: Coins, bought: Bought,
               shops: ShopCoins, floors: FloorStats}.

play_floor(Player, MaxHP, Shops, pf(N, Floor0, Start, Objects, V, VStart),
           run(HP0, C0, D0, B0, S0, Fs0), run(HP, C, D, B, S, [Stats|Fs0])) :-
    % Webs disappear once crossed, so each play gets its own grid.
    Floor0 = floor(W, H, G0, Tele, Stairs, Adj),
    duplicate_term(G0, G),
    Floor = floor(W, H, G, Tele, Stairs, Adj),
    empty_assoc(Used),
    Ctx = ctx(Floor, Objects, V, VStart, Player, MaxHP),
    walk_floor(Ctx, at(Start, none, false), 0, Used,
               t(HP0, C0, 0, 0, 0, 0, HP0), t(_, _, HPP, HPM, CP, CM, Dip), Turns),
    Running is HP0 + HPP - HPM,
    (   Running =< 0
    ->  HP1 = MaxHP, C1 = 0, D is D0 + 1, Died = true
    ;   HP1 is min(MaxHP, Running), C1 is max(0, C0 + CP - CM), D = D0, Died = false
    ),
    Stats = _{turns: Turns, hp_in: HP0, dip: Dip, hp_plus: HPP, hp_minus: HPM,
              coins_plus: CP, died: Died},
    (   memberchk(N, Shops)
    ->  shop(C1, C, Bought), B is B0 + Bought, S = [C1|S0]
    ;   C = C1, B = B0, S = S0
    ),
    HP = HP1.

%   Buy what's affordable: the re-roll first, then the doubling potion.
shop(C0, C, N) :-
    (   C0 >= 13 -> C1 is C0 - 13, N1 = 1 ; C1 = C0, N1 = 0 ),
    (   C1 >= 12 -> C is C1 - 12, N is N1 + 1 ; C = C1, N = N1 ).

%   t(HPIn, CoinsIn, HP+, HP-, ¢+, ¢-, LowestRunningHP)
walk_floor(Ctx, State, Turns0, Used0, T0, T, Turns) :-
    random_between(1, 6, Roll),
    Ctx = ctx(Floor, _, _, _, _, _),
    findall(R-P, turn(Floor, State, Roll, R, P), Outs0),
    sort(Outs0, Outs),
    turn_cap(Cap),
    (   Turns0 >= Cap -> Hurry = true ; Hurry = false ),
    maplist(utility(Ctx, Used0, T0, Hurry), Outs, Scored),
    max_member(_-(Best-Path), Scored),
    apply_path(Ctx, Path, Used0, Used, T0, T1),
    Turns1 is Turns0 + 1,
    (   Best == exit
    ->  T = T1, Turns = Turns1
    ;   walk_floor(Ctx, Best, Turns1, Used, T1, T, Turns)
    ).

% Choosing a move ---------------------------------------------------------

utility(Ctx, Used, t(HP0, C0, HPP, HPM, CP, CM, _), Hurry, R-Path, U-(R-Path)) :-
    Ctx = ctx(_, Objects, V, VStart, p(Patience0, Greed), MaxHP),
    (   Hurry == true -> Patience = 50.0 ; Patience = Patience0 ),
    sort(Path, Cells),
    foldl(expect(Objects, Used), Cells, 0.0-0.0, DHP-DC),
    HP is HP0 + HPP - HPM + DHP,
    Coins is C0 + CP - CM + DC,
    hp_weight(L),
    Base is Coins + L * min(HP, MaxHP),
    (   R == exit
    ->  (   HP =< 0 -> U is Base - (Coins + 10) ; U = Base )
    ;   R = at(I, _, _),
        state_id(R, Id),
        arg(Id, V, Turns0), ( Turns0 =:= 0 -> Turns = VStart ; Turns = Turns0 ),
        lure(Ctx, Used, Cells, I, HP, Lure),
        (   HP =< 0 -> Risk is 0.5 * (Coins + 10) ; Risk = 0 ),
        U is Base - Patience * Turns + Greed * Lure - Risk
    ).

%   Expected HP and coin change from the objects on these cells.
expect(Objects, Used, I, DHP0-DC0, DHP-DC) :-
    (   \+ get_assoc(I, Used, _), get_assoc(I, Objects, Kind-Value)
    ->  worth(Value, X),
        (   Kind == coin  -> DHP = DHP0, DC is DC0 + 1
        ;   Kind == chest -> DHP = DHP0, DC is DC0 + 3.5
        ;   Kind == enemy -> DHP is DHP0 - X, DC = DC0
        ;   Kind == heart -> DHP is DHP0 + X, DC = DC0
        ;   Kind == web   -> DHP = DHP0, DC is DC0 - 3.5
        )
    ;   DHP = DHP0, DC = DC0
    ).

worth(null, 3.5) :- !.
worth(V, V).

%   Unused loot (and hearts when hurt) still on the floor, counted more
%   the closer it is to cell I.
lure(ctx(Floor, Objects, _, _, _, MaxHP), Used, Crossed, I, HP, Lure) :-
    Floor = floor(W, _, _, _, _, _),
    xy(W, I, X, Y),
    hp_weight(L),
    assoc_to_list(Objects, Pairs),
    foldl([J-(Kind-Value), S0, S]>>(
              (   get_assoc(J, Used, _) ; memberchk(J, Crossed) )
          ->  S = S0
          ;   worth(Value, Wv),
              (   Kind == coin -> G = 1
              ;   Kind == chest -> G = 3.5
              ;   Kind == heart -> G is L * min(Wv, max(0, MaxHP - HP))
              ;   G = 0
              ),
              xy(W, J, JX, JY),
              D is max(abs(X - JX), abs(Y - JY)),
              S is S0 + G / (1 + D)
          ), Pairs, 0.0, Lure).

xy(W, I, X, Y) :- X is (I - 1) mod W, Y is (I - 1) // W.

% Applying a move ---------------------------------------------------------

apply_path(Ctx, Path, Used0, Used, T0, T) :-
    foldl(use_cell(Ctx), Path, Used0-T0, Used-T).

use_cell(ctx(Floor, Objects, _, _, _, _), I, Used0-T0, Used-T) :-
    (   \+ get_assoc(I, Used0, _), get_assoc(I, Objects, Kind-Value)
    ->  put_assoc(I, Used0, true, Used),
        roll(Value, X),
        T0 = t(HI, CI, HPP, HPM, CP, CM, Dip0),
        (   Kind == coin  -> T1 = t(HI, CI, HPP, HPM, CP1, CM, Dip0), CP1 is CP + 1
        ;   Kind == chest -> random_between(1, 6, R), CP1 is CP + R, T1 = t(HI, CI, HPP, HPM, CP1, CM, Dip0)
        ;   Kind == enemy -> HPM1 is HPM + X, T1 = t(HI, CI, HPP, HPM1, CP, CM, Dip0)
        ;   Kind == heart -> HPP1 is HPP + X, T1 = t(HI, CI, HPP1, HPM, CP, CM, Dip0)
        ;   Kind == web   -> random_between(1, 6, R), CM1 is CM + R, T1 = t(HI, CI, HPP, HPM, CP, CM1, Dip0),
                             Floor = floor(_, _, G, _, _, _), nb_setarg(I, G, 0'.)
        ),
        T1 = t(HI1, CI1, P, M, CP2, CM2, _),
        Dip is min(Dip0, HI + P - M),
        T = t(HI1, CI1, P, M, CP2, CM2, Dip)
    ;   Used = Used0, T = T0
    ).

roll(null, X) :- !, random_between(1, 6, X).
roll(V, V).

% Floors from JSON ------------------------------------------------------------

%!  doc_floor(+FloorDict, -Floor, -Start) is det.
%
%   Rebuild a floor's movement grid from the generator's output.
doc_floor(F, Floor, Start) :-
    length(F.rows, H),
    F.rows = [R0|_], string_length(R0, W),
    Cells is W*H,
    functor(G, g, Cells),
    forall(( nth0(Y, F.rows, Row), sub_string(Row, X, 1, _, Ch) ),
           ( I is Y*W + X + 1, string_code(1, Ch, C), nb_setarg(I, G, C) )),
    forall(( member(O, F.objects), kind_code(O.kind, C) ),
           ( I is O.y*W + O.x + 1, nb_setarg(I, G, C) )),
    [TX, TY] = F.stairs, Stairs is TY*W + TX + 1,
    nb_setarg(Stairs, G, 0'S),
    findall(I, ( member(O, F.objects), kind_code(O.kind, 0'T), I is O.y*W + O.x + 1 ), Ts),
    ( Ts = [A, B] -> Tele = tp(A, B) ; Tele = none ),
    make_floor(W, H, G, Tele, Stairs, Floor),
    [SX, SY] = F.start, Start is SY*W + SX + 1.

%   Kinds are atoms straight from the generator, strings from JSON.
kind_code(Kind, C) :-
    atom_string(A, Kind),
    code(A, C).

code(lock, 0'L).
code(key, 0'K).
code(teleporter, 0'T).
code(web, 0'W).
