:- module(golf, [notebook//1]).

/** <module> GOLF generator

PLACEHOLDER terrain: a fairway corridor from tee to cup plus noise.
This exists to exercise the pipeline end to end; the real course
generator and its par-6 validation come with milestone 2
(see docs/rules/golf.md).

Terrain codes in each row string: r rough, f fairway, s sand,
w water, t trees.
*/

:- use_module('../rng').

width(12).
height(16).
holes_per_notebook(3).

notebook(_{holes: Holes}) -->
    { holes_per_notebook(Max) },
    holes(1, Max, Holes).

holes(N, Max, []) --> { N > Max }, !.
holes(N, Max, [H|Hs]) -->
    hole(N, H),
    { N1 is N + 1 },
    holes(N1, Max, Hs).

hole(N, _{number: N, par: 6, width: W, height: H,
          tee: [TX, TY], cup: [CX, CY], rows: Rows}) -->
    { width(W), height(H), TY is H - 2 },
    rand_int(2, W - 3, TX),
    rand_int(1, W - 2, CX),
    rand_int(1, 3, CY),
    rows(0, H, W, seg(TX-TY, CX-CY), Rows).

rows(Y, H, _, _, []) --> { Y >= H }, !.
rows(Y, H, W, Seg, [Row|Rows]) -->
    cells(0, Y, W, Seg, Codes),
    { string_codes(Row, Codes), Y1 is Y + 1 },
    rows(Y1, H, W, Seg, Rows).

cells(X, _, W, _, []) --> { X >= W }, !.
cells(X, Y, W, Seg, [C|Cs]) -->
    cell(X, Y, Seg, C),
    { X1 is X + 1 },
    cells(X1, Y, W, Seg, Cs).

cell(X, Y, Seg, C) -->
    rand_int(0, 99, R),
    { segment_distance(X-Y, Seg, D),
      (   D =< 1.2 -> C = 0'f
      ;   R < 6    -> C = 0't
      ;   R < 10   -> C = 0'w
      ;   R < 13   -> C = 0's
      ;   C = 0'r
      ) }.

%   Distance from point P to the segment A-B.
segment_distance(PX-PY, seg(AX-AY, BX-BY), D) :-
    DX is BX - AX, DY is BY - AY,
    L2 is DX*DX + DY*DY,
    (   L2 =:= 0
    ->  T = 0
    ;   T is max(0, min(1, ((PX-AX)*DX + (PY-AY)*DY) / L2))
    ),
    D is sqrt((PX - (AX + T*DX))**2 + (PY - (AY + T*DY))**2).
