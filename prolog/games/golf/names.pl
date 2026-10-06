:- module(golf_names, [course_name//2]).

/** <module> Course names

Two-word place names plus a club suffix, e.g. "Thistle Heron Links".
*/

:- use_module('../../rng').

first([ "Whispering", "Old", "Crooked", "Silver", "Lazy", "Copper",
        "Thistle", "Bramble", "Foggy", "Golden", "Windy", "Mossy",
        "Sleepy", "Lantern", "Juniper", "Saltwind", "Amber", "Rook" ]).

second([ "Pines", "Heron", "Brook", "Dunes", "Oaks", "Meadow", "Ridge",
         "Willow", "Hollow", "Fern", "Marsh", "Badger", "Kettle",
         "Harbor", "Acorn", "Cove", "Hare", "Glen" ]).

suffix([ "Links", "Golf Club", "Country Club", "Golf Course", "Greens",
         "Fairways" ]).

%!  course_name(+Used, -Name)// is det.
%
%   A name not already in Used.
course_name(Used, Name) -->
    { first(A), second(B), suffix(C) },
    rand_member(X, A),
    rand_member(Y, B),
    rand_member(Z, C),
    { atomic_list_concat([X, Y, Z], ' ', Atom), atom_string(Atom, Name0) },
    (   { memberchk(Name0, Used) }
    ->  course_name(Used, Name)
    ;   { Name = Name0 }
    ).
