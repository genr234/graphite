:- module(graphite, [ generate/3,
                      generate_json/3,
                      game/1
                    ]).

/** <module> Notebook generation entry point

Shared by the browser (swipl-wasm, called from src/graphite_ffi.mjs) and
the native CLI (scripts/render.sh). A generator is a DCG over the RNG
state from rng.pl that produces a dict; the dict is handed to the
matching Typst template as JSON.
*/

:- use_module(library(json)).
:- use_module(rng).
:- use_module(games/golf, []).

%!  game(?Game) is nondet.
game(golf).

%!  generate(+Game, +Seed, -Doc:dict) is det.
generate(Game, Seed, Doc) :-
    (   game(Game) -> true ; domain_error(game, Game) ),
    seed_state(Seed, S0),
    phrase(Game:notebook(Body), [S0], [_]),
    format(string(SeedText), "~w", [Seed]),
    Doc = Body.put(_{game: Game, seed: SeedText}).

%!  generate_json(+Game, +Seed, -Json:string) is det.
generate_json(Game0, Seed, Json) :-
    atom_string(Game, Game0),
    generate(Game, Seed, Doc),
    with_output_to(string(Json),
                   json_write_dict(current_output, Doc, [width(0)])).
