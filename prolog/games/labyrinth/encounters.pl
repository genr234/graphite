:- module(labyrinth_encounters, [ encounter//3,
                                  battle_cost/4,
                                  weapon/3,
                                  table_dict/2
                                ]).
:- encoding(utf8).

/** <module> LABYRINTH encounter library

Every room page holds one encounter, built from an authored template plus
generated numbers. `encounter(+Kind, +Tier, -Dict)//` makes the page dict
(see labyrinth.pl for the fields). Tier 1-4 grows with distance from
room 1.

Die tables are six faces, each one of:

  - hit, miss                       (battles)
  - hp(N), coin(N)                  (N may be negative)
  - again, nothing, bust, add       (roll tables and the dice game)

Adjacent faces with the same outcome print as one wide cell.
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../../rng').
:- use_module(maze, [shuffle//2]).
:- use_module(monster).

% Weapons -------------------------------------------------------------------

%!  weapon(?Name, ?Damage, ?Price) is nondet.
weapon("Knife", 1, 0).
weapon("Sword", 2, 6).
weapon("Mace",  3, 12).
weapon("Axe",   3, 18).

shield_price(8).

%   The weapon a player is assumed to carry by each tier, for balancing.
tier_damage(1, 1).
tier_damage(2, 2).
tier_damage(3, 3).
tier_damage(4, 3).
tier_damage(5, 3).

% Battles -------------------------------------------------------------------

%!  battle_cost(+Faces, +Hearts, +Damage, -HP) is det.
%
%   Expected HP lost winning a battle. Each roll is a hit with chance h/6;
%   the K = ceil(Hearts / Damage) hits needed take K/p rolls on average, so
%   the misses in between cost K * (sum of damage faces) / hits.
battle_cost(Faces, Hearts, Damage, HP) :-
    include(==(hit), Faces, Hits), length(Hits, NH),
    foldl([F, A0, A]>>( F = hp(N), N < 0 -> A is A0 - N ; A = A0 ), Faces, 0, Hurt),
    K is ceiling(Hearts / Damage),
    HP is K * Hurt / NH.

%   Per tier: hearts range, damage per enemy face, and the band the expected
%   HP cost must fall in (with the tier's expected weapon).
tier(1, 2-3, [1, 1, 2],    1.0-3.0).
tier(2, 3-5, [1, 2, 2],    1.5-4.0).
tier(3, 5-7, [1, 2, 3],    2.0-5.0).
tier(4, 6-9, [2, 3, 3],    2.5-6.0).
tier(5, 10-10, [2, 3, 4],  6.0-11.0).

battle_table(Tier, Hearts, Faces) -->
    battle_table(30, Tier, Hearts, Faces).

battle_table(K, Tier, Hearts, Faces) -->
    { tier(Tier, Hearts1, Hurts, Band), Hearts1 = Lo-Hi, Band = Min-Max,
      tier_damage(Tier, Dmg) },
    rand_int(Lo, Hi, Hearts0),
    battle_faces(Tier, Hurts, Faces0),
    { battle_cost(Faces0, Hearts0, Dmg, Cost) },
    (   { K =< 1 ; Cost >= Min, Cost =< Max }
    ->  { Hearts = Hearts0, Faces = Faces0 }
    ;   { K1 is K - 1 },
        battle_table(K1, Tier, Hearts, Faces)
    ).

%   Faces come in mirrored pairs (1|6, 2|5) around a middle pair (3-4),
%   which keeps tables easy to read. Weak enemies give more hits.
battle_faces(Tier, Hurts, [F1, F2, F3, F3, F5, F6]) -->
    { Tier =< 2 -> Patterns = [middle, middle, inner, both] ; Patterns = [middle, inner, inner] },
    rand_member(Pattern, Patterns),
    hit_pattern(Pattern, Hurts, F1, F2, F3, F5, F6).

hit_pattern(middle, Hurts, F1, F2, hit, F5, F6) -->
    side_pair(outer, Hurts, F1, F6),
    side_pair(inner, Hurts, F2, F5).
hit_pattern(inner, Hurts, F1, hit, F3, hit, F6) -->
    side_pair(outer, Hurts, F1, F6),
    rand_member(H, Hurts), { F3 = hp(N), N is -H }.
hit_pattern(both, Hurts, F1, hit, hit, hit, F6) -->
    side_pair(outer, Hurts, F1, F6).

side_pair(Where, Hurts, A, B) -->
    { Where == outer -> Kinds = [hurt, hurt, miss, coins] ; Kinds = [hurt, hurt, miss] },
    rand_member(Kind, Kinds),
    side_faces(Kind, Hurts, A, B).

side_faces(hurt, Hurts, hp(A), hp(B)) -->
    rand_member(H, Hurts),
    rand_chance(0.3, Differ),
    (   { Differ == true }
    ->  rand_member(H2, Hurts)
    ;   { H2 = H }
    ),
    { A is -H, B is -H2 }.
side_faces(miss, _, miss, miss) --> [].
side_faces(coins, _, coin(A), coin(B)) -->
    rand_member(A-B, [1-(-1), (-1)-1, 1-1, (-1)-(-1)]).

% Roll tables ---------------------------------------------------------------

%   Pools of outcomes by mood, and the band for the average HP+¢ change of
%   a roll (ROLL AGAIN counts as the average of the rest).
pool(good,  [hp(1), hp(2), hp(3), hp(4), coin(1), coin(2), coin(3), again, hp(-1)]).
pool(bad,   [hp(-1), hp(-1), hp(-2), hp(-2), hp(-3), coin(-1), nothing, hp(1)]).
pool(mixed, [coin(1), coin(2), coin(3), coin(4), hp(-1), hp(-2), again, nothing]).
pool(hurt,  [hp(-1), hp(-2), hp(-2), hp(-3), hp(-4), nothing]).

band(good,  0.8-3.0).
band(bad,   (-2.5)-(-0.6)).
band(mixed, 0.3-2.2).
band(hurt,  (-3.0)-(-1.0)).

roll_table(Mood, Faces) --> roll_table(30, Mood, Faces).

roll_table(K, Mood, Faces) -->
    { pool(Mood, Pool) },
    rand_member(F1, Pool), rand_member(F2, Pool), rand_member(F3, Pool),
    rand_member(F5, Pool), rand_member(F6, Pool),
    { Faces0 = [F1, F2, F3, F3, F5, F6], band(Mood, Band), Band = Lo-Hi },
    (   { roll_value(Faces0, V), ( K =< 1 ; V >= Lo, V =< Hi ) }
    ->  { Faces = Faces0 }
    ;   { K1 is K - 1 },
        roll_table(K1, Mood, Faces)
    ).

roll_value(Faces, V) :-
    exclude(==(again), Faces, Rest),
    Rest \== [],
    foldl([F, A0, A]>>( F = hp(N) -> A is A0 + N ; F = coin(N) -> A is A0 + N ; A = A0 ),
          Rest, 0, Sum),
    length(Rest, N),
    V is Sum / N.

% Tables as JSON ------------------------------------------------------------

%!  table_dict(+Faces, -Cells) is det.
%
%   Runs of equal faces merge into one cell: from, to, label, dark.
%   Dark cells (bad or decisive outcomes) print white on black.
table_dict(Faces, Cells) :-
    runs(Faces, 1, Runs),
    maplist([F-(A-B), _{from: A, to: B, label: L}]>>label(F, L), Runs, Cells).

runs([], _, []).
runs([F|Fs], I, [F-(I-J)|Rs]) :-
    same_prefix(F, Fs, 0, N, Rest),
    J is I + N,
    I1 is J + 1,
    runs(Rest, I1, Rs).

same_prefix(F, [G|Gs], N0, N, Rest) :- F == G, !, N1 is N0 + 1, same_prefix(F, Gs, N1, N, Rest).
same_prefix(_, Rest, N, N, Rest).

label(hit, "HIT").
label(miss, "MISS").
label(again, "ROLL AGAIN").
label(nothing, "NOTHING").
label(bust, "BUST").
label(add, "Add the roll to your score").
label(hp(N), L) :- signed(N, " HP", L).
label(coin(N), L) :- signed(N, "¢", L).

signed(N, Unit, L) :-
    (   N >= 0
    ->  format(string(L), "+~d~w", [N, Unit])
    ;   M is -N, format(string(L), "−~d~w", [M, Unit])
    ).

% Encounters ----------------------------------------------------------------

%!  encounter(+Kind, +Tier, -Dict)// is det.
%
%   Kind is one of start, boss, battle, key(K), roll, choice, shop,
%   armory, dice, chest, camp.
encounter(start, _, _{kind: start, art: gate, now: false, loot: null,
                      text: ["You squeeze through a crack in the old ruins and drop into the LABYRINTH. The crack seals behind you.",
                             "Somewhere in here lurks the BULLGRIM, keeper of the maze. Beat it to get out!"]}) --> [].

encounter(boss, _, Dict) -->
    battle_table(5, Hearts, Faces),
    { table_dict(Faces, Cells),
      Dict = _{kind: battle, boss: true, art: bullgrim, now: true, loot: null,
               enemy: "BULLGRIM", hearts: Hearts, table: Cells,
               text: ["At last, the lair of the BULLGRIM! It lowers its horns and paws the ground.",
                      "Beat it to escape the labyrinth!"]} }.

encounter(battle, Tier, Dict) -->
    enemy(Tier, Name, Art, Line),
    battle_table(Tier, Hearts, Faces),
    rand_chance(0.3, Now),
    run_cost(Now, Run),
    loot(Tier, Loot),
    { table_dict(Faces, Cells),
      append([Line], Run, Text),
      art_dict(Art, ArtDict),
      Dict = ArtDict.put(_{kind: battle, now: Now, loot: Loot,
                           enemy: Name, hearts: Hearts, table: Cells, text: Text}) }.

encounter(key(Key), Tier, Dict) -->
    { T is max(1, Tier - 1) },
    enemy(T, Name, Art, Line),
    battle_table(T, Hearts, Faces),
    rand_member(Metal, ["brass", "rusty", "silver", "copper"]),
    loot(T, Loot),
    { table_dict(Faces, Cells),
      format(string(Guard), "It's guarding a ~w key. Beat it to take KEY ~w!", [Metal, Key]),
      art_dict(Art, ArtDict),
      Dict = ArtDict.put(_{kind: battle, now: false, loot: Loot, key: Key,
                           enemy: Name, hearts: Hearts, table: Cells, text: [Line, Guard]}) }.

encounter(roll, _, Dict) -->
    rand_member(event(Mood, Art, Now, Text), [
        event(bad, darts, true, "Click! You stepped on a loose stone. Darts shoot out of the walls!"),
        event(bad, pit, true, "The floor tilts and you slide towards a spiky pit!"),
        event(bad, boulder, true, "A boulder thunders down the passage behind you. Run!"),
        event(bad, gas, true, "Purple gas hisses out of the cracks in the floor."),
        event(good, fountain, false, "A glowing fountain bubbles in the corner. Take a sip."),
        event(good, mushrooms, false, "Fat spotted mushrooms carpet the floor. Lunchtime? Roll to see how they taste."),
        event(mixed, bones, false, "An old adventurer's bones lie here, still wearing a backpack. Search it."),
        event(mixed, well, false, "A wishing well! Coins glint at the bottom. Fish some out.")
    ]),
    roll_table(Mood, Faces),
    { table_dict(Faces, Cells),
      Dict = _{kind: roll, art: Art, now: Now, loot: null, text: [Text], table: Cells} }.

encounter(choice, _, Dict) -->
    rand_member(Template, [toll, witch, cups, dragon, beggar]),
    choice(Template, Dict).

encounter(shop, _, Dict) -->
    rand_member(Line, [
        "A cheerful merchant has parked a snack cart down here, somehow.",
        "A goblin with a tray of treats waves you over. 'Hungry? Everything's fresh! Mostly.'",
        "A vending golem whirrs to life. 'PLEASE. MAKE. A SELECTION.'"
    ]),
    snacks(Items),
    { Dict = _{kind: shop, art: merchant, now: false, loot: null,
               text: [Line, "Buy what you like, now or on a later visit."],
               options: Items} }.

encounter(armory, _, Dict) -->
    { findall(Opt, ( weapon(N, D, P), P > 0,
                     ( N == "Axe" -> Extra = ", 1 re-roll per enemy" ; Extra = "" ),
                     format(string(Opt), "~w — ~d¢ (~d DMG~w)", [N, P, D, Extra]) ), Ws),
      shield_price(SP),
      format(string(Shield), "Shield — ~d¢ (ignore each enemy's first attack)", [SP]),
      append(Ws, [Shield], Opts),
      Dict = _{kind: armory, art: anvil, now: false, loot: null,
               text: ["A dwarf smith hammers away at a glowing anvil. 'Arms and armour! Fair prices!'",
                      "Buy what you like, now or on a later visit, and tick it on your stats sheet."],
               options: Opts} }.

encounter(dice, _, Dict) -->
    rand_member(Goal-Loot, [15-3, 18-4, 21-5, 21-5]),
    { format(string(Rule), "Add up your rolls until you reach ~d or more. If you BUST, lose 1¢ and start again from 0.", [Goal]),
      format(string(L), "~d", [Loot]),
      table_dict([bust, add, add, add, add, add], Cells),
      Dict = _{kind: roll, art: die, now: false, loot: L, game: Goal,
               text: ["A giant die hops into your path. \"Let's play a game!\"", Rule],
               table: Cells} }.

encounter(chest, _, Dict) -->
    roll_table(mixed, Faces0),
    { Faces0 = [_|Rest], Faces = [hp(-2)|Rest] },   % a 1 is always a bite
    { table_dict(Faces, Cells),
      Dict = _{kind: roll, art: chest, now: false, loot: null,
               text: ["A dusty treasure chest sits in an alcove. Open it... carefully.",
                      "Roll a 1 and it bites!"],
               table: Cells} }.

encounter(camp, _, Dict) -->
    rand_int(2, 4, HP),
    { format(string(Opt), "Rest by the fire: +~d HP (once)", [HP]),
      Dict = _{kind: shop, art: campfire, now: false, loot: null,
               text: ["Someone left a campfire crackling in this quiet corner.",
                      "Nothing down here seems to come near it."],
               options: [Opt]} }.

run_cost(true, []) --> [].
run_cost(false, Text) -->
    rand_chance(0.35, Costs),
    (   { Costs == true }
    ->  rand_int(1, 2, C),
        { format(string(T), "(Run back and fight later: −~d¢.)", [C]), Text = [T] }
    ;   { Text = [] }
    ).

loot(Tier, Loot) -->
    { Lo is Tier, Hi is Tier + 2 },
    rand_chance(0.15, D6),
    (   { D6 == true }
    ->  { Loot = "d6" }
    ;   rand_int(Lo, Hi, N), { format(string(Loot), "~d", [N]) }
    ).

% Choices -------------------------------------------------------------------

choice(toll, Dict) -->
    rand_int(2, 4, Cost),
    roll_table(hurt, Faces),
    { format(string(Pay), "Pay the toll. Give it ~d¢.", [Cost]),
      choice_dict(troll, ["A bridge troll blocks the way and holds out a huge hand. \"Toll!\""],
                  [Pay, "Dash past. Roll for HP lost."], Faces, Dict) }.
choice(witch, Dict) -->
    rand_int(1, 3, Cost),
    roll_table(good, Faces),
    { format(string(Buy), "Buy a cup for ~d¢. Roll for result.", [Cost]),
      choice_dict(witch, ["A witch stirs a bubbling cauldron. \"A taste of my stew, dearie? Only a little bit cursed.\""],
                  [Buy, "No thanks."], Faces, Dict) }.
choice(cups, Dict) -->
    rand_int(1, 3, Bet),
    roll_table(mixed, Faces),
    { format(string(Play), "Bet ~d¢. Roll for result.", [Bet]),
      choice_dict(cups, ["A sly goblin shuffles three cups. \"Find the pebble, win big!\""],
                  [Play, "Walk away."], Faces, Dict) }.
choice(dragon, Dict) -->
    roll_table(mixed, Faces),
    { choice_dict(dragon, ["A baby dragon snores on a heap of coins."],
                  ["Tiptoe past.", "Grab a handful. Roll for result."], Faces, Dict) }.
choice(beggar, Dict) -->
    rand_int(2, 3, Gift),
    roll_table(bad, Faces),
    { format(string(Give), "Give ~d¢. Gain ~d HP from the warm feeling.", [Gift, Gift]),
      choice_dict(ghost, ["A ghostly beggar rattles an empty bowl at you."],
                  [Give, "Ignore it. Roll for result."], Faces, Dict) }.

choice_dict(Art, Text0, Options, Faces, Dict) :-
    table_dict(Faces, Cells),
    append(Text0, ["Choose one."], Text),
    Dict = _{kind: choice, art: Art, now: false, loot: null, text: Text,
             options: Options, table: Cells}.

% Snacks --------------------------------------------------------------------

snack("Glowcap Soup").
snack("Cave Cheese").
snack("Bat-Wing Pie").
snack("Moss Tea").
snack("Grub Kebab").
snack("Rock Candy").
snack("Toadstool Tart").
snack("Ember Pepper Jerky").
snack("Stalactite Slush").

snacks(Items) -->
    { findall(S, snack(S), All) },
    shuffle(All, Shuffled),
    { Shuffled = [A, B, C|_] },
    rand_int(2, 4, P1), rand_int(5, 7, P2), rand_int(8, 10, P3),
    { maplist([Name, Price, Item]>>( HP is Price - 1 - Price // 4,
                                      format(string(Item), "~w — ~d¢ (+~d HP)", [Name, Price, HP]) ),
              [A, B, C], [P1, P2, P3], Items) }.

% Enemies -------------------------------------------------------------------

%   Art is a drawing key, or monster(Colors) for enemies whose name doesn't
%   pin down a look: those get a random monster (labyrinth/monster.pl).
enemy(Tier, Name, Art, Line) -->
    { findall(e(N, A, L), enemy(Tier, N, A, L), Es) },
    rand_member(e(Name, Art0, Line), Es),
    enemy_art(Art0, Tier, Art).

enemy_art(monster(Colors), Tier, monster(M)) --> !,
    monster(Tier, Colors, M).
enemy_art(Art, _, Art) --> [].

%   The page dict's art fields: a drawing key, or "monster" plus its parts.
art_dict(monster(M), _{art: monster, monster: M}) :- !.
art_dict(Art, _{art: Art}).

enemy(1, "GIANT RAT", rat, "A GIANT RAT bursts out of a drain! It wants your lunch.").
enemy(1, "CAVE SLIME", monster([green, blue, yellow]), "A CAVE SLIME drops off the ceiling with a wet splat!").
enemy(1, "GOBLIN", monster([green, yellow]), "A GOBLIN pickpocket makes a grab for your coin purse!").
enemy(1, "BAT SWARM", bat, "A cloud of squeaking BATS swoops down the corridor!").
enemy(1, "MUD IMP", monster([dark, red]), "A MUD IMP pops out of a puddle, cackling.").
enemy(2, "BONE GUARD", skeleton, "A BONE GUARD rattles to attention and swings a rusty blade!").
enemy(2, "SPORE BRUTE", mushroom, "A SPORE BRUTE lumbers forward, puffing green dust.").
enemy(2, "CAVE SPIDER", spider, "A CAVE SPIDER drops out of the dark on a silver thread!").
enemy(2, "KOBOLD", monster([red, yellow, green]), "A KOBOLD with a lit fuse grins at you. Uh oh.").
enemy(3, "ARMORED BEETLE", beetle, "An ARMORED BEETLE charges at you, horn first!").
enemy(3, "GARGOYLE", monster([white, dark]), "A GARGOYLE cracks free of its plinth and flexes its stone claws.").
enemy(3, "CULTIST", cultist, "A hooded CULTIST chants something nasty in your direction.").
enemy(3, "MIMIC", chest, "That treasure chest has teeth! It's a MIMIC!").
enemy(4, "STONE TROLL", monster([white, dark, blue]), "A STONE TROLL ducks under the arch. It does not look friendly.").
enemy(4, "WRAITH", wraith, "A WRAITH drifts through the wall, colder than a crypt.").
enemy(4, "OGRE CHEF", monster([green, yellow, red]), "An OGRE CHEF sharpens a cleaver. You're on tonight's menu!").
enemy(4, "IRON GOLEM", golem, "An IRON GOLEM grinds into motion, gears whirring.").
