:- module(labyrinth_monster, [monster//3]).

/** <module> LABYRINTH random monsters

Enemies whose name doesn't pin down a look (a GOBLIN, a MUD IMP...) get a
one-off monster put together from Kenney's Monster Builder Pack (CC0):
a body, arms, legs, a pair of head details, eyes, brows and a mouth.
typst/lib/monster.typ assembles the parts; this module only picks them.

Tougher tiers lean mean: angry eyes, fangs and horns, and a bigger build.
*/

:- use_module('../../rng').

%!  monster(+Tier, +Colors, -Dict)// is det.
%
%   Colors is the palette the enemy's name allows (Kenney's colour names).
monster(Tier, Colors, _{color: Color, limbs: Limbs, body: Body, arms: Arms,
                        legs: Legs, detail: Detail, eyes: Eyes, eye: Eye,
                        brows: Brows, mouth: Mouth, nose: Nose, size: Size}) -->
    rand_member(Color, Colors),
    % Now and then the arms and legs come in a contrasting colour.
    rand_chance(0.2, Odd),
    (   { Odd == true } -> rand_member(Limbs, [white, dark, yellow]) ; { Limbs = Color } ),
    rand_member(Body, ["A", "B", "C", "D", "E", "F"]),
    maybe(0.85, ["A", "B", "C", "D", "E"], Arms),
    maybe(0.9, ["A", "B", "C", "D", "E"], Legs),
    { mean(Tier, Mean) },
    (   { Mean == true }
    ->  maybe(0.85, [horn_large, horn_large, horn_small, ear, antenna_large, eye], Detail),
        rand_member(Eyes, [1, 2, 2, 2, 3]),
        eye(Eyes, mean, Eye),
        maybe(0.8, [angry], Brows),
        rand_member(Mouth, ["mouthB", "mouthC", "mouthF", "mouthI", "mouthJ",
                            "mouth_closed_fangs"])
    ;   maybe(0.7, [ear, ear_round, antenna_small, antenna_large, horn_small, eye], Detail),
        rand_member(Eyes, [1, 2, 2, 3]),
        eye(Eyes, goofy, Eye),
        maybe(0.25, [raised], Brows),
        rand_member(Mouth, ["mouthA", "mouthD", "mouthE", "mouthG", "mouthH",
                            "mouth_closed_teeth", "mouthB"])
    ),
    maybe(0.2, ["nose_brown", "nose_red", "nose_yellow", "nose_green"], Nose),
    { size(Tier, Size) }.

%   Tier 1 monsters are mostly goofy, later ones always mean.
mean(1, false) :- !.
mean(_, true).

size(1, 0.72).
size(2, 0.8).
size(3, 0.88).
size(4, 0.96).

%   A single big eye has to look good on its own, so it skips the slanted
%   angry shapes.
eye(1, _, Eye) --> !,
    rand_member(Eye, ["eye_human", "eye_human_red", "eye_human_green", "eye_psycho_light",
                      "eye_red", "eye_yellow"]).
eye(_, mean, Eye) --> !,
    rand_member(Eye, ["eye_angry_blue", "eye_angry_green", "eye_angry_red", "eye_red",
                      "eye_yellow", "eye_psycho_dark"]).
eye(_, goofy, Eye) -->
    rand_member(Eye, ["eye_cute_light", "eye_cute_dark", "eye_human", "eye_human_blue",
                      "eye_psycho_light"]).

%   A member of Options with probability P, else null.
maybe(P, Options, X) -->
    rand_chance(P, Yes),
    (   { Yes == true } -> rand_member(X, Options) ; { X = null } ).
