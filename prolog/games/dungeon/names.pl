:- module(dungeon_names, [gem//1]).

/** <module> The treasure at the bottom of the dungeon

A gem with a made-up name, e.g. "The Weeping Opal of Old Varnhollow",
and the numbers the Typst template draws it from.
*/

:- use_module('../../rng').

adjective([ "Weeping", "Sleeping", "Burning", "Hollow", "Frozen", "Whispering",
            "Crimson", "Midnight", "Shattered", "Laughing", "Silent", "Dreaming",
            "Starlit", "Wandering", "Forgotten", "Hungry", "Gilded", "Restless" ]).

stone([ "Opal", "Sapphire", "Emerald", "Ruby", "Garnet", "Topaz", "Amethyst",
        "Diamond", "Moonstone", "Jade", "Onyx", "Pearl", "Beryl", "Jasper" ]).

prefix([ "Old ", "Lost ", "Deep ", "High ", "", "", "", "" ]).

head([ "Var", "Dun", "Mor", "Ash", "Kel", "Bram", "Thal", "Gor", "Ell", "Ost",
       "Zan", "Wyr", "Qua", "Riv", "Sel", "Ur" ]).

tail([ "hollow", "mere", "gard", "wick", "moor", "keep", "deep", "fall",
       "reach", "holm", "stead", "vale", "crag", "fen" ]).

%!  gem(-Gem:dict)// is det.
%
%   `sides` and `crown` shape the cut: the outline is a polygon with
%   `sides` points on the girdle, and `crown` (0..1) is how much of its
%   height sits above the girdle.
gem(_{name: Name, sides: Sides, crown: Crown}) -->
    { adjective(As), stone(Ss), prefix(Ps), head(Hs), tail(Ts) },
    rand_member(A, As),
    rand_member(S, Ss),
    rand_member(P, Ps),
    rand_member(H, Hs),
    rand_member(T, Ts),
    rand_member(Sides, [5, 6, 7, 8]),
    rand_int(28, 42, C),
    { format(string(Name), "The ~w ~w of ~w~w~w", [A, S, P, H, T]),
      Crown is C / 100 }.
