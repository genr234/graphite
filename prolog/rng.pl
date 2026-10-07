:- module(rng, [ seed_state/2,
                 rand_int//3,
                 rand_member//2,
                 rand_chance//2,
                 shuffle//2
               ]).

/** <module> Deterministic seeded randomness

Every generator threads an RNG state through a DCG, so the same seed
yields the same notebook in native SWI-Prolog and in the WASM build.
SWI's built-in random is implementation-defined, so we roll our own:
FNV-1a to hash the seed text, xorshift32 to step the state.

Use inside a DCG body, e.g. `rand_int(1, 6, Roll)`, and run a generator
with `phrase(Gen, [S0], [S])` where `seed_state(Seed, S0)`.
*/

mask32(X, Y) :- Y is X /\ 0xFFFFFFFF.

%!  seed_state(+Seed, -State) is det.
%
%   Hash any text (atom, string or number) to a non-zero 32-bit state.
seed_state(Seed, State) :-
    format(string(Text), "~w", [Seed]),
    string_codes(Text, Codes),
    foldl(fnv1a, Codes, 0x811C9DC5, H),
    (   H =:= 0 -> State = 1 ; State = H ).

fnv1a(Code, H0, H) :-
    X is H0 xor Code,
    mask32(X * 0x01000193, H).

xorshift32(S0, S) :-
    mask32(S0 xor (S0 << 13), S1),
    S2 is S1 xor (S1 >> 17),
    mask32(S2 xor (S2 << 5), S).

%!  rand_int(+Lo, +Hi, -X)// is det.
%
%   Uniform-ish integer in Lo..Hi (inclusive).
rand_int(Lo, Hi, X), [S] -->
    [S0],
    { xorshift32(S0, S),
      X is Lo + S mod (Hi - Lo + 1) }.

%!  rand_member(-X, +List)// is semidet.
rand_member(X, List) -->
    { length(List, N), N > 0 },
    rand_int(0, N - 1, I),
    { nth0(I, List, X) }.

%!  rand_chance(+P, -Bool)// is det.
%
%   Bool is `true` with probability P (0.0..1.0), else `false`. Det on
%   purpose: a failing DCG step would roll back the RNG state.
rand_chance(P, Bool) -->
    rand_int(0, 999999, X),
    { X < P * 1000000 -> Bool = true ; Bool = false }.

%!  shuffle(+List, -Shuffled)// is det.
shuffle([], []) --> !.
shuffle(List, [X|Xs]) -->
    { length(List, N) },
    rand_int(0, N - 1, I),
    { nth0(I, List, X, Rest) },
    shuffle(Rest, Xs).
