:- module(golf, [notebook//1]).

/** <module> GOLF generator

A notebook is 3 courses of 18 holes. Each hole is built from a fairway
running tee -> (doglegs) -> green, then water, trees, bunkers and slopes,
and is only accepted if golf_evaluate says it's fair: no lie can trap the
ball, Speed GOLF can finish, and Dice GOLF expected strokes sit in a band
around par 6. See docs/rules/golf.md.

Terrain codes in each row string: r rough, f fairway, s sand,
w water, t trees.
*/

:- use_module('../rng').
:- use_module(golf/rules).
:- use_module(golf/evaluate).
:- use_module(golf/names).

width(14).
height(20).
courses_per_notebook(3).
holes_per_course(18).
attempts_per_hole(60).

%   Optimal-play expected strokes in Dice GOLF. Real players trend higher,
%   so this band keeps an average round close to par 6.
expected_band(4.2, 5.6).

notebook(_{courses: Courses}) -->
    { courses_per_notebook(NC) },
    courses(1, NC, [], Courses0),
    rand_chance(0.34, HasBigfoot),
    bigfoot(HasBigfoot, Courses0, Courses).

courses(N, Max, _, []) --> { N > Max }, !.
courses(N, Max, Used, [_{number: N, name: Name, holes: Holes}|Cs]) -->
    course_name(Used, Name),
    { holes_per_course(NH) },
    holes(1, NH, Holes),
    { N1 is N + 1 },
    courses(N1, Max, [Name|Used], Cs).

holes(N, Max, []) --> { N > Max }, !.
holes(N, Max, [H|Hs]) -->
    { attempts_per_hole(K) },
    hole(K, N, H),
    { N1 is N + 1 },
    holes(N1, Max, Hs).

%   Keep drawing candidates until one passes. The last attempt is kept
%   regardless, so generation always terminates.
hole(K, N, Dict) -->
    candidate(Hole, Tee),
    { evaluate_hole(Hole, Tee, Stats) },
    (   { K =< 1 ; acceptable(Stats) }
    ->  { hole_dict(N, Hole, Tee, Stats, Dict) }
    ;   { K1 is K - 1 },
        hole(K1, N, Dict)
    ).

acceptable(stats(E, _)) :-
    expected_band(Lo, Hi),
    E >= Lo, E =< Hi.

hole_dict(N, Hole, Tee, Stats, _{number: N, par: 6, width: W, height: H,
                                 tee: [TX, TY], cup: [CX, CY],
                                 rows: Rows, slopes: Slopes,
                                 expected: E, speed: Speed}) :-
    Hole = hole(W, H, T, S, Cup),
    xy(W, Tee, TX, TY),
    xy(W, Cup, CX, CY),
    rows(W, H, T, Rows),
    findall(_{x: X, y: Y, dir: D},
            ( arg(I, S, D), D \== none, xy(W, I, X, Y) ),
            Slopes),
    (   Stats = stats(E0, Speed)
    ->  E is round(E0 * 100) / 100
    ;   E = null, Speed = null
    ).

xy(W, I, X, Y) :- X is (I - 1) mod W, Y is (I - 1) // W.

rows(W, H, T, Rows) :-
    H1 is H - 1,
    findall(Row,
            ( between(0, H1, Y),
              findall(C, ( between(1, W, X1), I is Y*W + X1, arg(I, T, C) ), Cs),
              string_codes(Row, Cs) ),
            Rows).

% Candidate holes ---------------------------------------------------------

candidate(hole(W, H, T, S, Cup), Tee) -->
    { width(W), height(H), N is W*H,
      functor(T, t, N), fill(T, 0'r),
      functor(S, s, N), fill(S, none),
      TY is H - 2 },
    rand_int(3, W - 4, TX),
    rand_int(1, W - 2, CX),
    rand_int(1, 3, CY),
    { index(W, TX, TY, Tee), index(W, CX, CY, Cup) },
    route(TX-TY, CX-CY, Route),
    rand_member(Width, [0.9, 1.2, 1.5]),
    { paint(W, H, T, near_route(Route, Width), [0'r], 0'f),
      paint(W, H, T, near_point(CX-CY, 1.6), [0'r], 0'f) },
    water(W, H, T, TX-TY, CX-CY),
    trees(W, H, T),
    bunkers(W, H, T, Route, Width, CX-CY),
    slopes(W, H, T, S, CX-CY),
    { nb_setarg(Tee, T, 0'f), nb_setarg(Cup, T, 0'f),
      nb_setarg(Tee, S, none), nb_setarg(Cup, S, none) }.

fill(T, V) :- functor(T, _, N), forall(between(1, N, I), nb_setarg(I, T, V)).

index(W, X, Y, I) :- I is Y*W + X + 1.

%   Polyline from tee to cup with 0-2 doglegs.
route(Tee, Cup, Route) -->
    rand_member(Bends, [0, 0, 1, 1, 1, 2]),
    bends(Bends, Tee, Cup, Mid),
    { append([Tee|Mid], [Cup], Route) }.

bends(0, _, _, []) --> [].
bends(1, _-TY, _-CY, [X-Y]) -->
    { width(W), Y is (TY + CY) // 2 },
    rand_int(1, W - 2, X).
bends(2, _-TY, _-CY, [X1-Y1, X2-Y2]) -->
    { width(W), Y1 is TY - (TY - CY) // 3, Y2 is CY + (TY - CY) // 3 },
    rand_int(1, W - 2, X1),
    rand_int(1, W - 2, X2).

water(W, H, T, Tee, Cup) -->
    rand_member(Kind, [none, none, pond, pond, pond, creek, creek, both]),
    water_kind(Kind, W, H, T, Tee, Cup).

water_kind(none, _, _, _, _, _) --> [].
water_kind(pond, W, H, T, Tee, Cup) -->
    rand_int(1, W - 2, PX),
    rand_int(3, H - 5, PY),
    rand_member(RX, [1.0, 1.5, 2.0, 2.5]),
    rand_member(RY, [1.0, 1.5, 2.0]),
    { paint(W, H, T, ( in_ellipse(PX-PY, RX, RY), away_from(Tee, Cup) ),
            [0'r, 0'f], 0'w) }.
water_kind(creek, W, H, T, Tee, Cup) -->
    rand_int(5, H - 6, Y0),
    creek(0, W, Y0, Cells),
    { forall(member(X-Y, Cells),
             paint(W, H, T, ( at(X-Y), away_from(Tee, Cup) ), [0'r, 0'f], 0'w)) }.
water_kind(both, W, H, T, Tee, Cup) -->
    water_kind(pond, W, H, T, Tee, Cup),
    water_kind(creek, W, H, T, Tee, Cup).

%   A creek meanders across the hole one column at a time.
creek(X, W, _, []) --> { X >= W }, !.
creek(X, W, Y, [X-Y|Cs]) -->
    rand_int(-1, 1, DY0),
    { height(H), Y1 is max(4, min(H - 5, Y + DY0)), X1 is X + 1 },
    creek(X1, W, Y1, Cs).

trees(W, H, T) -->
    rand_int(3, 6, N),
    tree_clusters(N, W, H, T),
    scatter(W, H, T, 0.04, [0'r], 0't).

tree_clusters(0, _, _, _) --> !.
tree_clusters(N, W, H, T) -->
    rand_int(0, W - 1, X),
    rand_int(0, H - 1, Y),
    rand_member(R, [0.8, 1.2, 1.5, 1.8]),
    scatter_where(W, H, T, near_point(X-Y, R), 0.75, [0'r], 0't),
    { N1 is N - 1 },
    tree_clusters(N1, W, H, T).

bunkers(W, H, T, Route, Width, CX-CY) -->
    rand_int(1, 3, N),
    bunker_list(N, W, H, T, Route, Width, CX-CY).

bunker_list(0, _, _, _, _, _, _) --> !.
bunker_list(N, W, H, T, Route, Width, Cup) -->
    rand_member(Where, [green, green, landing]),
    bunker_centre(Where, Route, Width, Cup, BX-BY),
    rand_member(R, [0.8, 1.0, 1.3]),
    { paint(W, H, T, ( near_point(BX-BY, R), \+ near_point(Cup, 1.0) ),
            [0'r, 0'f], 0's),
      N1 is N - 1 },
    bunker_list(N1, W, H, T, Route, Width, Cup).

bunker_centre(green, _, _, CX-CY, BX-BY) -->
    rand_member(DX-DY, [-2-0, 2-0, 0-2, -2-1, 2-1, -1-2, 1-2]),
    { BX is CX + DX, BY is CY + DY }.
bunker_centre(landing, [TX-TY|_], Width, _, BX-BY) -->
    rand_member(Side, [-1, 1]),
    rand_int(5, 8, Up),
    { BX is TX + Side * round(Width + 1.5), BY is TY - Up }.

slopes(W, H, T, S, Cup) -->
    rand_int(0, 3, N),
    slope_list(N, W, H, T, S, Cup).

slope_list(0, _, _, _, _, _) --> !.
slope_list(N, W, H, T, S, CX-CY) -->
    rand_int(-4, 4, DX),
    rand_int(0, 4, DY),
    rand_member(Dir, [n, e, s, w]),
    { X is CX + DX, Y is CY + DY,
      (   X >= 0, X < W, Y >= 0, Y < H,
          index(W, X, Y, I),
          arg(I, T, C), memberchk(C, [0'r, 0'f])
      ->  nb_setarg(I, S, Dir)
      ;   true
      ),
      N1 is N - 1 },
    slope_list(N1, W, H, T, S, CX-CY).

% Painting ----------------------------------------------------------------

%   Set every cell satisfying Shape (and currently in From) to To.
paint(W, H, T, Shape, From, To) :-
    W1 is W - 1, H1 is H - 1,
    forall(( between(0, H1, Y), between(0, W1, X),
             index(W, X, Y, I), arg(I, T, C), memberchk(C, From),
             call_shape(Shape, X-Y) ),
           nb_setarg(I, T, To)).

%   Like paint/6 but each matching cell is converted with probability P.
scatter(W, H, T, P, From, To) -->
    scatter_where(W, H, T, true, P, From, To).

scatter_where(W, H, T, Shape, P, From, To) -->
    { W1 is W - 1, H1 is H - 1,
      findall(I, ( between(0, H1, Y), between(0, W1, X), index(W, X, Y, I),
                   arg(I, T, C), memberchk(C, From),
                   call_shape(Shape, X-Y) ), Is) },
    scatter_cells(Is, T, P, To).

scatter_cells([], _, _, _) --> [].
scatter_cells([I|Is], T, P, To) -->
    rand_chance(P, Hit),
    { Hit == true -> nb_setarg(I, T, To) ; true },
    scatter_cells(Is, T, P, To).

call_shape(true, _) :- !.
call_shape((A, B), P) :- !, call_shape(A, P), call_shape(B, P).
call_shape(\+ A, P) :- !, \+ call_shape(A, P).
call_shape(at(Q), P) :- !, P == Q.
call_shape(near_point(C, R), P) :- !, dist(P, C, D), D =< R.
call_shape(near_route(Route, R), P) :- !, route_distance(P, Route, D), D =< R.
call_shape(in_ellipse(CX-CY, RX, RY), X-Y) :- !,
    ((X - CX) / RX)**2 + ((Y - CY) / RY)**2 =< 1.
call_shape(away_from(Tee, Cup), P) :-
    dist(P, Tee, D1), D1 > 1.5,
    dist(P, Cup, D2), D2 > 1.5.

dist(X1-Y1, X2-Y2, D) :- D is sqrt((X1 - X2)**2 + (Y1 - Y2)**2).

route_distance(P, [A, B|Rest], D) :-
    segment_distance(P, A, B, D0),
    (   Rest == []
    ->  D = D0
    ;   route_distance(P, [B|Rest], D1), D is min(D0, D1)
    ).

segment_distance(PX-PY, AX-AY, BX-BY, D) :-
    DX is BX - AX, DY is BY - AY,
    L2 is DX*DX + DY*DY,
    (   L2 =:= 0
    ->  T = 0
    ;   T is max(0, min(1, ((PX-AX)*DX + (PY-AY)*DY) / L2))
    ),
    D is sqrt((PX - (AX + T*DX))**2 + (PY - (AY + T*DY))**2).

% Bigfoot -----------------------------------------------------------------

%   In about a third of notebooks Bigfoot hides on one hole, in the trees
%   if there are any.
bigfoot(false, Courses, Courses) --> [].
bigfoot(true, Courses0, Courses) -->
    { length(Courses0, NC), holes_per_course(NH) },
    rand_int(1, NC, C),
    rand_int(1, NH, N),
    { nth1(C, Courses0, Course0),
      nth1(N, Course0.holes, Hole0),
      findall(X-Y, hiding_spot(Hole0, 0't, X, Y), Trees),
      (   Trees == []
      ->  findall(X-Y, hiding_spot(Hole0, 0'r, X, Y), Spots)
      ;   Spots = Trees
      ) },
    rand_member(BX-BY, Spots),
    { Hole = Hole0.put(bigfoot, [BX, BY]),
      replace_nth1(N, Course0.holes, Hole, Holes),
      Course = Course0.put(holes, Holes),
      replace_nth1(C, Courses0, Course, Courses) }.

hiding_spot(Hole, Code, X, Y) :-
    nth0(Y, Hole.rows, Row),
    string_codes(Row, Cs),
    nth0(X, Cs, Code).

replace_nth1(N, List0, X, List) :-
    nth1(N, List0, _, Rest),
    nth1(N, List, X, Rest).
