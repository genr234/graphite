:- module(golf_rules, [ hole_index/3,
                        shot/6,
                        dice_distance/3,
                        speed_clubs/2,
                        direction/3,
                        slope_direction/1,
                        roll_slopes/3
                      ]).

/** <module> GOLF shot mechanics

The movement rules from the GOLF rules reference, shared by the
generator's validators. A hole is `hole(W, H, Terrain, Slopes, Cup)`:

  - Terrain: compound with W*H args of terrain codes
    (r rough, f fairway, s sand, w water, t trees)
  - Slopes:  compound with W*H args, each `none` or one of n/e/s/w
  - Cup:     cell index

Cells are addressed by a 1-based index `I = Y*W + X + 1`.
*/

%!  direction(?Name, ?DX, ?DY) is nondet.
%
%   The 8 shot directions. Y grows downwards (row 0 is the top of the page).
direction(n,   0, -1).
direction(ne,  1, -1).
direction(e,   1,  0).
direction(se,  1,  1).
direction(s,   0,  1).
direction(sw, -1,  1).
direction(w,  -1,  0).
direction(nw, -1, -1).

%!  slope_direction(?Dir) is nondet.
%
%   Slope arrows only point orthogonally.
slope_direction(n).
slope_direction(e).
slope_direction(s).
slope_direction(w).

opposite(n, s).
opposite(s, n).
opposite(e, w).
opposite(w, e).

hole_index(hole(W, H, _, _, _), X-Y, I) :-
    X >= 0, X < W, Y >= 0, Y < H,
    I is Y*W + X + 1.

terrain(hole(_, _, T, _, _), I, C) :- arg(I, T, C).

%!  dice_distance(+Terrain, +Roll, -Distance) is det.
%
%   Fairway adds 1, sand subtracts 1. A sand 1 gives 0, which in play
%   means "putt instead" (putting is always allowed).
dice_distance(0'f, R, D) :- !, D is R + 1.
dice_distance(0's, R, D) :- !, D is R - 1.
dice_distance(_,   R, R).

%!  speed_clubs(+Terrain, -Clubs:list) is det.
%
%   Clubs available from a lie in Speed GOLF, as Distance-OverTrees pairs.
speed_clubs(0'f, [6-true, 3-false, 1-false]) :- !.
speed_clubs(0's, [2-false, 1-false]) :- !.
speed_clubs(_,   [3-false, 1-false]).

%!  shot(+Hole, +From, +Distance, +OverTrees, +Dir, -Result) is semidet.
%
%   Result is `in` (holed) or `at(I)` (ball at rest on cell I).
%   Fails if the shot is illegal: leaves the grid, crosses trees when
%   OverTrees is false, or comes to rest in water or trees.
shot(Hole, From, Distance, OverTrees, Dir, Result) :-
    Distance > 0,
    direction(Dir, DX, DY),
    Hole = hole(W, _, _, _, Cup),
    FX is (From - 1) mod W, FY is (From - 1) // W,
    path(Hole, FX-FY, DX-DY, Distance, OverTrees, Cells, CrossedCup),
    last(Cells, Land),
    (   Land =:= Cup
    ->  Result = in
    ;   CrossedCup == overshot1
    ->  Result = in
    ;   resting_cell(Hole, Land),
        roll_slopes(Hole, Land, Result)
    ).

%   Walk the shot's path cell by cell. CrossedCup becomes `overshot1`
%   when the cup is the second-to-last cell, which the rules count as holed.
path(_, _, _, 0, _, [], none) :- !.
path(Hole, X0-Y0, DX-DY, N, OverTrees, [I|Is], Crossed) :-
    X is X0 + DX, Y is Y0 + DY,
    hole_index(Hole, X-Y, I),
    terrain(Hole, I, C),
    (   N > 1, C == 0't -> OverTrees == true ; true ),
    N1 is N - 1,
    path(Hole, X-Y, DX-DY, N1, OverTrees, Is, Crossed0),
    Hole = hole(_, _, _, _, Cup),
    (   I =:= Cup, N =:= 2 -> Crossed = overshot1 ; Crossed = Crossed0 ).

resting_cell(Hole, I) :-
    terrain(Hole, I, C),
    C \== 0'w,
    C \== 0't.

%   Slopes: keep rolling while on an arrow. Ignore an arrow that would
%   roll into water, trees or off the grid. Two arrows facing each other
%   stop the ball after the first roll. Capped to guard against cycles.
roll_slopes(Hole, I, Result) :-
    roll_slopes(Hole, I, none, 8, Result).

roll_slopes(_, I, _, 0, at(I)) :- !.
roll_slopes(Hole, I, Prev, Budget, Result) :-
    Hole = hole(W, _, _, Slopes, Cup),
    arg(I, Slopes, Dir),
    (   Dir == none
    ->  Result = at(I)
    ;   opposite(Dir, Prev)
    ->  Result = at(I)
    ;   direction(Dir, DX, DY),
        X is (I - 1) mod W + DX, Y is (I - 1) // W + DY,
        hole_index(Hole, X-Y, Next),
        resting_cell(Hole, Next)
    ->  (   Next =:= Cup
        ->  Result = in
        ;   B1 is Budget - 1,
            roll_slopes(Hole, Next, Dir, B1, Result)
        )
    ;   Result = at(I)
    ).
