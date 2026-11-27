# Dev log

Newest entries on top. Each development run adds one entry.

## v2.1.0 (2026-11-27): Survival depth
Next M9 step: cold nights, bleeding wounds, more cooking, food that goes bad and heavy loads. No player feedback was waiting.
- **Warmth** (a fourth bar under water). From 21:00 to 05:00 the desert is cold: in the open warmth runs out in about 2.5 minutes. Within **5 m of a burning fire pit** you warm up fast (+6 a second). A **roof** overhead keeps 40% of the chill off, and walls round you the rest (inside a closed cabin it keeps it all off; walls without a roof keep off at most 30%). Outside the cold hours you warm back up. Below 35 you are **cold**: food drains 1.5x faster and you don't heal. At 0 you freeze (0.5 health a second, "The cold got you."). The difficulty's needs setting scales the chill. The HUD line above the bars says "Cold: find a fire or a roof" / "Freezing!", and the bar turns icy blue.
- **Bleeding wounds.** Walker and runner claws and jackal bites build up; every 20 damage opens a wound (at most 3). Each wound costs 0.25 health a second and closes on its own after 2 minutes, and you don't heal while bleeding. A **bandage** or medkit stops all bleeding. A brute's fist and spitter acid don't cause bleeding. "Bleeding: use a bandage" on the HUD.
- **Cooking.** E at a burning fire pit cooks up to 5 batches of whatever you carry, in this order: raw meat to cooked meat, 2 millet + 1 water to 2 **flatbread** (food 22, never goes bad), 1 cooked meat + 1 melon to 2 **stew** (food 30, water 15). The prompt lists what will be cooked.
- **Food goes bad.** Each morning every piece of fresh food has a chance to rot into **rotten food**: raw meat 50%, cooked meat and stew 20%, melons and dragon fruit 12%, prickly pears 8%. In a **storage chest** the chance is halved. Canned food, millet, dates, olives and flatbread keep. Rotten food can be eaten in a pinch (food 6, health -8, never kills you). A banner says how much went bad.
- **Heavy loads.** Over half the 50 kg limit, digging, mining and chopping cost more stamina and ladders and jumps are slower, rising to 1.5x at the limit and 2x when overloaded (jump height then about half).
- **Decisions:**
  - Warmth and wounds belong to the body, so they live in `survival.gd` next to food and water. Sensing the world for them (fires, the roof and walls), cooking, spoiling and the load factor are a new script, `scripts/camp.gd`. Cooking moved there from `animals.gd`, so there is one place for it (the meat cooking works and is tested as before).
  - Shelter is measured with rays (one up, eight round you at chest height, twice a second). Dunes and rocks next to you count as walls; that felt right for a windbreak.
  - Wounds build up from damage rather than a random roll, so they are predictable and testable: about every second walker claw, every third runner claw.
  - Spoiling is rolled per piece with a generator seeded by the world, the day and the container, so the same save rots the same food. There is no per-item freshness (the inventory stacks plain counts), so it's a morning roll; a cool box or salting could come later.
  - Stew is made from cooked meat (not raw) so that E never turns your fresh raw meat into stew before you've eaten any.
- **Saved:** warmth and open wounds (seconds left each). Older saves load warm and unhurt; broken values fall back. No `SAVE_VERSION` bump (only new fields).
- Code: `survival.gd` (warmth, wounds, `status_text()`), new `scripts/camp.gd`, `player.load_mult` (ladders and jumps), the warmth bar and status line in `hud.gd`, three new items. main.gd creates the camp (`_setup_camp`), calls `camp.sense()` with the shade check, routes the fire pit to camp, scales work stamina by the load and wounds you on claws and bites (+35 lines).
- **Tests (50 new):** chilling in the open and not indoors, the cold hours, a roof alone, warming at a fire and by day, being cold (hungrier, no healing), freezing, the HUD lines, wounds building up, bleeding, the wound cap, bandages, wounds closing, respawning, rotten food, which hits make you bleed, saving (and older and broken saves), the cooking plan and prompt, cooking meat, flatbread and stew, the batch cap, a fire's warmth reach, spoiling (rates, what keeps, the same rolls for the same day, chests slower, the morning in pockets and chests), the load factor and climbing; and a cabin's shelter measured with rays (1.0 inside, 0 on open sand).
- New screenshot view `77_cold_night` (cold and bleeding by a fire pit at 23:30, with the cooking prompt and the warmth bar).

**Try:** stay out in the open after 21:00 and watch the warmth bar, then warm up at a fire pit, or sit the night out inside a cabin. Let a walker claw you and patch yourself up with a bandage. Hunt a gazelle and cook the meat with millet and a melon for flatbread and stew; leave some raw meat in your pockets overnight and some in a chest and see what's left in the morning.
**Next:** v2.2, crafting chain: a furnace (scrap to metal plates, sand to glass, clay to bricks), building parts made at the workbench, better tools (a steel shovel digs faster, a sledgehammer demolishes).

## v2.0.0 (2026-11-27): Physics pass, part 2 (throwables and loose bags)
First step of M9 after the terraforming milestones: things you throw and things you drop now fly, bounce and roll. No player feedback was waiting.
- **Throwing:** hold a stone, a molotov or a pipe bomb and hold **left click** to draw back (your hand pulls back and the prompt shows a power bar), let go to throw. A click lobs it at 40% power, 0.8 s of holding throws at full power (about 18 m/s, a little above the crosshair, plus half your running speed). Each throw is a real rigid body: it flies in an arc, bounces off the sand, walls and mutants and tumbles to a stop.
  - **Stone** (the stones you already pick up and mine): up to 26 damage with a shove and a short stagger when it hits a mutant at speed (5 m/s or more; it works on animals and the dummy too). Where it stops it becomes a stone on the ground ("[E] Pick up 1 stone"); stones landing within 1 m of a pile join it.
  - **Molotov** (new, workbench: 1 fuel can, 1 cloth, 2 water bottles make 2): shatters on the first thing it touches with a glass-and-whoomph sound, leaving a 2.6 m pool of fire for 8 s: 30 damage a second to mutants standing in it and slows them; 5 damage every half second to you. A **nest** within 4 m of the fire catches light with no fuel can (the v1.18 idea).
  - **Pipe bomb** (new, workbench tier 2: 2 scrap, 4 nails, 1 fuel can): a sparking fuse, bounces and rolls, and after 2.5 s blows up with the landmine's blast, a bit bigger (6.5 m, 260 damage at the centre, throws mutants further). It hurts you within 6.5 m and building pieces within 3.5 m, alerts wandering mutants within 60 m and burns out a nest close by.
- **Dropped bags are physics props:** every bag (dropped with Q, spilled from a chest, a dead animal's loot, a drone delivery, a full inventory) is a rigid body on its own layer (nobody trips over it). It is put on top of whatever is under it (a foundation or a floor, not inside it), falls into holes you dig, and blasts (mines, pipe bombs) throw it about. Q now tosses the stack a step ahead of you (at your feet if you face a wall). A safety net puts a bag that somehow ends up under the sand back on top.
- **Decisions:**
  - Throwing is on the left mouse button with the item in your hands (like the other tools), not a separate key: the hotbar is how everything else is used. Stones were already an item, so "rocks" are the existing stones.
  - The landmine's blast became one shared function, `traps.blast_at(pos, spec, cause)`; the mine and the pipe bomb each pass their own numbers. Its effect on mines is unchanged (all the v1.12 tests pass as before).
  - Throwables in the air and fires are short-lived and **not saved**. Saving first lands every stone still in the air (so none is lost); loading puts fires out. A pipe bomb or molotov in the air when you save is gone (it was spent anyway).
  - A pipe bomb doesn't set off nearby landmines (no chain reactions yet), and fire doesn't damage wooden pieces. Both would be easy to add if it's fun.
  - Bags keep their ground point as their saved position, so older saves load their bags where they were. No `SAVE_VERSION` bump (no new save fields).
- Code: new `scripts/throwables.gd` (drawing back and throwing, the stone, molotov and pipe bomb bodies, fires, landing stones). Changes: `loot.gd` bags as `RigidBody3D` (`toss_drop`, `ground_changed`, the rest point and the safety net), `traps.blast_at` (shared blast; `scatter_debris` also throws the "loose_props" group), `oases.burn_nest(i, free)`, models and a wind-back in `melee.gd`, two recipes and items, a hint. main.gd creates the node (`_setup_throwables`), routes left click and the prompt, and lands stones before saving (+50 lines; the blast/fire damage handler is now a named function shared by mines and throwables).
- **Tests (32 new):** what can be thrown, the recipes and the hands, power from a click and a full draw, the prompt, a throw taking one from your hands in the direction you look, nothing thrown from empty hands, a stopped stone becoming a stone on the ground and piling up, picking stones up again, saving landing stones, loading clearing fires and bombs, your own fire burning you (not every frame), a nest set alight by a molotov's fire (and still not by E without fuel), bags as physics props resting on top of a foundation, a tossed bag; and moving tests: a thrown stone hitting a walker and landing as a stone, a molotov burning a walker in the fire but not one 6 m away, a pipe bomb going off after its fuse, hurting a walker 2.5 m away and throwing a bag lying beside it, and you staying unhurt 25 m away.
- New screenshot views `74_molotov` (a pool of fire among walkers at dusk), `75_pipe_bomb` (a bomb in the air) and `76_throw_stone` (a stone drawn back, stones on the ground and a tossed bag).

**Try:** make a few molotovs at the workbench (fuel cans come from car trunks and supply crates) and throw one into a group of walkers at night, or at a nest out at an oasis instead of walking up with a fuel can. Pick up some loose stones and pelt a walker. At workbench tier 2 make a pipe bomb and bounce it off a wall into a crowd (and step back). Drop a bag with Q in front of a hole and watch it roll in.
**Next:** v2.1, survival depth: cold nights (fire pits and walls keep you warm), bleeding wounds fixed with bandages, cooking at the fire pit, food that spoils, and carried weight slowing digging and climbing.

## v1.19.0 (2026-11-27): Goals and an ending
Last step of the terraforming direction (M10): the green % now has milestones that unlock things, the final one brings the rain back (an ending, then free play), and there is a peaceful terraform-only mode. No player feedback was waiting.
- **Green milestones** (of the whole desert, the green % from v1.17). Each is announced with a banner and unlocks drone orders at the shop terminal; locked orders show "Locked: reach N% green". The HUD shows the next one ("Green 0.3% / 1%"), and the map has a GOALS panel under LAND, ticked as you go. Milestones stay reached if the green fades later.
  - **1%, First green:** two new seeds. **Olive tree** (a fruit tree: 7 days, 6 olives every 3 days, tough once grown, only 2 L a day; shades and greens round it like the date palm) and **prickly pear** (food, hardy, 4 days, 3 pears every 2 days, 2 L a day). Both are eaten and sold at the market.
  - **2.5%, Green belt:** the **dew collector** ($120 by drone): a net on two poles over a tank. Every morning it waters every square within 8 m with 4 L (a day's need), no pipes or pump. Works at outposts too.
  - **5%, Clouds gather:** the **weather station** ($400 by drone): a mast with wind cups and a solar panel. Each morning there is a 60% chance of a shower over everything within 40 m (about 300 squares, 6 L each: sand turns to soil in one shower). Rain falls till 10:00 with grey skies (rain streaks round you when you're near a station). Its E prompt shows the chance and the last rainy day.
  - **10%, The rain returns:** the **ending**. The first rain falls over the whole desert at once and an ending screen shows the day, nights survived, green %, livable score and time played. "Keep playing" goes on: from then on about half the mornings bring rain on every watered square on the map, and the v1.17 spreading turns the sand round green land to soil for the next rain, so the green keeps growing on its own.
- **Peaceful mode** (a fourth difficulty on New game): no walkers roam, no night waves (no siren; each quiet night still pays at dawn, $35 + $10 per night), the horde button does nothing, oasis guards never come out and nests don't breed (they still kill the land; burn them with a fuel can as before). Jackals still bite, at half damage. Needs as on Easy.
- **Decisions:**
  - The roadmap said 10 / 25 / 50%. I measured first: the map has about 10,000 ground squares, so 10% is 1,000 fully green squares, which need 4,000 L of water every day. The deepest main well gives 800 L. So I set the milestones at **1, 2.5, 5 and 10%**, with the weather station unlocked before the end so that 10% can be reached with stations at the base and outposts, dew collectors, springs and the spreading green. The numbers are in one table (`GOALS` in `goals.gd`) if they need tuning after playing.
  - The weather station and dew collector need no power (a solar panel on the station). The generator only runs at night or for machines with work, so a powered station would rarely be on in the morning.
  - Rain is decided at 06:00 (seeded by the world and the day) and its water counts for that day, so a rainy morning keeps plants alive through the midday heat.
  - A save made after the ending loads in free play without the ending screen again. "Machines" at 2.5% is the dew collector only for now; the water purifier from the later ideas list can join it.
  - The drone page now has 8 rows, so its buttons are a little lower (44 px) to fit a 720 px window.
- **Saved:** the milestones reached, and the last rainy day. Older saves get the milestones their land already reaches, without banners or the ending screen; broken values fall back to that. No `SAVE_VERSION` bump (only new fields).
- Code: new `scripts/goals.gd` (milestones, unlocks, the ending trigger), `scripts/weather.gd` (dew collectors, the weather station, rain and its look) and `scripts/ending_ui.gd` (the ending screen). Small hooks: `shop.goal_level` / `order_unlocked()` and a "goal" on drone orders, two new pieces in `building.gd`, `day_night.overcast` (greyer sky and weaker sun while it rains), `livable.next_goal`, a GOALS panel in `map_ui.gd`, fruit trees found by kind ("tree") in farming instead of by the date palm's name, `Game.is_peaceful()` with `peaceful` flags on waves, mutants and oases. main.gd only creates the three new nodes (`_setup_goals`), passes the weather prompt and saving through, and sets the peaceful flags (+60 lines).
- **Tests (64 new):** the milestone table and text, nothing reached on a dead desert, the four locked drone orders (and the "Locked" text), 1% unlocking only the seeds, the HUD's next goal, banners only once, 5% unlocking the machines, milestones kept when the green fades, every crop's seed and harvest items (and market prices), olive shade, the dew collector's prompt and the squares it waters (and not further), no rain without a station, the station's chance, rainy mornings the same for the same world, a shower's reach (soil at 30 m, nothing at 50 m), rain falling only in the morning and near a station, dry and rainy mornings, saving the weather (and a broken save), the ending (the screen, pausing, Keep playing, rain everywhere afterwards, no next goal on the HUD), saving goals (no second ending screen, older and broken saves), the map, and peaceful mode (no wanderers, no wave, a quiet night's pay and summary, no horde, no guards, no breeding, claiming without fighting).
- New screenshot views `69_weather_station`, `70_rain`, `71_goals_map`, `72_goals_drone` and `73_ending`.

**Try:** open the map (M) and look at the GOALS panel. Water a big patch green until the HUD passes 1% and order olive saplings and prickly pears. Past 2.5% put dew collectors round a field you can't reach with pipes (or at an outpost); past 5% build a weather station and check on a few mornings whether it rains. Or start a new game on **Peaceful** and just farm.
**Next:** M10 is done. Next on the roadmap is M9's v2.0, physics pass part 2: dropped items as physics props and throwables (molotov, pipe bomb, rocks) with arcs and bounces using the v1.12 blasts (a molotov could also burn nests).

## v1.18.0 (2026-11-27): Oases and outposts
Sixth step of the terraforming direction (M10): the desert now hides oases you can fight for, burn clean and claim. No player feedback was waiting.
- **3 to 5 hidden oases**, 85 to 195 m from the base and at least 70 m apart, on fairly flat ground with no rock, tree or wreck within 11 m. Where they lie comes from the world seed (4 in the default world). You find one by coming within 35 m (a banner, and it shows on the map as a blue dot).
- **What's there:** a pond round a **spring** (E: drink your fill and fill the watering can), a clump of **reeds** (E cuts 2, 8 a day; a new item), a red **clay bank** (E digs 2, 6 a day), four wild palms and a half-buried **old stash** (once: 2 to 4 saffron bulbs, 1 to 3 dragon fruit cuttings, up to 2 date palm saplings, a water bottle or two). Reeds and clay come back each morning. New workbench recipe: 3 reeds make 2 agave fibre.
- **Guards:** when you come within 55 m, mutants come out (3 at a time): 3 walkers and runners at an oasis without a nest. They stay round the pond: a guard that loses you walks back instead of settling where it stopped. They don't count towards the desert's 5 wandering walkers.
- **Nests:** the nearest oasis never has one, and every world has at least one. A nest keeps the land within 26 m dead (every morning those ground squares go back to sand), the palms are bare stumps, and it breeds a new guard every minute (4 waiting at most, spitters among them). **Burn it** with E and a fuel can: it burns for 6 seconds and is gone, leaving black ash. Then the spring brings the oasis back (soil the next morning, greener every morning after).
- **Wild springs** keep the land within 10 m green on their own (an oasis without a nest starts green).
- **Claiming:** E at the oasis's marker post, once the nest is burned and every guard is dead, for 6 wood and 2 cloth (pockets or a chest in reach). The post gets a red flag and a ring of stakes, and you can build anything within **16 m** of it, exactly as at the base (pieces, blueprints, traps). A claimed spring waters the land within 14 m every morning.
- **The map** shows found oases (blue), a purple dot while a nest stands, and "Outpost N" with its zone ring once claimed.
- **Night waves:** the green round wild oases is the desert's own, so it's taken off the wave lure; a claimed outpost's green is yours and counts. (Wave groups that go for fields can pick a field at an outpost.)
- **Bug fixed (found this run):** the livable score counted walls, roofs, chests, benches, wells and fire pits anywhere, not only in the base's build zone as v1.17 said. It didn't matter until outposts made building elsewhere possible. Test first (a wall at an outpost raised the base's shelter from 0 to 1), then fixed in `livable.gd`.
- **Saved:** for each oasis whether it was found, claimed, its stash searched, the nest (a nest saved while burning counts as burned), guards still to come, the reeds and clay taken today and the nest's breeding time. Guards are saved with the mutants and load as guards. Older saves get a new world's oases (not found, nests standing) with green round the wild springs; broken entries fall back to defaults. No `SAVE_VERSION` bump (only new fields).
- Code: new `scripts/oases.gd` (where they lie, the looks, guards, nests, the spring, claiming, saving). Small hooks: `building.outposts` (extra build zones in `in_zone`), `base_zone.center` (the ring of stakes round an outpost), `water.clear_cell()`, `mutant.guard_of`, `raids.wild_green`, the "oasis" loot table, the reeds item and recipe. main.gd only creates it (`_setup_oases`) and passes prompts, E, the build-mode highlight and saving through (+40 lines).
- Decisions: nests burn only with fire (a fuel can) for now; v2.0's molotovs can use the same `burn_nest`. No new crop for "rare seeds": the stash gives the exotic seeds you'd otherwise have to buy (the market page is full at 720 px, so a new crop would have needed a new page). Outposts get no mutant navigation map (mutants walk straight at walls there), and the night waves still march on the main well: day raids on outposts are v2.3. The ground at outposts can't be dug (the fine diggable grid is only round the base).
- **Tests (61 new):** how many oases and where (far out, apart, the same for the same world, others for another), no props in the ponds, the nearest without a nest, green round wild springs and dead land at a nest, wild green not luring waves, finding one, drinking and filling the can, cutting reeds and digging clay (and the daily limit and morning reset), the reeds recipe, the stash (once), guards waking and staying round the pond, guards not counting as wanderers, the claim post's reasons (guards, materials), claiming (paid), the zone ring and flag, building a foundation inside an outpost and not outside it, the livable fix, the zone highlight, a claimed oasis' green counting for the lure, a claimed spring watering further, a nest killing the land, its prompts, no burning without fuel, breeding guards, burning (and saving mid-burn), the palms coming back and the land greening, saving and loading oases and guards, older and broken saves, the map.
- New screenshot views `64_oasis`, `65_nest`, `66_nest_burning`, `67_outpost` (claimed, with a foundation and a wall) and `68_oasis_map`.

**Try:** look at the map for a direction, head out about 90 m from the base and look for palms and a pond. Kill the guards, search the stash for saffron and dragon fruit, cut some reeds and dig clay. Then find a dead oasis with a purple nest, bring a fuel can and burn it, and come back a few mornings later. Claim an oasis (6 wood, 2 cloth) and build a small walled camp at its spring.
**Next:** v1.19, goals and an ending: green % milestones (10, 25, 50) unlocking new seeds, machines and a weather station, a final milestone that brings back rain, and a peaceful terraform-only mode.

## v1.17.0 (2026-11-27): Green and livable
Fifth step of the terraforming direction (M10): the game now measures how green the desert is and how livable your base is, and rewards you for it. No player feedback was waiting.
- **Green %** of the whole desert (the green of every 4 m ground square added up, over the roughly 10,000 squares of the map). Shown on the HUD under the clock ("Green 0.11%   Livable 46") and on the map. It is small at first on purpose: v1.19 will hang its 10 / 25 / 50% milestones on it.
- **Livable score (0 to 100)** for the base: five parts of up to 20 points each, counted inside the build zone, worked out once a second:
  - **Shade:** 4 per grown date palm, 2 per roof (and triangle roof).
  - **Water:** 6 for the main well, up to 9 more for deepening it (3 per 200 L), 3 for the hand pump, 2 per dug well.
  - **Food:** 2.5 per living millet, melon, date palm or dragon fruit plant, 3 for a fire pit to cook on.
  - **Plants:** 2 per fully green square (10 squares fill it).
  - **Shelter:** 1 per wall-type piece, floor or roof, plus 2 each for a chest and a workbench.
- **Milestones and comforts** (while the score holds them; each is announced with a banner the first time):
  - **25, Settled:** health comes back twice as fast inside the build zone.
  - **50, Cool camp:** the midday heat doesn't make you thirstier inside the build zone (resting through the heat).
  - **75, Homestead:** every damaged building piece mends 10% of its hit points each morning (my take on "a better shelter").
- **The map** now draws your soil and green land (brown to green squares) and a LAND panel on the right with the green %, the livable score, its five parts and the three milestones (ticked when reached).
- **Green land spreads on its own:** each morning a fully green square gives the squares next to it 2 L towards soil and a touch of green. So the sand round green land turns to soil in 3 mornings and stays soil while the green holds, but it only goes green with your water (the touch of green is less than a dry morning takes). Let the green fade and the fringe goes back to sand.
- **Palm groves spread:** each morning a grown date palm has a 30% chance to drop a sapling on a free, watered soil spot within 2 beds (4 m) of it, 3 saplings a morning at most. Where they fall comes from the world seed and the day. The saplings are ordinary date palms (water them or the heat kills them).
- **Saved:** the best milestone reached (so banners aren't repeated). The score itself is worked out from the base. Older saves load with the milestones they already reach taken as announced; a broken value falls back to that too.
- Code: new `scripts/livable.gd` (score, green %, comforts, spreading, saving). Small hooks: `farming.sprout()` (a plant coming up on its own, using the same checks as planting), `building.mend_all()`, and `regen_mult` / `heat_shelter` on survival (set by livable). main.gd only creates it and saves it (+19 lines); the HUD and the map read it.
- Decisions: comforts follow the current score rather than the best ever, so a neglected base loses them (the milestone banner isn't repeated, though). All parts count only inside the build zone, so outposts (v1.18) can get their own score later. A roof counts for both shade and shelter, which is fair: it gives both.
- **Tests (38 new):** the map's square count, 0% on a dead desert, a bare base scoring 6 (the well), green % over the whole map, plant points only inside the zone, the HUD text, food plants (dead ones not counted) and a fire pit, palm shade, the first milestone and its banner (only once), faster healing at the base and not away from it, a cabin's roofs and walls, Cool camp with no heat at the base but heat in the desert, water upgrades, Homestead mending a wall 10%, the map's milestone list, saving and loading without repeated banners, an older save, a broken save, green spreading to the four squares next to a green one in 3 mornings (and no further), the fringe staying bare soil, fading back to sand when left dry, a palm dropping a sapling next to it, the same spot for the same world and day, none on dry soil, and never on the main well or on sand.
- New screenshot views `62_livable_map` (the map with green land and the LAND panel) and `63_livable` (the HUD line over a green farm).

**Try:** water a patch near the base green, plant a few melons and a date palm, build a fire pit and a cabin, and watch the Livable number on the HUD climb; open the map (M) to see what's missing. Reach 50 and stand in the base at 13:00: the heat warning shouldn't show. Keep a grown date palm's square and the ones around it watered and look for saplings in the mornings.
**Next:** v1.18, oases and outposts: hidden oases with springs, rare seeds, clay and reeds, guarded by mutants or a nest, which you can claim as outposts.

## v1.16.0 (2026-11-27): Water draws life
Fourth step of the terraforming direction (M10): water brings animals by day and mutants by night. No player feedback was waiting. The owner asked to merge and keep developing; everything was already merged into `main` (v1.15), so this run went on to the next roadmap item.
- **Animals by day.** Between 07:00 and 17:00 animals walk (or fly) in from 80 to 115 m out to graze on your green land, and now and then to drink at the main well. How many come depends on the land's **life**: the green of every square added up, plus a little for bare soil. About one gazelle for every 3 fully green squares (8 grazers at most), a jackal for every four grazers, birds in flocks of three (9 at most). Dead sand draws nothing. Which animal comes, from where and to which square comes from the world seed and the day.
  - **Gazelle** (55 hp): grazes and bolts at full speed when you come within 20 m (10 m crouching). 3 raw meat.
  - **Jackal** (40 hp): comes for you within 9 m and bites (6 damage), runs off once it's below half health. 1 raw meat.
  - **Sandgrouse** (10 hp): flies in at 7 m, lands to peck on the green, flies off when you come within 9 m. 1 raw meat.
  - Gunshots scare everything nearby (not jackals). At dusk they all head back out, and at nightfall any still about are gone. Animals more than 140 m from you stand still to save work.
- **Hunting and cooking.** Guns and melee weapons hit animals. A dead animal lies where it fell for 4 minutes; look at it and press **E** to butcher it for **raw meat**. Raw meat can't be eaten: light a **fire pit**, then **E** with raw meat cooks up to 5 pieces (each burns 10 s of the fire; the prompt says so, and says to light the fire if it's cold). **Cooked meat** gives 40 food.
- **Mutants drawn to the main well.** Night waves now march on the main well rather than the flag beside it. Each wave also gets a **lure**: one extra mutant for every 40 L drawn from the main well that day and for every 4 green (summed over squares), 12 at most, on top of the night-count size (the same as before, so a base with no water use and no green plays as it did). The lure is worked out at the dusk siren, and the radio says "Your water and green land draw N of them".
- **Raids on fields and pipes.** Every third group of a night wave heads for a field (a living plant picked with the wave's seed) instead of the well. Any wave mutant at the base goes for the nearest plant or water pipe within 30 m if it's closer than the nearest building piece. A mutant standing on a plant tramples it dead in about a second; one standing on a pipe tears it up in 2 seconds. When a field is wrecked they move on to the well. The night summary counts plants trampled and pipes torn up, and a banner warns you.
- **Saved:** animals (living and dead, where they're heading, whether they're leaving), the day's spawn count, the wave's lure and group count, and each wave mutant's final goal. Older saves load with no animals, no lure, and mutants heading where they were.
- Code: new `scripts/animal.gd` (one animal), `scripts/animals.gd` (spawning from green land, butchering, cooking, saving) and `scripts/raids.gd` (the lure, which groups go to fields, trampling and pipe tearing). Small hooks: `water.green_total()`, `drawn_today()` and `break_pipe()`, `farming.trample()`, a `raid` callable and `base_goal` on mutants, and `lure` / `night_goal` / `goal_source` on waves. Animals use a new physics layer 6 (32), so they don't block mutants or you; guns and melee rays include it, and a body moves to layer 2 so the E ray finds it. main.gd only creates the two new systems (`_setup_life`) and passes prompts, E and saving through (+60 lines).
- **Test runner fix (a bug found this run):** a script that failed to compile still gave "ALL TESTS PASSED" (main.gd loaded with the broken script missing, and the checks after it passed). The runner now catches every error Godot reports, through Godot 4.5's `Logger` class, and fails the run if there were any. I checked it by breaking `animal.gd` on purpose: 1 failure, exit code 1.
- Decisions: the night-count growth (2 more mutants each night) stays and the lure comes on top, so greening and watering are a real trade-off rather than a different difficulty curve. Animals don't use up well water. Cooked meat isn't sold at the market yet (the market page is full at 720 px). Animals only spawn and move by day, so mutants never meet them.
- **Tests (62 new):** how many animals the land draws, none on dead sand or at night, coming in from the desert to the green or the well, the same animal for the same world and day, flocks and the cap, creeping up crouched, gazelles bolting, jackals biting and then running, gunshots scaring birds, a body to butcher (prompt and meat), raw meat needing cooking, a cold fire, lighting it, cooking and burning it down, eating cooked meat, leaving at dusk and gone by nightfall, saving (bodies too), broken and old saves, the lure formula and wave size, the siren and radio line, night waves marching on the well with some groups going for fields, mutants picking the nearest plant, trampling (and the plant next to it surviving), tearing up a pipe, the summary lines, moving on to the well, the lure and goals saved, older saves, and in real frames: a gazelle walking in, birds flying, and a rifle shot hitting a gazelle. Plus the new "no Godot errors" check.
- New screenshot views `60_animals` (gazelles, a jackal and birds on green land; a body with the butcher prompt) and `61_raid` (mutants in a field with trampled plants).

**Try:** water a patch of land green near the base and wait for a sunny morning: gazelles and birds should walk in. Crouch to creep up, shoot one, butcher it, and cook the meat at a lit fire pit. Then compare a night after drawing the well dry with one where you barely touched it (the radio upgrade says how many the water draws), and watch whether they go for your fields.
**Next:** v1.17, green and livable: a green % for the map and a livable score for the base on the HUD and map, groves spreading on their own, and comforts at livable milestones.

## v1.15.0 (2026-11-27): The market
Third step of the terraforming direction (M10): your fields now earn cash. No player feedback was waiting.
- **Market page** at the shop terminal (a fourth tab). One row for each thing the market buys: millet, melons, dates, cotton, agave fibre, rope, cloth, logs, marigolds, dragon fruit and saffron. Each row shows how many you carry, today's price and **Sell 1** / **Sell all ($total)**. Sales come from your pockets.
- **Daily prices:** every morning each price moves up or down from its base price (±20% for goods like cloth and logs, ±30% for food, up to ±50% for saffron). A good price shows green with "(high)", a poor one red with "(low)", and the page says which crop is most wanted today. Prices come from the world seed and the day, so the same world has the same prices.
- **Gluts:** each one you sell lowers the price of the next (selling as many as the item's "glut size" halves it: 4 for saffron, 10 for dragon fruit, 15 for melons and rope, 30 for millet). The glut halves every morning, so big harvests pay best spread over a few days. "Sell all" shows the true total, glut included.
- **Base prices:** saffron $80, dragon fruit $18, rope $9, melon $7, marigolds $5, dates $4, millet and cotton $3, fibre and logs $2, cloth $1. Things the counter also sells (cloth, logs) are priced below what they cost there, so you can't buy and sell for profit. Rope is worth more than the 3 fibre it takes.
- **Fresh food:** the market sells millet, melons, dates and dragon fruit at twice today's price.
- The shop screen got a little tighter (smaller title, shorter note, slimmer counter buttons) so all four pages fit a 1280x720 window; before this the counter page's bottom line was cut off at 720 px.
- **Saved:** the gluts. Today's prices come from the day, so they aren't saved. Older saves load with no gluts; broken entries are skipped.
- Code: the new `scripts/market.gd` (prices, gluts, selling, buying, saving); the page is in `shop_ui.gd`. main.gd only creates it, connects the morning and the pop-ups, and saves it.
- Decisions: selling is from your pockets only (not chests), which keeps it simple and makes you carry the harvest to the terminal. Scrap, wood, stone and the like aren't bought: the market is for what you grow. Prices are whole dollars, so cheap crops drop in $1 steps.
- **Tests (26 new):** every harvest has a buyer, exotic crops worth the most, rope worth more than its fibre, repeatable daily prices that change from day to day and stay in their range, selling paying cash and taking the items, prices dropping as you sell, only selling what you have, no scrap, the glut wearing off, saving and broken saves, buying food (and not without cash, and not saffron), and the market page's rows and Sell all button.
- New screenshot view `59_market`.

**Try:** harvest some crops (or take them from the second test box), open the shop terminal's Market tab and compare "Sell 1" with "Sell all". Sell half a big harvest today and the rest tomorrow and see the difference. Check which crop is wanted each morning.
**Next:** v1.16, water draws life: animals by day come to water and green land (hunted for meat), and at night mutants are drawn to the main well, with wave size growing with your water use and green land.

## v1.14.1 (2026-11-27): Workbench screen fits a 1280x720 window
Player feedback first (found by the v1.14 run): at 1280x720 the workbench screen was taller than the window, so the last recipe row was cut off and the help line under it was off screen.
- **Recipes in 4 columns** instead of 3 (21 recipes now take 6 rows, not 7).
- **The recipe list scrolls** when the window is still too short for it: the screen measures the window and makes the list as tall as there is room for, so the inventory, the list and the help line all stay on screen. A scroll bar shows, and the help line then says "Mouse wheel scrolls the recipes". At 1600x900 or bigger everything shows without scrolling. It refits when the window is resized.
- The **chest screen** works the same way (the biggest 40-slot chest only just fitted at 720 px; its slots now scroll on smaller windows instead of running off the bottom).
- Code: all in `scripts/inventory_ui.gd` (`fit_to_window`). One Godot catch, noted in the code: the first time the screen opens nothing is laid out yet, so a wrapping label reports a height of thousands of pixels; the labels get the panel's width before measuring, and the list refits once the wrapped button texts are laid out.
- Decisions: scrolling rather than only more columns, because the v2.2 crafting chain will add more recipes. The list keeps at least 100 px even on a tiny window.
- **Tests (6 new):** at 720 px the workbench screen fits (696 px), the recipes scroll and the help line says so, every recipe is in the list, a tall window shows them all without scrolling, the biggest chest fits (670 px), and the plain inventory fits.

**Try:** run the game in a 1280x720 window (or smaller), open the workbench and scroll the recipes with the mouse wheel; the help line should sit at the bottom of the panel.
**Next:** v1.15, the market: sell crops, flowers and fruit at the shop terminal at daily prices that drop when you sell a lot of one thing.

## v1.14.0 (2026-11-27): Seeds and farming
Second step of the terraforming direction (M10): the soil you water can now be farmed.
- **Seeds by drone** (shop terminal, Drone orders, at the end): millet, melon, cotton, agave pups, fast acacia seedlings, desert marigold, a date palm sapling, saffron bulbs and dragon fruit cuttings ($15 to $90).
- **Seed beds:** hold a seed packet and **left click soil** to dig a seed bed and plant it. Beds sit on a 2 m grid, so four fit on one 4 m square of ground. Sand has to be watered into soil first (the prompt says so). Not on the main well.
- **Growing:** each morning a plant grows one day if its square got the crop's litres the day before. The plant's prompt (look at it, whatever you hold) says the day, whether it's watered today, and what it needs. Plants get bigger as they grow, and each crop has its own simple look (millet stalks with heads, melons, cotton bolls, agave rosettes, an acacia with a flat crown, flowers, a date palm, purple saffron, dragon-fruit cactus).
- **The midday heat (13:00):** a plant on a square that has had less than half its litres by then loses half its health; the next morning's water heals it. Hurt twice in a row and it dies (a brown stalk, **E** clears the bed). Saffron also gets hurt out in the sun.
- **Harvests by type (E on a ripe plant):**
  - **Food:** millet (3 days, 4 L, 4 millet), melon (4 days, 6 L, 2 melons). Both can be eaten with F (melons also quench thirst).
  - **Resources:** cotton (4 days: 3 cotton, which make 2 cloth at the workbench), agave (5 days, only 2 L, never minds the heat: 4 fibre, 3 make a rope), fast acacia (4 days: 3 logs).
  - **Flowers:** desert marigold (2 days, picked again every 2 days). Crops within 6 m of blooming marigolds grow 1.5 days a morning, and watered soil round them gets +10% green a morning on top.
  - **Fruit tree:** date palm (6 days, then dates every 3 days). Once grown it shades plants within 3.5 m, survives dry days, and every morning adds soil and +10% green to the 3x3 squares round it, so the sand round a palm slowly turns to soil and green on its own.
  - **Exotic:** saffron (4 days, 4 to 6 L: more rots it; needs shade at midday from a roof or a date palm) and dragon fruit (5 days, 6 L, fruit every 3 days). Both are worth the most at the market in v1.15; for now dragon fruit can be eaten.
- Digging up a bed (shovel) uproots its plant.
- **Saved:** every plant, its growth, health, and whether it has fruited. Older saves load with no plants; broken entries are skipped.
- **Test boxes:** the test box only has 40 slots and there are now more items than that, so a **second test box** stands next to it with the newer items (the seeds and harvests). Further boxes appear by themselves as items are added.
- Code: the new `scripts/farming.gd`. water.gd got a `morning_tally` signal (farming reads the squares' litres before they are cleared each morning) and `add_life` (palms and flowers adding soil and green). main.gd only creates it and passes clicks, prompts, E and saving through.
- Also: the README now covers the main well and watering (left out in v1.13) as well as farming, and its version line is right again.
- Decisions: a plant uses its square's water rather than having its own (the 4 L a day waters the whole square, all four beds). Plants don't use up the main well's water on top of what you pour. Seed beds are dug by planting rather than built in build mode, so farming works anywhere you have made soil, not just inside the base zone.
- **Tests (40 new):** seeds for every crop on the drone, crops of all five kinds, no planting without seeds or on sand, one plant to a bed, not in the main well, the prompt, no growth on a dry day, a day a watered morning, ripe after 3 days, beds and stalks drawn, the crosshair finding a plant and E harvesting it, millet as food, wilting and then dying in the heat (through the 13:00 hour signal), clearing a dead plant, no harm when watered, hardy agave, saffron dying in the sun and rotting when too wet, marigolds blooming, speeding up the millet beside them and greening the soil, picked flowers growing back, a palm shading saffron and turning the sand round it to soil, dates and fruiting again, a grown palm surviving dry middays, saving, old and broken saves, digging uprooting, cotton to cloth, and the second test box.
- New screenshot views `57_farm` (every crop from new bed to ripe) and `58_seeds` (planting prompt).

**Try:** water a few squares into soil by the base, take seeds from the second test box (or order them by drone), plant a row of millet with marigolds beside it, and keep the squares at 4 L a day before 13:00. Plant a date palm and watch the green spread round it over the next days.
**Next:** v1.15, the market: sell crops, flowers and fruit at the shop terminal at daily prices that drop when you sell a lot of one thing.

## v1.13.0 (2026-11-27): The main well and watering
First step of the new terraforming direction (M10). There is now a big **main well** next to the flag, and its water turns the sand round your base into soil and then grass.
- **The main well** stands between the flag and the crates, with a stone ring, a little roof and a crank. It holds **200 litres** and is **topped up every morning**; the water level inside goes down as you use it. Its prompt shows how much is left.
- **Watering can** (workbench: 2 scrap, 2 nails; shop $20). **E** at the main well fills it (10 L). Hold it and **left click** the sand to pour 2 L. The prompt says what the ground needs.
- **The ground is a grid of 4 m squares across the whole map:**
  - **6 L** in all turns dry sand into **soil** (damp sand first, then dark soil, shown on the ground).
  - Soil that gets **4 L in a day** is a little **greener each morning** (20% a morning, so 5 days to full): grass tufts come up, then small plants once it is past 40%.
  - A dry morning wilts it 10%. Bare soil left dry for 4 mornings goes back to sand.
  - A square takes at most 8 L a day ("soaked for today").
- **Hand pump, pipes and sprinklers:**
  - **Hand pump on the main well**: new base upgrade in the shop ($120). It puts a pump beside the well, and the pipes need it.
  - **Water pipe** (workbench: 4 for 2 scrap and 1 nail; shop: 10 for $25). Hold it and click the main well, then a sprinkler, like the power cable: 1 pipe per 2 m, 24 m at most per pipe. Sprinklers pass water on to the next sprinkler. **RMB** takes up the pipes on an end.
  - **Sprinkler** (build mode, end of the list: 3 scrap, 2 nails; base zone only). When it is piped to the well, it waters every square within 5 m **by day** (about 4 squares) up to 6 L each, taking the water from the main well, and you can see the spray. **E** turns it off or on. Its prompt says why it isn't watering (no pump, no pipe, well dry, turned off).
- **Deepen the main well**: new base upgrade with 3 levels ($150, $300, $500) for 350, 550 and 800 litres a day.
- Saved: the well's water, your can, every square's soil, wetness and green, the pipes, and whether each sprinkler is on. Older saves load with a full well and dry sand.
- Code: everything lives in the new `scripts/water.gd`; main.gd only creates it, passes clicks and prompts through and saves it (following the new code rules in CLAUDE.md).
- Decisions: the main well is a fixed part of the world (not a build piece), so it can't be destroyed or moved. One watering can is all you need (it holds the water, not each can). Greening is checked each morning, so you see damp soil straight away and grass from the next day. Mutants don't care about water yet (v1.16).
- **Tests (48 new):** the well by the flag and full, the crosshair finding it, no water without a can, filling the can, pours using the can, damp sand then soil at 6 L, the 8 L cap, an empty can, soil drawn on the ground, greening next morning (not on damp sand), the well refilling, grass and then plants, wilting, saving, old saves and a broken save, soil going back to sand, sprinklers needing the pump and a pipe, pipe cost, watering by day only, up to 6 L, stopping when done, turning off, the 24 m pipe limit, chained sprinklers, pipes and valves saved, pipes going with their sprinkler, and the deeper well.
- New screenshot views `55_greening` and `56_watering_can`.

**Try:** make a watering can at the workbench (or take one from the test box), fill it at the main well by the flag and water a patch of sand until it turns to soil. Come back after the next morning (keep it at 4 L a day) and look for grass. Then buy the hand pump, build a sprinkler, pipe it to the well and let it do the work.
**Next:** v1.14, seeds and farming: seeds by drone, seed beds on soil, crops that grow over days with water and die in the midday heat when dry.

## v1.12.0 (2026-11-27): Physics pass, part 1 (knockback, stagger, blasts, falls)
PR #14 (v1.11 gathering and processing) was merged into main first. Then the first half of the v2.0 physics pass: hits now move mutants, and blasts throw them. The roadmap item was big, so it is split: this run did the combat physics, part 2 (dropped items as physics props, throwables) is next.
- **Knockback and stagger per weapon.** Every hit now has a shove (m/s) and a stagger (seconds). While staggered, a mutant doesn't walk, and a swing or spit it was winding up is cut short. It leans back from the blow.
  - Rusty pipe: big shove, long stagger (5.5 m/s, 0.55 s). It's the crowd-control weapon.
  - Axe: in between (3.8, 0.4).
  - Machete: cuts deep but barely moves them (1.8, 0.2).
  - Pistol: light (1.2, 0.12).
  - Shotgun: 0.9 per pellet, so a point-blank blast shoves 8 m/s, with a 0.5 s stagger.
  - Rifle: 3.5, 0.45.
  - Turrets: a light shove and no stagger. They fire too fast for stagger, which would stunlock mutants.
  - A Runner flies further, a Brute shrugs most of it off (20%). No stagger lasts longer than 1.5 s.
- **Knockback is its own velocity** on top of the mutant's walking. It fades fast on the ground and hardly at all in the air, so a mutant shoved off a roof edge or a pit rim keeps going and falls. It stops dead against walls.
- **Mutants feel long falls:** above 2.5 m they lose 22 health per extra metre and reel for a moment. Off a level-2 roof (4.8 m) that's about 50, so knocking mutants off your walls is worth it. Pits up to 2.25 m (the usual trench) still don't hurt them.
- **Landmine blasts** throw mutants away and up (11 m/s out, 6.5 m/s up at the centre, less further out) and stagger them for up to 1.2 s. The body of one that dies is thrown too: a walker on the mine lands about 7 m away. Brutes barely move. The blast also **scatters loose debris** within 7 m and **shoves you** if you are too close.
- **Getting shoved:** a Brute's fist knocks you back about 2.5 m and lifts you a little. A walker's claw is a small shove, and spitter acid none. Your shove is kept apart from your walking and fades in about a second.
- Nothing new to save: knockback and stagger only last a moment.
- **Tests (17 new):** the weapon tuning order, a pipe hit shoving harder and longer than a machete (by speed, and by distance moved: 0.65 m against 0.17 m), a stagger cutting a swing short, turret hits not stunlocking, the 1.5 s cap, a blast throwing a walker but not a Brute, acid not shoving you while a Brute shoves 5 times harder than a walker, a mine throwing a walker 3 m away up and back, a 6.5 m fall hurting (89) while a 1.5 m drop doesn't, the body on the mine thrown, debris scattered 5 m, and you knocked back 2.4 m with the shove fading out. The old "brutes barely flinch" check now looks at the knockback and stagger.
- New screenshot view `54_blast`: a mine going off under four walkers with a Brute beside them.

**Try:** fight a wave with the rusty pipe: each hit shoves a walker back and stops its swing, so you can hold a doorway. Stand on a wall with the pipe and knock them off. Put a landmine in front of the gate and watch it throw them.
**Next:** v2.0 physics pass, part 2: dropped items become physics props, and throwables (rocks, pipe bombs, molotovs) that arc, bounce and use these blasts.

## v1.11.0 (2026-11-27): Gathering and processing
The owner asked for resource gathering and processing: trees and an axe, rocks to pick up, machines bought with cash and flown in by drone (a rock crusher for cement), and traps made from gathered resources.
- **Trees:** seven groves of date palms and dry acacias round old water holes (62 to 195 m out) and about 30 lone trees, 110 or so in all, none inside even the biggest build zone. They have their own random stream, so older saves' rocks and containers keep their ids.
- **Axe** (workbench: 3 scrap, 2 wood; shop $40). Left click on a tree chops it (8 stamina a blow, 3 to 9 blows by size; the prompt shows how many are left and about how many logs). The last blow topples it away from you and its **logs** (2 to 5) go in your bag; what doesn't fit lands in a bag beside you. Felled trees grow back after **3 mornings**. Swung at anything else, the axe is a weapon (34 damage, between the pipe and the machete). Half-chopped and felled trees are saved.
- **Logs** (3 kg, stack 10): split by hand at the workbench into **2 wood**, or into **5** at a sawmill. Log stakes are made from them.
- **Loose stones:** 150 small stones lie about the sand, most beside rocks and 24 within 40 m of the base. **E** picks one up (+1 stone). They turn up again after 2 mornings. Saved.
- **Machines, by drone** (drone section of the shop): **Sawmill** $150 (1 log makes 5 wood every 6 s), **Rock crusher** $250 (3 stone make 1 cement bag every 15 s), **Nail press** $200 (1 scrap makes 8 nails every 8 s). Each arrives as a crate in your bag. Place it in build mode (end of the list), where it turns freely like the other objects.
  - They **run on power**: put one within 4 m of a generator or run a cable to it. **E** loads everything it takes from your pockets (its hopper holds 30) and takes what it has made (it stops when 60 are waiting). The prompt says what is in, what is ready and why it isn't running ("no power", "waiting for stone", "full").
  - Generators now also start up **by day** when a machine has work, and burn fuel for it. The saw blade, crusher wheel or flywheel spins while a machine works.
  - Demolishing a machine with the hammer gives you back its crate. What is in a machine is saved.
- **Log stakes** (trap, 3 logs + 2 nails, end of the build list): sharpened logs crossed over a rail. They slow a mutant on them to 45% and bite for 26 a second, wearing down 5 per bite. Mutant pathfinding counts them as a trap, like the others.
- **Support colours (build mode, from Valheim):** an upstairs piece's preview is green when it is well held (60% or more), yellow from 35%, and orange close to the 20% limit. Red still means it can't be built.
- **Merged with v1.10 from main:** a separate v1.10 run on main added mutant navigation (`scripts/nav.gd`) while this branch had its own flow field. Main's version is more complete (paths to the player, stepping onto foundations, work spread over frames), so this branch dropped its own and kept main's. Log stakes cost 9 in its trap costs.
- Everything new is in the test box (it fills from every item), the machine crates included.
- **Tests (32 new):**
  - Trees and stones: trees in groves and none in the zone, stones near the base, the axe finding the tree in front of you and its prompt, blows counting down, a half-chopped tree saved, the last blow giving its logs, no second felling, felled trees loaded, regrowth after 3 days but not 2, the axe and log recipes, picking up a stone (once), picked stones saved and coming back.
  - Machines: the three on the drone, an idle generator staying off by day, the sawmill prompt and loading, the generator starting up for it, 5 wood in 6 s, machine contents saved, taking the wood, a crusher without power waiting then grinding cement once cabled, demolishing giving the crate back.
  - Log stakes biting, and the preview colours.
  - New screenshot views `52_trees` and `53_machines`.

**Try:** buy a sawmill and a rock crusher from the drone, put them beside your generator with a can of fuel, then chop a grove and pick up stones on the way back: logs and stone in, wood and cement out.
**Next:** v2.0, the physics pass (explosions, throwables, knockback), or more processing (a furnace) if the owner prefers.

## v1.10.0 (2026-11-27): Mutant navigation
Mutants no longer walk straight at you and claw at the first wall they meet. They find a way round.
- **Paths round the base:** a 1 m grid covers the build zone and 16 m round it. Mutants inside it follow a shared **flow field** to you (or to the flag if you are out in the desert). Going round costs walking; a wall, closed gate, fence or sandbag wall in the way costs its **hit points** (tearing it down takes time). So:
  - an **open gate** is the way in, even round the far side of the base;
  - with every gate shut they go for the **weakest** wall or gate: a damaged one, or wood before scrap or stone (a locked metal door counts double, an electric fence a bit more);
  - **groups pick the same weak point**, from every side, because they all follow the same field;
  - **pits and trenches:** a rise they can't climb (2 m or more) can't be taken, so they walk round the end of a trench; a ring with no gap still makes them come straight and fall in, as before. Shallow dips cost a little climbing;
  - **traps:** barbed wire, spike strips, barricades and spiked pits cost a few metres, so they walk round them when the way round is short. Landmines cost nothing (they don't know they're there). Chests, turrets and other objects are walked round;
  - **Brutes** ignore all this and come straight through, as before.
- Mutants now **step up onto foundations** (and other low pieces up to 0.8 m) instead of wrecking them, so a gate in a wall on foundations works.
- Following a path that is open ahead, a mutant that bumps into a wall corner slides round it for 1.6 s before it starts tearing at it, and never wrecks an open gate it is squeezing through.
- The paths are redone when you build, open or shut a gate, a piece breaks or gets badly damaged, or the ground is dug, and the path to you when you move 2 m. The work is spread over frames (about 1 ms a frame, a fresh path in about a third of a second) and only done while mutants need it; the map itself is made when the game loads.
- **Why not Godot's navigation mesh** (the roadmap said "navigation mesh"): the base is built on a grid anyway, and the important part is giving each wall a cost (its hit points) so mutants pick the weakest one, which a navigation mesh can't express. Baking a mesh over ground that is dug all the time would also be slow. A grid flow field is cheap, exact for walls on grid edges, and shared by the whole wave.
- **Code:** `scripts/nav.gd` (cost map, `rebuild_map()` that only redoes the cells round what changed, `compute_now()`, sliced Dijkstra in `_advance()`, `direction()`, `way_clear()`, `trace()` / `pieces_on()` for tests). `building.revision` and `terrain.revision` say when to redo it. Mutant `_nav_want()`, `_step_up()`, `nav_field`. `tools/nav_bench.gd` times it; `tools/soak_test.gd` takes `gate=1` and says who broke what.
- **Tests (20 new, 1 changed):** the grid covers the zone, the path goes round to an open gate (and is longer but cheaper than a wall), mutants by a wall are sent sideways, in through the gate, closing a gate makes paths stale, the damaged wall picked from north, east and south, another wall picked once repaired, never the stone wall, Brutes not following and Walkers following, wire costing, a trench walked round (and no way out of a deep one), and with real physics a walker going round a walled yard on foundations, in at the open gate and onto the foundations, without scratching a wall, and reaching you. The old "breaks through a wall" test now shuts you in a 2 x 2 m box (a single wall they now simply walk round). New screenshot view `51_nav` shows the paths as yellow dots.
- Soak test (wave 6, a 12 x 12 m ring of walls): with the gate open only the two Brutes broke walls; with it shut, the wave tore down one wall and came in through that gap.
- Noticed, not fixed: now and then a mutant out in the desert gets stuck against a rock for good (also before this version).

**Try:** build a ring of walls with a doorway, leave the gate open and call a horde with the red button: watch them go round to the gate (a turret or a spike strip there is a good idea). Then shut the gate and call another: they all pile onto the same wall (gates close by themselves only at night, so by day the button is the easy way to watch).
**Next:** v2.0, the physics pass: explosions pushing mutants and items, throwables (molotov, pipe bomb, rocks), knockback per weapon, mutants falling into pits and off roofs.

## v1.9.0 (2026-11-27): Building overhaul: free turning, ready-made buildings, the horde button
The owner asked for building to become a big part of the game, tuned like the survival builders: turn pieces before placing them, ready-made cabins, and a stand with a button that brings the enemies to you. This run does those instead of the planned mutant navigation (now v1.10).
- **Turning pieces:** **R** still turns a quarter clockwise; new keys **Z / X** turn the other way and on. Objects (chest, workbench, barricade, traps, fire pit, generator, floodlight, turret, switch) turn in **15° steps**, so they no longer have to sit square to the grid; the build line shows "facing 120°". Grid pieces (walls, stairs...) turn a quarter with Z / X. The see-through preview now **swings round smoothly** instead of snapping. Turned objects are saved (older saves load as before).
- **Ready-made buildings (T in build mode):** Shelter (1×1), Cabin (2×2, door and window), Big cabin (3×3, door, four windows), Watchtower (pillars, ladder up through a trapdoor, half walls, roof) and Gatehouse (a gate between walls, a walkway with half walls on top, a ladder). The preview of the whole building follows the crosshair (the square you aim at is its middle), turns with R / Z / X, and turns red if any piece would clash, it leaves the zone, or the ground under it is more than 1.4 m uneven. The build line shows the whole bill.
  - **Left click lays a free blue blueprint.** Walk up to it: "[E] Build Cabin: next wooden wall (3 wood, 3 nails)   11 pieces left". **E builds the next piece; hold E to keep going** (one every 0.3 s), foundations first, then walls, then the roof. Each piece is paid from your pockets and any chest in reach and costs the usual stamina, so it stops when the wood or your breath runs out, and you can come back later. **Right click on a blueprint** in build mode scraps it (nothing was paid for unbuilt pieces). Blueprints, half built or not, are saved.
  - Foundations of a ready-made building all come to the same height (the sand is filled in under them), so its walls line up.
- **The horde button:** a yellow post with a big red button stands by the spawn point (west of you when you start). **E** calls a horde right away, day or night: as many mutants as the last night brought (night 1's size before the first night), from about 60 m round the stand, with the siren and a blinking lamp. It shows "Horde: 3 left" under the clock, pays the kill bounty (no night pay or base bonus) and ends with "Horde wiped out!". It can't be pressed while a wave is out. A horde called by day survives saving and loading.
- **Fix:** a wall could not be built against the end of another wall at a corner ("Something is in the way"): the room check now leaves a wall's thickness at each end of pieces a whole square long. Thin roofs no longer make the room check fail with "BoxShape3D size cannot be negative".
- Build mode shows its keys under the build line, and the build text now grows upwards so it never covers the hotbar. New keys on the controls page and in the README.
- **Code:** `scripts/prefabs.gd` (layouts, `turn_slot()`, `placed()`, `total_cost()`), building `sites` with `add_site()` / `site_next()` / `build_site_piece()` / `site_prompt()` / `sites_save_data()` and `add_ghost_meshes()`, slot `"turn"` and `FREE_TURN`, build mode `fine_turn()` / `toggle_prefabs()` / `evaluate_prefab()` / `place_prefab()` / `prefab_middle()`, `scripts/horde_stand.gd`, `Waves.call_horde()`.
- **Tests (38 new):** slots turned four times come back, a turned cabin keeps its walls and roof on its squares all four ways, T and the prefab build line, a blueprint costing nothing and showing every piece, no second blueprint on top, the bill, nothing built without materials, E building and paying for the first foundation, the whole cabin built from a chest and pockets with its roof supported and its door and window, every ready-made building going up in full, a half-built blueprint saved and loaded, walls meeting at a corner, 15° turning both ways, a turned chest standing and loading turned, walls turning a quarter, the key help, and the horde button (prompt, a horde by day, no second press, spawning about 60 m out, saved by day, bounty-only pay, its summary). New screenshot views `48_prefabs`, `49_blueprint`, `50_horde`.

**Try:** press B, then T, pick the Cabin with the mouse wheel, turn it with R and lay it next to the flag. Fill a chest nearby with wood, nails and scrap from the test box and hold E at the blueprint. Then go and press the red button.
**Next:** v1.10 mutant navigation (a navigation mesh so mutants go round to an open gate or the weakest wall), unless the owner asks for more building first.

## v1.8.0 (2026-11-26): Doors, switches and wiring (M8 done)
- **Cables instead of the 18 m reach:** floodlights and electric fences now get power along **cables** from a running generator. Anything within **4 m** of a generator plugs straight in. Make **cable** at the workbench (1 scrap + 1 cloth = 6). Hold it and left click a generator, then the floodlight, fence, switch or turret to join them; it costs one cable per 2 m (24 m at most for one cable, so put a switch in between for longer runs). The prompt shows the cost before you click. Right click takes up all of a piece's cables and gives the cable back. Cables hang as thin dark lines with a little sag, and power runs on from piece to piece.
- **Power switch** (2 scrap, 2 nails, last in the build list): power only passes through it when it is on; **E** flips it. Put one between the generator and the floodlights to keep them dark until you want them.
- **Powered turrets:** a turret cabled to a running generator turns and fires **40% faster**. Without power it works as before.
- **Gates close by themselves at night:** a gate or metal door left open closes 8 seconds after nightfall, or 8 seconds after you open it at night, but never while you stand in it. By day they stay as you leave them.
- **Lockable metal door:** **R** on a shut metal door locks it ("Metal door, locked   [R] Unlock"). Locked, it won't open and takes **half damage**. The lock is saved.
- **Older saves keep their power:** each generator gets free cables to every floodlight and fence that was within its old 18 m reach. The soak test lays its cables the same way.
- Fix: debris could still now and then fall through the ground, when the ground's collision was rebuilt under it (loading a save rebuilt every ground chunk). Loading now only rebuilds chunks that changed, and as a safety net a chunk found more than 1 m under the sand is removed. In 5 test runs in a row the debris settled every time; once, the safety net took one stray chunk away, so the cause isn't fully gone, just harmless.
- That finishes **M8, building capabilities**.
- **Tests (27 new, 2 changed):** plugging in next to a generator, needing a cable further away, chests refusing cables, starting and finishing a cable (and paying for it), a switch blocking power when off and passing it when on (the floodlight lights, the turret gets power), the switch prompt, the length limit, cables saved and loaded, older saves getting cables in the old reach, taking cables up, gates staying open by day, waiting while you stand in them and closing once you leave at night, and the metal door (locking, staying shut, half damage, the lock saved, unlocking, no locking while open). The v0.20 power test now lays its cables; the door prompt test allows the new "[R] Lock". The `29_power` screenshot shows cables and a switch.

**Try:** run a cable from your generator to a switch by the gate, and from there to the floodlights and the turrets.
**Next:** M9, v1.9 mutant navigation: a navigation mesh rebuilt when the base or the ground changes, so mutants go round to an open gate or the weakest wall.

## v1.7.0 (2026-11-26): Faster building
- **Lines:** in build mode, hold left click and let go somewhere else to build a straight **line** (up to 12) of the piece: squares (foundations, floors, roofs) along the longer direction, walls and fences along their own edge, and pillars from corner to corner. Each piece is checked and paid on its own (and costs its stamina), so the line simply stops when the materials or your breath run out, skipping spots that are blocked. A plain click still builds one piece. While dragging, the build line shows "Line: 5 pieces (let go to build)".
- **Area hammer:** with the hammer, **R** repairs every damaged piece within 8 m, nearest first, and **G** upgrades every piece within 8 m that has the same tier as the one you look at (except damaged ones and upgrades that would bring something down). Both are paid from your pockets **and any chest within reach**, and cost 5 stamina a piece.
- **Moving pieces:** in build mode, **G** picks up the piece you look at (traps and ladders too). A chest keeps everything in it, a turret its ammo, a generator its fuel, a well its water, and damage stays. Left click puts it down anywhere it fits, for free. G again, leaving build mode or saving puts it back where it was. Foundations, stairs, ramps, wells and anything that holds up another piece can't be moved ("Something rests on it").
- New key **G** (on the controls page and in the README).
- Fix: a debris chunk could now and then start inside the sand (from the bottom of a wall or a foundation) and drop through the ground; chunks now start at least 45 cm above it (the debris test passed 3 runs in a row after).
- **Code:** `building.piece_data()` / `restore_piece()` (saves use them too), `move_problem()`; build mode `begin_drag()` / `end_drag()` / `line_slots()` / `place_line()` / `pick_up()` / `cancel_carry()`; `main.area_repair()` / `area_upgrade()` / `has_near()` / `pay_near()`.
- **Tests (18 new):** line geometry (walls, squares along the longer way, the 12 limit, objects not making lines), a line stopping when the wood runs out, chests counting as yours for the hammer, area repair paid from a chest, area upgrade while the scrap lasts, picking up a chest and putting it down elsewhere with its contents, a wall holding a floor refusing to move, and a carried piece going back when you leave build mode.

**Try:** drag out a ring of foundations, then a ring of walls on top. When the night has battered them, stand in the middle with the hammer and press R.
**Next:** v1.8, doors, switches and wiring: gates that close by themselves at night, a lockable metal gate, and cables carrying power from the generator.

## v1.6.0 (2026-11-26): More pieces
Eight new pieces at the end of the build list (scroll the mouse wheel in build mode). All take material tiers unless said otherwise.
- **Half wall** (2 wood, 2 nails): 1.2 m high, under your eyes (1.65 m), so you can shoot over it. **Low wall** (1 wood, 2 nails): 0.7 m. Neither holds anything up.
- **Gun slit wall** (3 wood, 3 nails): a full wall with a 1 m wide, 16 cm slot at 1.4 m to shoot through. It holds up floors like a wall.
- **Pillar** (2 wood, 2 nails): a new kind of slot on the **corners** of the grid. Pillars stand on the sand or on any of the four foundations around their corner, stack, and **hold up floors** (one pillar under any corner of a square is enough, at the same 10-point support cost as a wall). Now you can put a floor in the open without walls.
- **Floor with trapdoor** (4 wood, 4 nails): a floor (it holds up floors next to it) with a 1 m hatch on one side. **E** opens and closes it; the state is saved. Put a ladder under it to climb up.
- **Triangle foundation** (2 wood, 2 nails) and **triangle roof** (2 scrap, 1 nail): half a square, cut corner to corner, turned with R. They have triangle colliders and work like a foundation and a roof (walls stand on a triangle foundation, a triangle roof holds up floors next to it), for rounder towers.
- **Metal door** (8 scrap, 4 nails): a doorway with a metal leaf, **1400 hit points**, no tiers. E opens and closes it ("[E] Open door"). It holds up floors like a wall.
- The pit ladder from v1.2 works against walls too, so it is the ladder for upper floors.
- **Code:** a new slot kind `post` (grid corners) with `post_cells()`/`post_key()`, `FOUNDATIONS`, `TRIS` with `prism_points()`/`prism_mesh()`, the trapdoor hatch (`_add_hatch`, "hatch:" interact ids), and pieces flagged `"gate"` get a gate.
- **Tests (36 new):** every new piece in the build list, the heights of the half and low walls, half walls not holding floors and having tiers, the gun slit, a pillar snapping to the nearest corner, pillars on sand holding a floor at 90%, stacking, saving, one pillar being enough and the floor falling with both gone, the trapdoor (upstairs, holding a neighbour, the hole, the prompt, opening, saved open), the triangle foundation's height and collider, a wall on it and a triangle roof above, the build-mode ghost, and the metal door (hp, no tiers, prompt, opening, holding a floor). New screenshot view `47_pieces`.

**Try:** build a lookout: four pillars, a floor on top with a trapdoor and a ladder under it, and half walls round the edge to shoot over.
**Next:** v1.7, faster building: drag to lay a line of walls or foundations, repair or upgrade an area at once, and pick a piece up to put it down elsewhere.

## v1.5.0 (2026-11-26): Structural stability
- **Support:** every piece now has a support value counted from the ground. Ground-level pieces have **100%**. Resting on what is below (a floor on walls, a wall on a wall, a stair on a floor) costs **10 points**, a floor hanging off the floor next to it **25**, and anything standing on a floor 5. Heavier tiers cost more: scrap metal ×1.15, stone ×1.4, concrete ×1.3 (reinforced). Below **20%** a piece can't stand.
  - With wooden floors: 90% on the walls, then 65%, 40%, and a fourth square out (15%) is refused with "Too far from support (15%): build closer to walls".
  - Build mode shows "Support here: 65%" for an upstairs piece, and the hammer prompt shows the support of built ones.
  - The hammer refuses an upgrade that would bring something down ("Too heavy: a stone floor would bring itself down") and takes nothing for it.
  - When a wall breaks, or a piece is demolished or undone in build mode, everything left below 20% collapses, then whatever that held, and so on. Undoing a piece in build mode now brings down what it held too (before, it could leave floors in the air).
- **Physics debris:** collapsing and broken pieces throw **rigid chunks** that tumble, bounce, settle on the sand and shrink away after about 4 seconds. They are on their own physics layer (you and mutants walk through them), use continuous collision so they never fall through the ground, and at most 72 are around at once.
- **Code:** `building.compute_support()`, `support_for()`, `support_loss()`, `upgrade_problem()` and a rewritten `collapse_unsupported()`. Support is kept up to date in `building.support` (worked out once after loading a save).
- **Tests (17 new):** the 90/90/65/40% chain, the too-far floor refused, a wall on a wall, the hammer showing support, stone floors weighing more (86/51/22%), the refused upgrade that takes nothing, an upgrade that is fine, all four floors falling when the walls go, rigid debris (and its limit), and the debris settled on the sand a few seconds later. New screenshot view `46_support`.

**Try:** build a balcony off your walls and see how far it reaches, then try it in stone.
**Next:** v1.6, more pieces: half and low walls, a gun slit wall, a corner pillar, a ladder piece for walls, a trapdoor, triangle foundations and roofs, and a metal door.

## v1.4.0 (2026-11-26): The water well (M7 done)
- **Water well** (8 stone, 4 wood, 2 scrap, last in the build list): dig a shaft at least **3.5 m** deep (a single 1 m square is enough; the last metre is stone, so it takes the pickaxe), then build the well on the 2 m square whose middle is a corner of the shaft. It stands at the original ground level with a stone ring, posts, a crank bar and a bucket, and fills the sand round the shaft inside its footprint. It fills **a bottle of water every 75 s, up to 6**. **E** takes them ("Well: 3 bottles, the next in 40 s"). Water in a well is saved. Digging next to it doesn't drop it into its own shaft.
- **Reaching down holes:** looking steeply down, the shovel and pickaxe reach further (about 4 m out, up to 6.4 m along the line of sight), so you can dig a shaft from its edge.
- **Stamina for hard work:** a dig costs 7 (a fill 3.5), a pickaxe hit 9, building a piece 6, a hammer repair or upgrade 5. With too little: "Too tired: catch your breath".
- That finishes **M7, digging and terrain**.
- **Tests (17 new):** a well needing a deep shaft (the reason says 3.5 m and the pickaxe), the shaft depth, reaching its bottom looking down, the well standing at ground level, the footprint filled round the shaft, the filling prompt, a bottle every 75 s, taking it, the 6-bottle limit, the well staying put when you dig next to it, water saved, and stamina for digging. New screenshot view `45_well`.

**Try:** dig a shaft with the pickaxe next to your base, build a well over it, and stop hauling water bottles in from the wrecks.
**Next:** M8, v1.5 structural stability: a support value for each piece counted from the ground, overhangs and tall towers that collapse, and debris.

## v1.3.0 (2026-11-26): Mining
- **Layers:** sand down to 1.5 m, then **clay** down to 2.75 m (reddish brown in the hole), then solid **stone** (grey) down to bedrock at 4 m. A dig gives a bag of whatever it brings up, and the prompt says what the next dig brings ("Clay, dug 1.75 m deep"). The shovel can't cut stone ("Solid stone: you need a pickaxe to dig deeper").
- **Pickaxe** (workbench: 4 scrap, 2 wood): digs through every layer, and left click on a **rock** out in the desert chips a **stone** off it each hit. Rocks take 1 to 12 hits depending on their size, then break apart and are gone for good (saved). Hitting is a little slower than digging.
- **Stone building tier** between scrap metal and concrete: **1000 hit points**, upgraded with the hammer for stone plus 1 clay as mortar (a wall: 5 stone, 1 clay), repaired with stone. Stone pieces are a warm grey-brown. **Older saves keep their concrete as concrete** (saves now record how many tiers there are).
- **Metal detector** (workbench: 6 scrap, 4 nails, 2 cloth) and **buried caches:** six caches are buried around the base (at least 8 m from the flag and 8 m apart) and one more most mornings, up to six hidden at a time. Hold the detector: it beeps faster the closer you are ("no signal", "a faint beep", "beep... beep...", "fast beeping", then "a steady tone. Dig right here, 1 m down!"). Dig that square 1 m down and the cache comes up in a bag: scrap, nails, 9mm rounds, sometimes shells, cement, fuel, food or a medkit. Saved; older saves get a fresh set.
- The pickaxe, metal detector, stone and clay are in the test box too (it fills from every item).
- **Tests (31 new):** the recipes and test box, sand then clay then stone, the shovel stopped by stone and the pickaxe not, the prompt, aiming at a rock, hits giving stone, a rock breaking, rocks saved and restored (and older saves having every rock), caches buried, the detector over a cache and far away, a cache coming up only 1 m down, found caches saved, older saves getting fresh caches, the stone tier upgrade and its cost, refunds, and older saves keeping scrap metal and concrete. New screenshot views `43_layers` and `44_detector`; `14_tiers` shows four walls.

**Try:** take the pickaxe and detector from the test box, break a few rocks, follow the beeps to a cache, then upgrade a wall to stone.
**Next:** v1.4, the water well: dig down at the base to strike water for a slow, endless supply, and digging and building cost stamina.

## v1.2.0 (2026-11-26): Trenches and pits
- **Mutants and pits:** mutants walk or fall into holes, and climb a steep sand wall slowly: walkers and spitters at 0.35 m/s, runners at 0.55, brutes at 0.22. A wall **2 m high or more holds them** (they can't climb it, and pushing no longer slides them up the sand). In the soak test (wave 8, walls only, you away all night), a 2.25 m deep trench ring 14 m out caught **15 of 23** mutants and only 1 wall was lost; without the trench, 20 of 24 walls were torn down.
- **Spiked pit** (4 wood, 6 nails, build mode): goes in a hole at least 1 m deep ("Dig a pit at least 1 m deep here first"). Its stakes bite a mutant in it for 30 every second and slow it to 30% (climbing out too), and they wear out.
- **Ladder** (4 wood, 4 nails): stands in a pit (steep ground is fine). Walk into it and hold W to climb, S to climb down. Mutants can't use it. You can also dig yourself a ramp out with the shovel (steps of 25 to 50 cm).
- **Sandbags** are now made of **6 sand and 2 cloth** (were 4 cloth and 2 cement). They still need their blueprint.
- **Foundations level the ground:** building a foundation fills the sand under it up to its bottom, so a foundation over a dip or a dug hole has no gap under it.
- Soak test option `trench=1`, and it reports how many mutants are down in a hole.
- **Tests (15 new):** a walker climbs out of a 1.5 m pit and one stays in a 2.25 m pit, the sandbag cost, the spiked pit needing a hole and then biting (once a second) and wearing out, the ladder standing in a pit and where you can climb it, you climbing a ladder out of a 2.25 m pit, and a foundation filling a hole under it but nothing outside.

**Try:** dig a trench 2.25 m deep (9 digs per square) round your walls, leave a way in over a ladder or a dug ramp for yourself, and put a spiked pit where they fall in.
**Next:** v1.3, mining: a pickaxe, breakable rocks for stone, clay and stone layers, a stone building tier and buried caches.

## v1.1.0 (2026-11-26): Deformable ground and the shovel
- **Diggable ground around the base.** The ground within 48 m of the flag (a 96 × 96 m square, covering even the biggest build zone) is now a finer grid of **1 m squares** in 36 chunks of 16 × 16. Only the chunks around a change are rebuilt (mesh and collision). The rest of the map keeps the old 4 m grid. The two meet without gaps, and the existing test that checks the collision against the height sampler at 200 random points still passes.
- **Shovel** (workbench: 3 scrap, 2 wood; shop: $40). Hold it and left click to **dig** the square under the crosshair (a yellow square marks it, reach 4 m): it drops 25 cm and you get a bag of **sand** (1 kg). Right click **fills** a square with a bag of sand. A dig brings the square's highest corner down 25 cm and the other corners down to it, and a fill does the same upwards from the lowest corner. So a row of digs makes a level trench, and digging again flattens a tilted square before going deeper. The prompt shows how deep a square is dug, or how high it is piled.
- **Limits:** **bedrock 4 m** below the original ground ("Bedrock: you can't dig any deeper here", and no sand from it), sand piles up to **2 m** high, and you can't dig more than 48 m from the flag. Nobody can dig under the flag, the shop terminal, the training dummy, the test box, rocks or wrecks.
- **Undermining:** dig the sand out from under a wall, doorway, floor, stairs or other piece on the sand (more than 0.6 m below its base, under its middle or under half the points it stands on) and it **falls** with debris and a crash, and anything it held up comes down too. Foundations take 1 m. Walls on a foundation stand as long as the foundation does. Chests, traps, turrets and other objects on the sand **settle** into the hole instead. Dropped bags settle too, and filling under you (or a mutant) lifts you out of the sand.
- **Saved** as height changes (only the corners that moved, in mm). **Older saves load flat ground**, so nothing changes for them.
- Pause menu → Controls and the README list the shovel. New first-time hint for the shovel.
- Fix: the end-of-wave summary could crash if a wave's stats were incomplete (only seen in the screenshot tool).
- **Code:** `terrain.gd` has the fine grid (`dig`, `fill`, `dig_blocked`, `cell_depth`, `at_bedrock`, `save_data`/`load_data`, signal `ground_changed`). `building.settle(area)` and `undermined(rec)` decide what falls. `main.dig_at(point, filling)` is the shovel's logic and `_on_ground_changed` handles what stands on the ground. `base_zone.rebuild()` stands the stakes on new ground.
- **Tests (40 new):** the items, recipe, shop and test box, the grid matching its vertices, where you can and can't dig, dig and fill amounts and sand, bedrock, a level trench, the piling limit, the prompt and marker, saving and loading, older saves loading flat, a wall falling (and one further away not), a chest settling, a foundation with a wall and an upper floor coming down together, a bag settling, the collision matching the dug ground, falling into a 1 m pit and standing on its floor, and filling lifting you out. New screenshot views `41_digging` and `42_trench`. The soak test is unchanged: all 18 wave mutants killed, 2.3 ms per frame.

**Try:** make a shovel at the workbench (or take one from the green test box), dig a trench in front of your walls and watch your sand pile up. Dig too close to a wall and it comes down.
**Next:** v1.2, trenches and pits: mutants can't climb steep pit walls, a spiked pit trap, sandbags from sand and cloth, and foundations that level the ground under them.

## v1.0.5 (2026-11-26): Test box and a new roadmap
- **Test box (temporary):** a green crate with a white cross right next to where you spawn. **E** opens it like a chest: it holds a full stack of every item in the game (weapons, ammo, materials, fuel, traps, medkits...), refills each time you open it, and tops your cash up to $2000 so you can try the shop, blueprints and base upgrades. It is not saved and doesn't count as a building. Turn it off with `TEST_BOX = false` in `scripts/main.gd`.
- **Roadmap:** new milestones after v1.0, following the owner's focus (simple visuals; game logic, physics, building and **digging**): **M7 Digging and terrain** (deformable ground with a shovel, trenches and pits, mining, a water well), **M8 Building capabilities** (structural stability, more pieces, faster building, doors and wiring) and **M9 Game logic, AI and physics** (mutant navigation, a physics pass, survival depth, a crafting chain, events).
- **Tests:** the test box contents, the cash top-up, and it not closing by itself.

**Next:** v1.1, deformable ground and the shovel.

## v1.0.4 (2026-11-26): Tidy-up
- Turrets, traps, fences, fire pits and generators no longer scan every building piece many times a second; the building keeps a list per piece type (`building.keys_of()`). It makes no difference with a small base (the soak test runs the same night, same result, about 2.4 ms per frame), but a big late-game base won't slow them down.

## v1.0.3 (2026-11-26): No skipping the night
- **Fix: you could dodge every night by staying out in the desert.** Wave mutants that reached an empty base just milled about until dawn. Now, with nobody within smelling range, each one picks the **nearest building piece** at the base (not traps and not upstairs pieces) and tears it down, then the next. Leave your base alone at night and you come back to rubble, unless your turrets, traps and fences deal with them.
- Soak test options: `away=1` (the player spends the night 190 m out in the desert) and `walls=1` (only a ring of walls, no traps or turrets). With both, wave 4 now flattens the 24 walls before dawn. With the full fortress and you away, the turrets and traps still clear it.
- Note: this container has no Vulkan, so the Forward+ renderer can't be tried here (Godot falls back to OpenGL). The game only uses standard nodes and materials, so Forward+ should be fine, but tell me if anything looks wrong with `./play.sh` (Forward+) compared with `./play.sh --compat`.
- **Tests:** a wave mutant at an empty base heading for the nearest wall.

## v1.0.2 (2026-11-26): Controls page and the wave on the map
- **Pause menu → Controls:** every key on one page (the help line at the bottom of the screen fades after a few seconds). The pause menu also shows the game's difficulty.
- **Map during a wave:** red dots show tonight's mutants on their way (brutes as bigger dots), and a thin red ring shows your build zone (it grows with the zone upgrade).
- **Tests:** the controls page. New screenshot views `38_controls`, `39_settings` and `40_wave_map`.

## v1.0.1 (2026-11-26): Turrets on masts, and a soak test
- **Fix: turrets behind walls never fired.** Their gun sat at 1 m and walls are 2.4 m tall, so a turret inside your walls couldn't see anything outside them. Turrets now stand on a **3.4 m braced mast** and fire over walls at anything a few metres out (a mutant hugging the wall is still hidden from them; that is what wire, spikes and your own guns are for). They aim at the upper chest.
- **New `tools/soak_test.gd`:** builds a fortress (a ring of walls with a gate, wire, sandbags, mines, two loaded turrets, a generator, a floodlight, an electric fence and a fire pit), starts a big wave (night 8 by default) and plays the whole night. It prints the lineup, progress every 10 seconds, what is left at the end, and the time per frame. Run it with `godot --headless --path . -s tools/soak_test.gd --fixed-fps 60 -- frames=11000`.
  - Before the fix: 23 mutants, after a full night only 14 killed and 4 runners still clawing at the walls.
  - After: all 18 wave mutants killed before dawn, 1 piece lost, no script errors, about 2.3 ms per frame (headless, no rendering) with 20+ mutants.
- The screenshot tool no longer shows first-time hints in its pictures.

## v1.0.0 (2026-11-26): Version 1.0
The last parts of the v1.0 item (difficulty and hints came in v0.25):
- **Graphics quality** in Settings: **Low** (no sun shadows, 75% render scale, 450 m view distance), **Medium** (shadows to 90 m, no anti-aliasing, 650 m) or **High** (the old look: shadows to 160 m, 2× anti-aliasing, 900 m). If the game stutters on the laptop, try Medium or Low. It applies straight away and is remembered.
- **Performance:** wandering mutants far from you pause, turrets and traps only check a few times a second, and repeated props are MultiMeshes. Low quality is there for heavy nights with 30+ mutants on screen.
- **Standalone Linux build:** `./export.sh` makes `build/desert-fortress.x86_64`, one 70 MB file that runs without Godot or the source folder. The first time it downloads Godot's export templates (1.3 GB, one time) and keeps just the Linux ones. I tested it here: the exported file starts and shows the title screen. `export_presets.cfg` holds the "Linux" preset (tests, tools and screenshots are left out).
- **README** rewritten as a short manual: how to play your first day, survival, building, nights and the four mutant types, weapons, defences, cash and the shop, difficulty, every control, settings and performance, and where saves live.
- **Tests:** low and high quality settings. All tests and the flow test pass.

This completes the roadmap through **M6** and **v1.0**. Thanks for playing!

**Try:** `./export.sh`, then run `build/desert-fortress.x86_64` on its own. Start a new game on Normal and see how many nights you last.
**Next:** the owner picks from "After 1.0" (sandstorms, a boss every 10 nights, a buggy, outposts, animated characters, a soundtrack, Windows and Steam Deck builds), or adds player feedback.

## v0.25.0 (2026-11-26): Difficulty and first-time hints (v1.0, part 1)
The v1.0 item is big, so it comes in parts. It stays unticked on the roadmap until all of it is done.
- **Difficulty:** New game now asks for **Easy, Normal or Hard**. It stays with that game (it is in the save):
  - Easy: waves 30% smaller, mutants with 20% less health that do 40% less damage, 25% more pay, hunger and thirst 30% slower.
  - Hard: waves 40% bigger, mutants with 25% more health that do 40% more damage, 10% less pay, hunger and thirst 30% faster.
  - Older saves play on Normal.
- **First-time hints:** a "TIP" box under the title the first time something happens: a new game, picking up loot, build mode, holding the hammer, holding a gun, the dusk siren, the first mutant that spots you, the first pay, and getting hungry or hurt. Each shows once, ever (they queue up if several come at once). **Settings → First-time hints** turns them off; turning them back on shows them all again.
- Fix: a wave's stats could be missing a key and stop the kill count (seen only in the screenshot tool).
- The screenshot tool now puts a `.gdignore` in `screenshots/`, so Godot no longer imports every PNG.
- **Tests:** the default difficulty, wave sizes per difficulty, reduced damage on easy, the difficulty saved, a hint showing once, hints queuing, and no hints when turned off. New screenshot view `37_hint`.

**Try:** start a new game on Hard if the first nights feel too easy.
**Next:** the rest of v1.0: a graphics quality setting (performance), a standalone Linux export, and the README as a short manual.

## v0.24.0 (2026-11-26): Base upgrades and the radio
The shop terminal has a third page, **Base upgrades**:
- **Bigger build zone:** 26 m to **34 m** ($200), then **42 m** ($400). The ring of stakes and the dashed line in build mode move out with it.
- **More chest storage:** every chest (and every new one) grows from 20 to **30 slots** ($150), then **40** ($300). Nothing is ever lost; chests only grow.
- **Workbench tiers:** a new game's workbench is tier 1 (tools, bandages, barricades, the pistol and its rounds). **Tier 2** ($200) adds the shotgun and shells, **tier 3** ($400) the hunting rifle, 7.62 rounds and the new **medkit** (2 bandages, 2 cloth, 1 water: heals 70, use with F). Locked recipes stay on the list as "needs workbench tier N".
- **Radio** ($120): a field radio appears on top of the terminal. At dusk, instead of just the siren's warning, it tells you the coming wave's lineup ("Radio: wave 5 tonight, 6 walkers, 3 runners, 1 spitter, 2 brutes."), and the nightfall banner lists it again. Without a radio you only learn how many are coming.
- The workbench list is now three columns (the cost shows in brackets with what you have; hover a recipe for its description), and the chest grid is flatter so a 40-slot chest fits at 1280×720.
- **Saved:** every upgrade. **Older saves keep every recipe** (their workbench counts as tier 3); other upgrades start un-bought.
- **Code:** `Shop.UPGRADES` with `next_level`, `upgrade_value` and `buy_upgrade`. `main.apply_upgrades()` sets `building.zone_radius`, the chest size (`building.set_chest_slots`, `Inventory.resize`) and `inventory_ui.bench_tier`. `Waves.preview_next()` lets the radio tell the lineup before it is rolled.
- **Tests:** a tier 1 bench refusing the shotgun, buying tier 2 and making one, the rifle still needing tier 3, the zone growing twice (29 m now inside, the stakes moved), the limit, chests growing to 30, upgrades and a full big chest saved, the chest screen showing 30 slots, the radio on the terminal and its dusk lineup matching the real wave, medkits healing 70, and older saves keeping every recipe. New screenshot views `35_upgrades` and `36_chest`; `16_bench` shows the locked recipes.

**Try:** save up after a few nights for the radio, so you know when the brutes are coming, then upgrade the workbench for the rifle.
**Next:** v1.0, balance and polish: difficulty settings, first-time hints, a performance pass, a standalone Linux export and the README as a short manual.

## v0.23.0 (2026-11-26): Drone deliveries and blueprints
- **Drone landing pad** (4 wood, 2 scrap, 4 nails): a concrete pad with a painted H, in build mode after the turret.
- **Drone orders:** the shop terminal has a second page, **Drone orders**, with bigger loads at better prices: 40 wood $60, 40 scrap $90, 100 nails $45, 10 cement $80, 120 9mm rounds $80, 6 fuel cans $60, plus **blueprints**. Orders need a landing pad. A white quadcopter with an orange stripe flies in from the edge of the map, comes down over the pad, lowers the parcel and flies off, about 25 seconds in all, buzzing as it goes. The parcel is a bag on the pad with everything ordered since the last flight; orders placed while it is in the air go on the next one.
- **Blueprints unlock builds.** The **auto-turret** ($150) and the **electric fence** ($120) now need a blueprint, and there is a new **sandbag wall** ($60): a waist-high edge piece of stacked sandbags (4 cloth, 2 cement) with **900 hit points** that you can shoot over. A blueprint is learned the moment its parcel lands. Build mode says "Locked: order its blueprint by drone…" until then, and the shop shows blueprints you own or have ordered as "Owned".
- **Older saves keep every build** (all blueprints count as learned), so nothing you already use gets locked.
- **Saved:** learned blueprints, and orders not yet delivered (a parcel in the air when you save is flown again after loading).
- Pieces can now have their own hit points (`"hp"` in the piece table), used by the sandbags.
- **Code:** new `drone.gd` (order queue, flight, delivery). `shop.gd` has the drone catalogue, blueprints and `is_unlocked()`. `shop_ui.gd` has two pages.
- **Tests:** turret locked and walls not, the locked reason in build mode, no orders without a pad, building a pad, the drone page opening up, ordering a blueprint only once, a whole flight (take-off with two orders, arrival, the blueprint learned, the wood in a bag on the pad), turrets then buildable, undelivered orders saved and delivered after loading, older saves keeping every build, and sandbag hit points. New screenshot views `33_drone` and `34_drone_shop`.

**Try:** build a landing pad, order the sandbag-wall blueprint and a load of wood, and watch the drone come in. Save up for the turret blueprint.
**Next:** v0.24, base upgrades: a bigger build zone, more storage, workbench tiers, and a radio that warns which mutant types are coming.

## v0.22.0 (2026-11-26): Cash and the shop terminal
- **Cash:** you start with $50 and are paid at the end of every night. Your cash is shown in the top right, next to the day and time.
  - **Kills:** a bounty on every mutant of the wave you kill: walker $10, runner $12, spitter $15, brute $40.
  - **The night:** $25 plus $10 per wave number, for surviving it.
  - **Base condition:** up to $60, for the share of your building pieces still standing at dawn (only if you have built something).
  - **Clearing the whole wave** before dawn pays a quarter more on top.
  - The end-of-wave summary now ends with "Cash earned: $…".
- **Shop terminal:** a green screen on a post just west of the flag. **E** opens the shop, with what you can't afford greyed out:
  - Materials: 10 wood $20, 10 scrap $30, 25 nails $15, 5 cloth $10, 3 cement $30, 2 fuel cans $25
  - Supplies: 3 canned food $15, 3 water $15, 3 bandages $20
  - Weapons: machete $50, pistol $120, shotgun $260, hunting rifle $380
  - Ammo: 24 9mm $20, 12 shells $25, 10 7.62 $30
  - Traps: spike barricade $25, and parts kits for a spike strip ($20), barbed wire ($20) and a landmine ($30)
  If your pockets are full, the rest drops in a bag at your feet. E, Tab or Esc closes it.
- **Saved:** your cash. Older saves start with $50 plus $40 for each night already survived.
- **Code:** new `shop.gd` (the terminal, cash and catalogue) and `shop_ui.gd`. `Waves.cash_for()` works out the pay and `BOUNTY` holds the kill prices.
- **Tests:** the terminal prompt, opening and closing the shop, greyed-out buttons, buying, not affording a rifle, the pay formula (kills, night, base condition, clear bonus, no base), a real wave paying out with the right bounty, the summary and HUD showing cash, cash saved, and older saves. New screenshot views `31_terminal` and `32_shop`.

**Try:** survive the first two nights, then spend the cash on a shotgun or a stack of nails for more walls.
**Next:** v0.23, drone delivery to a landing pad, and blueprints that unlock new builds.

## v0.21.0 (2026-11-26): Auto-turret
- **Auto-turret** (18 scrap, 10 nails, 2 wood), the last piece in the build list: a gun on a swivel atop a post, with an ammo box at its foot. It needs no power, only **9mm rounds**: look at it and press **E** to load everything you carry (it holds 240). The prompt shows how many rounds are left and says EMPTY when it runs dry.
- It swings toward the **nearest mutant it can see within 22 m** (walls, wrecks and dunes block its view) and fires short bursts: a round every 0.22 s, 16 damage each, slightly spread. Walkers drop in about 7 rounds, brutes need a whole belt, so turrets are best behind walls and wire. With no target it slowly looks around.
- **Range circle:** while placing a turret in build mode, a dashed orange circle on the sand shows its 22 m reach.
- Turret fire is loud: it draws mutants within 35 m, like your own guns.
- Mutants can claw turrets down like any piece (250 hp); the hammer repairs them.
- **Saved:** rounds in each turret.
- **Code:** new `turrets.gd` (targeting with line of sight, turning, firing). The turret's head is built in `building.gd`.
- **Tests:** the range circle showing at the right size and hiding when you leave build mode, the prompt, loading rounds with E, rounds saved, a real fight over two seconds (the turret shoots a walker 12 m away and uses rounds, and leaves one 30 m away alone), and an empty turret holding fire. New screenshot view `30_turret`.

**Try:** put two turrets behind your walls covering the side the waves come from, load them up, and watch the first night from the roof.
**Next:** v0.22, cash for each wave (kills, waves survived, base condition) and a shop terminal at the base.

## v0.20.0 (2026-11-26): Fire, power and light
Four new build pieces (mouse wheel in build mode, after the landmine):
- **Fire pit** (4 wood): a ring of stones with crossed logs. **E** puts in a piece of wood: each one burns for a minute (up to 5 minutes' worth). It lights up the area with a warm flickering glow, and mutants walking through it burn (12 damage a second). The prompt shows how long it has left.
- **Fuel generator** (12 scrap, 8 nails): **E** pours in a **fuel can** (it holds 10). It starts by itself at nightfall or when a wave begins, and stops at dawn, so you don't waste fuel by day. One can runs it for 90 seconds, about three cans a night. It putters while running and has a small light on the front. The prompt shows the cans left and whether it is running.
- **Electric fence** (5 scrap, 6 nails): posts and five wires along a grid edge, like a wall. It blocks mutants, and with power the wires glow blue and **shock** anything touching them: 20 damage every half second and a near standstill while it is jolted, with sparks and a crackle. Without power it is just a flimsy fence that mutants will tear down.
- **Floodlight** (4 scrap, 2 wood, 2 nails): a 3 m pole with two lamps throwing a wide cone of light 30 m forward (R turns it). Lights up when powered.
- **Power:** a running generator powers every floodlight and electric fence within **18 m**.
- **Fuel cans:** a new item, found in some car trunks (0–2) and every supply crate (1–4).
- **Saved:** fuel in each generator and the burn time left in each fire pit.
- **Code:** new `power.gd` (generator fuel and running state, what is in range, fire pits burning down, the generator hum). Electric fence shocks and fire damage live in `traps.gd` with the other traps. `building.set_powered()` swaps the lamp and wire materials.
- **Tests:** each piece can be built, filling the tank, the generator prompt, staying off by day, running at night, a floodlight in range lighting up and one 25 m away staying dark, the fence going live, a can lasting 90 s, the fence shocking a walker, power going off when the fuel runs out (and a dead fence not shocking), lighting the fire with wood, fire burning a mutant, fuel and fire saved, and the fire burning out. New screenshot view `29_power`.

**Try:** collect fuel cans from car trunks, put a generator in the middle of your base with floodlights facing out, and run an electric fence along the side the waves come from.
**Next:** v0.21, the auto-turret fed from an ammo box, with its range circle shown while placing.

## v0.19.0 (2026-11-26): Traps
Three new pieces in build mode (mouse wheel past the spike barricade). They don't block anyone, so you and the mutants walk straight over them, and they are set for mutant weight, so they never hurt you (except a mine's blast).
- **Spike strip** (2 wood, 8 nails): a board bristling with nails. A mutant stepping on it takes **18 damage**, at most once every 0.8 s, and stumbles (slowed for a moment). Each bite wears the strip down (12 of its 250 hit points), so it lasts about 20 bites.
- **Barbed wire** (3 scrap, 4 nails): a low fence of wire on two posts. A mutant caught in it moves at **35% speed** and is cut for 4 damage a second. The wire wears 3 hit points a second per mutant in it. Great in front of walls, to hold them where your guns can reach them.
- **Landmine** (4 scrap, 4 nails, 1 cloth): buried, with a little flag so you know where it is. When a mutant steps on it, it beeps and goes off a quarter of a second later: **220 damage at the centre, less out to 5 m** (a walker on it is blown apart, a brute survives at around 260 health), 120 damage to building pieces within 3 m, and up to 70 to you if you are within 5 m. Fireball, flash, smoke and a deep boom that brings mutants within 60 m running.
- Traps have hit points like any piece: the hammer shows them, repairs them and demolishes them (half refund).
- Dust from collapsing pieces and mine smoke are now little low-poly puffs instead of flat squares.
- **Code:** new `traps.gd` (checks every trap against every mutant ten times a second, mine fuses and explosions). Traps sit on their own physics layer (5), which only the hammer looks at. Mutants have `slow()`.
- **Tests:** each trap can be built, traps don't block, the strip biting and wearing and not biting every tick, wire slowing and cutting, the mine's fuse, blast, walker on it killed, a walker 3.5 m away hurt, a brute surviving, you being safe at a distance and hurt close up, and a strip wearing out. New screenshot view `28_traps`.

**Try:** lay barbed wire 4–6 m in front of your weakest wall, spike strips in the gaps and a few mines further out where the waves come in.
**Next:** v0.20, a fire pit, an electric fence with a fuel generator, and floodlights.

## v0.18.0 (2026-11-26): Shotgun, rifle and headshots
- **Shotgun:** pump-action, 6 shells. Each blast fires 9 pellets (13 damage each) in a wide cone, so up close it nearly kills a walker in one blast, but past 20 m only a pellet or two land. Slow (one blast every 0.85 s), heavy kick, a deep boom, and it can be heard 60 m away. 2.6 s reload.
- **Hunting rifle:** bolt action, 5 rounds, 90 damage, reaches 220 m. **Aiming looks through the scope:** the screen goes black around a round sight picture with cross hairs and a red dot, zoomed in about 3×. At the hip it is inaccurate. One shot every 1.1 s, 2.4 s reload, and loud (75 m).
- **Headshots:** a gun hit on a mutant's head does **double damage** and flashes a bigger, red X. A rifle headshot kills a walker or a runner outright; a brute takes three.
- **Weapon switching:** select a gun on the hotbar (number keys or the mouse wheel) and it is brought up from below in 0.35 s; it can't fire until it is up. The left hand moves out to the fore-end on the long guns.
- **Ammo types:** **shotgun shells** and **7.62 rounds**, alongside the 9mm. Shells turn up in some car trunks; supply crates have shells and sometimes 7.62, a shotgun or a rifle. Workbench: shotgun (14 scrap, 4 wood, 8 nails), 6 shells (2 scrap, 4 nails, 1 cloth), rifle (16 scrap, 5 wood, 10 nails, 2 cloth), 5 rounds of 7.62 (3 scrap, 4 nails).
- **Workbench list in two columns** so all 10 recipes fit, with the amount you have of each material in brackets.
- Fix: a shot now lands where you aimed before the recoil kicks the view up (the pistol was slightly affected).
- Pellets hitting the same target add up into one hit and one damage number.
- **Code:** `Guns.GUNS` now holds pellets, hip and aimed positions, sound pitch and the scope flag. Mutants have `is_headshot(point)`. The HUD draws the scope overlay.
- **Tests:** crafting the new guns and ammo, all recipes on the bench, the switching delay, scope overlay and zoom, a rifle headshot killing a walker for double damage, pellets adding up to one hit, the shotgun close up versus far away, and a shell per blast. New screenshot views `26_shotgun` and `27_rifle_scope`; `16_bench` shows the new list.

**Try:** make a rifle and pick off mutants as they cross the dunes at night. Aim for the heads. Keep the shotgun for anything that gets through the gate.
**Next:** v0.19, traps: spike strip, barbed wire (slows) and landmine.

## v0.17.0 (2026-11-26): The pistol
- **Pistol:** a 12-round 9mm, held in both hands. **Left click** fires one shot (up to 5 a second), 34 damage, so three hits drop a walker and two a runner. Bullets travel 90 m.
- **Aim down the sights:** hold **right click**. The gun comes up to the centre with the sights on the crosshair, the view zooms in a little, and the spread shrinks from about 1.8° at the hip to 0.25°. The crosshair fades while aiming.
- **Recoil:** every shot kicks the view up (less when aimed) and nudges it to the side, and the gun jumps back in your hands. **Muzzle flash** with a short burst of light (you'll see it light up your arms at night).
- **Reload:** **R** (when not in build mode). 1.5 seconds, with the gun tipping down while you swap the magazine. Rounds come from your pockets, and an empty pistol clicks and starts a reload by itself. The HUD shows "Pistol 9 / 24" (loaded / spare) and says when to reload or when you are out.
- **Ammo is an item:** **9mm rounds** (stack of 60, almost weightless). Found in some car trunks and in every supply crate (8–20); supply crates sometimes hold a pistol too. At the workbench: **pistol** (10 scrap, 2 wood, 6 nails) and **8 rounds** (2 scrap, 3 nails).
- **Loud:** a gunshot brings every wandering mutant within 45 m running. Melee is still the quiet option.
- **Sounds:** a generated crack with a low thump and a faint echo, an empty click, and the clacks of a reload.
- Bullets kick up dust where they hit the ground or walls, and show the usual hit marker and damage numbers on targets.
- Shorter controls line so it fits at 1280×720.
- **Saved:** rounds in the magazine. Older saves load with an empty pistol (if you have one).
- **Code:** new `guns.gd` (a `GUNS` table ready for the shotgun and rifle), `Mutants.alert()` for noise, two new items and recipes.
- **Tests:** crafting a pistol and rounds, empty click and auto-reload, reloading from your pockets, no reload without ammo, a full magazine, the HUD ammo text, aiming zoom, three aimed hits on the dummy at 10 m, a round per shot, view kick, rate limit, a gunshot alerting a walker 27 m away, the magazine saved, and the gun hiding and the view zooming back out when you put it away. New screenshot views `24_pistol` and `25_pistol_ads`.

**Try:** make a pistol at the workbench (or find one in a supply crate) and some rounds, then pick off the walkers coming across the sand at night. Right click to aim.
**Next:** v0.18, the shotgun and the rifle, weapon switching, ammo types and a headshot bonus.
**Note:** the workbench list is now full at 1280×720; the next recipes need a second column or a scroll list.

## v0.16.0 (2026-11-26): Runner, Brute and Spitter
- **Runner:** lean, reddish, with claws and bared teeth, bent almost double. 45 health (two machete hits), but it runs at 6.4 m/s, faster than you walk, so only sprinting gets you away. Small, quick swipes (7 damage). Weak against walls.
- **Brute:** a big grey-purple hulk with huge fists. 420 health (11 machete hits) and barely flinches. Slow (2.5 m/s), with a long reach and a slow, heavy swing (30 damage). It **wrecks walls**: 95 per hit, so a wooden wall lasts about three swings. Kill brutes before they reach your walls, or upgrade.
- **Spitter:** yellowish, with glowing green sacs on its back and throat. 70 health. It keeps its distance (backs off inside 9 m, holds around 14 m) and **lobs globs of acid** in an arc every 3 seconds when it has a clear line to you: 14 damage on a hit, and 25 to any building piece it hits instead. Hide behind walls, then rush it.
- **Mixed waves:** night 1 is all walkers. Runners join on night 2, spitters on night 3 and brutes on night 4, each guaranteed to show up on its first night. Their share grows every night (by night 12 more than half the wave is runners, spitters and brutes). The wave banner says what is coming: "Wave 4 is coming: 6 walkers, 3 runners, 1 brute."
- Each type has its own voice pitch (shrill runners, deep brutes). The death screen names what got you.
- Day wanderers are still just walkers.
- **Saved:** each mutant's type (already part of v0.13 saves) and the order of the rest of the wave. v0.14 saves with a wave half-done fill up with walkers.
- **Code:** stats per type in `Mutant.TYPES` (size, skin, knockback, voice, ranged attack), new `spit.gd` (acid glob with a ray-checked arc), `Waves.wave_mix()` and `mix_text()`.
- **Tests:** type stats against your walk and sprint speed, wave mixes per night, the acid arc landing on target, brutes flinching less and being bigger, types and the wave lineup saved, the death screen naming the brute, and two real fights over many frames: a spitter keeps its distance and hits you with acid, and a runner closes 20 m in under 2 seconds. New screenshot view `23_types`.

**Try:** survive to night 4 and meet your first brute. Watch out for spitters lobbing acid over your walls.
**Next:** v0.17, the pistol: aim down sights, recoil, muzzle flash, reload, ammo as an item, and sound.

## v0.15.0 (2026-11-26): Mutants break in
- **They smell you:** a wave mutant within 30 m of you knows where you are, walls or not, and heads straight for you. Further away it keeps marching on the base.
- **Breaking walls:** a mutant that walks into a building piece (wall, gate, window wall, barricade, chest...) stops and **claws at it**: 20 damage per swipe, about one every 2 seconds. A wooden wall (250 hp) holds one walker off for about 25 seconds, scrap metal for a minute, and concrete for over two minutes. More mutants on the same wall break it faster.
- **No clawing through walls:** a mutant must have a clear line to you to hurt you. Standing right behind a wall is safe until the wall gives way.
- **Spike barricades bite back:** a mutant clawing at a spike barricade loses 8 health with every swipe, and the spike kills count for the wave.
- **Walls collapse:** at 0 hp a piece breaks apart in a shower of tumbling boards or chunks (in its material), a puff of dust and a generated crash. Anything upstairs that loses its last support falls down too: floors, walls, roofs and what stands on them. Two floors can no longer hold each other up in the air; there must be a chain of walls down to the ground. Demolishing with the hammer follows the same rule.
- **Warnings:** "Mutants are breaking in! (N side of the base)" when they start on your base (at most every 20 s), and a line on the right for each piece destroyed or collapsed. Pieces lost count in the end-of-wave summary.
- **Code:** mutants have a `BREAK` state; they look for a building piece with a short ray when they are blocked. `building.piece_key_of(node)`, `collapse_unsupported()` (a support chain search from the ground up), a `piece_collapsed` signal, and debris and crash effects in `building.gd`.
- **Tests:** an upper floor and its overhang collapsing with their wall, gates counting as part of their doorway, spikes hurting the attacker, mutants moving on when the piece is gone, and a real break-in over many frames: a wave mutant smells you behind a wall, claws at it while you stay unhurt, the wall breaks with dust and debris, then it gets to you. New screenshot view `22_breakin`.

**Try:** build a ring of walls around the flag with a doorway, upgrade the side facing the open desert, and wait for the night. Put spike barricades outside the weak spots.
**Next:** v0.16, more mutant types: the Runner (fast, weak), the Brute (slow, tanky, wrecks walls) and the Spitter (ranged acid). Waves mix types and scale up each night.

## v0.14.0 (2026-11-26): Night waves
- **Siren at dusk:** at 18:30 a generated air-raid siren wails and a banner tells you to get back to the base.
- **Waves at night:** when night falls (20:00), wave N begins: **4 mutants on the first night, 2 more each night after, up to 30**. They come in from the edge of the map in groups of 2 or 3, one group every 9 seconds, from random directions, and **march on the base** (2.2 m/s, so the first ones arrive about a minute and a half later). On the way, and once they reach the base, they go for you if they see or hear you. Wave mutants see half again as far as the day wanderers and don't give up as quickly.
- **Wave counter:** under the clock, "Wave 3: 5 left" counts the mutants still to come plus those still alive.
- **The night ends** when every mutant of the wave is dead (and all have arrived), or **at dawn**, when the sun finishes off the rest (they collapse and crumble; no kill counted).
- **End-of-wave summary:** a card for 10 seconds: "Wave 3 cleared!" or "Dawn: you survived night 3", with mutants killed, damage taken, building pieces lost and times you died.
- The day wanderers from v0.13 stay as they were; wave mutants don't count against them.
- **Saved:** the wave number and a wave in progress (how many are still to come, its stats, and which mutants belong to it). Older saves start counting from the current day. A save loaded in daytime never resumes a wave.
- **Code:** new `waves.gd` (siren, wave sizes, group spawning, summary). Mutants have a `hunter` flag (`make_hunter(goal)`) and `crumble()`.
- **Tests:** wave sizes, siren, a wave starting at night, every group arriving at the map edge, the HUD counter, clearing a wave and its summary (kills and damage), saving and loading mid-wave, dawn ending a wave, older saves, and a wave mutant really walking toward the flag. New screenshot views `20_wave` and `21_summary`.

**Try:** stay at the base after the siren and fight off the first wave with the machete. Then watch the summary at dawn. Waves get bigger every night, so start building walls.
**Next:** v0.15, mutants head for the base, attack walls in their way and break in, and walls collapse.

## v0.13.0 (2026-11-26): The first mutant, the Walker
- **Walkers** roam the desert: five of them, always at least 70 m from the flag, each shambling around its own patch of sand. Every morning the dead ones are replaced. Low-poly, hunched, sickly green with glowing orange eyes (easy to spot at night).
- **Spotting you:** a walker sees you up to 24 m away by day and 15 m at night, but only in front of it and only if nothing blocks the view (walls, wrecks, dunes). It also **hears** you within 9 m, more if you sprint and much less if you crouch. When it spots you it groans and comes after you at a fast shamble (3.3 m/s, slower than your walk), and it gives up when you get 38 m away.
- **Attacks:** close up it raises its arms and claws you for 12 health, about once every 2 seconds. A red flash on the screen edges and a red wedge around the crosshair show which side the hit came from. If a walker kills you the death screen says "A walker got you."
- **Fighting back:** walkers have 100 health, so the pipe takes 4 hits and the machete 3. Each hit shows the damage, makes it flash red and stagger back, and makes it chase you if it was just wandering. At 0 it **falls over** away from the blow, stops blocking you, and sinks into the sand after about 30 s.
- **Sounds:** generated groans, a snarl when it lunges, a grunt when hit and a moan when it falls, all in 3D.
- Walkers walk around things in their way by side-stepping when they get stuck. They don't break walls yet (that's v0.15).
- Far from you (over 140 m) wandering walkers pause, to keep things cheap.
- **Saved:** where each walker is, its home spot and its health, plus a kill count for later. Older saves keep the walkers a new world spawns.
- **Code:** `mutant.gd` (a `TYPES` table ready for the Runner, Brute and Spitter) and `mutants.gd` (spawning, morning top-up, shared sounds, saving). Mutants live on physics layer 4; the player and melee swings now see that layer.
- **Tests:** sight in front and not behind, hearing, crouching, range by day and night, a real chase over many frames ending in a claw, pipe damage on a walker, death, corpses ignoring hits, saving, older saves, morning top-up, death by walker. New screenshot views `18_walker` and `19_walker_night`.

**Try:** walk out 80 m or so from the base and look for a hunched figure. Crouch to sneak past, or take the machete and go for it. Try it at night when you can only see the eyes.
**Next:** v0.14, the wave system: a siren at dusk, mutants coming from the map edge at night, a wave counter and an end-of-wave summary.

## v0.12.0 (2026-11-26): Hands, melee weapons and a training dummy
- **First-person hands:** with the hammer, the rusty pipe or the machete selected you now see your hands holding it, with a gentle idle sway. Other items (food, water, materials) keep the hands hidden, so the view stays clear.
- **Rusty pipe:** new games start with one (hotbar slot 2), and older saves get one on load. **Left click** swings it: 25 damage, 12 stamina, one swing every 0.75 s, 2.4 m reach.
- **Machete:** made at the workbench (3 scrap, 1 cloth, 1 wood). 40 damage, 9 stamina, a swing every 0.55 s, 2.2 m reach.
- **Stamina:** each swing uses the same stamina as sprinting. If you don't have enough left, you can't swing.
- **Hit feedback:** a generated whoosh on every swing, a thud on a target and a clank on walls and rocks, an X flashing on the crosshair (orange on a target, grey on a wall), and the damage floating up from what you hit.
- **Training dummy:** a straw dummy on a post just left of the flag. It wobbles back and forth when hit and never breaks. Damage goes through a `take_hit(damage, point, dir)` method, which the v0.13 mutants will use too.
- The hammer plays the same swing when it repairs or upgrades.
- **Tests:** swing stamina cost, swing cooldown, too tired to swing, pipe and machete damage on the dummy, wobble, damage number, missing, hands hiding with other items, the hammer not swinging as a weapon, crafting a machete, older saves getting a pipe. New screenshot view `17_melee`.

**Try:** walk to the dummy left of the flag, press 2 and click away. Then make a machete at a workbench and feel the difference. Watch the stamina bar.
**Next:** v0.13, the first mutant (the Walker).

## v0.11.0 (2026-11-26): Base zone, storage chest and workbench
- **Base build zone:** everything must be built within **26 m of the flag**. A ring of stakes with red rags marks the edge, and in build mode a bright dashed line on the sand shows it too. Outside it the preview turns red: "Outside the base zone".
- **New build pieces** (key 9 for the chest, or the mouse wheel): **storage chest** (6 wood, 4 nails), **workbench** (6 wood, 3 scrap, 4 nails) and **spike barricade**. They stand in a square on the sand, a foundation or a floor (upper floors too), and R turns them. They have no material tiers, but the hammer repairs and demolishes them.
- **Storage chest:** E opens it next to your inventory. 20 slots. Click to move stacks, right click moves a whole stack across. Tab, E or walking away closes it. Contents are saved; if a chest is demolished or destroyed, what was in it drops in a bag.
- **Workbench:** E opens your inventory with three recipes: **hammer** (2 scrap, 2 wood), **bandage** (2 cloth, heals 30 with F) and **spike barricade** (4 wood, 4 nails). The barricade is an item you then build in build mode; demolishing it gives it back whole. It will hurt mutants once they arrive.
- **Code:** inventories can now have any size (`Inventory.new(20)`), with `move_to`, `transfer` and `contents`. New `base_zone.gd` (MultiMesh stakes and line). Building has a third slot kind, `obj`, so objects can share a square with a foundation or floor.
- **Saved:** chest contents (inside the building data). Older saves load unchanged.
- **Tests:** zone check, chest on a foundation, moving stacks in and out, closing when you walk off, chest saved, spilling on removal, workbench crafting with and without materials, bandage healing, spike refund, hammer prompt. New screenshot views `15_base` and `16_bench`.

**Try:** build a workbench near the flag, make a bandage from cloth, then build a chest and store your spare scrap. Walk to the zone edge in build mode to see the line.
**Next:** v0.12, first-person hands and melee weapons (rusty pipe, machete) with a training dummy.

## v0.10.0 (2026-11-26): Material tiers and the hammer
- **Three tiers** for every building piece, each with hit points: **wood** (250), **scrap metal** (600) and **concrete** (1500). Everything is built in wood, except roofs and ramps, which start as scrap metal. Each tier has its own look: planks, grey sheet metal with rusty posts, and grey concrete.
- **Hammer:** everyone has one (new games start with it in hotbar slot 1, and older saves get one). Select it and look at a piece within 3.5 m. The prompt shows its tier, hit points and what the hammer will do:
  - **Left click:** **repair** if damaged (one unit of the piece's material per started quarter of lost hit points), otherwise **upgrade** to the next tier. Wood to scrap metal costs scrap and 2 nails; scrap metal to concrete costs cement bags and 1 scrap.
  - **Right click twice:** **demolish**. You get back half of everything the piece cost, upgrades included. The first click only arms it, so you don't knock walls down by accident.
- **Build-mode right click** is now an **undo**: it gives everything back, but only for a piece built in the last minute that hasn't been upgraded or damaged. After that it tells you to use the hammer.
- **Cracks:** below 2/3 hit points a piece shows cracks, below 1/3 a lot more. At 0 it breaks and is gone. This is ready for mutants to attack walls in v0.15.
- **New item: cement bag** (2 kg). Found in ruin crates (sometimes) and supply crates (1–3).
- **Saved:** tier and hit points of every piece. Older saves load as full-health wood (and scrap roofs and ramps).
- **Tests:** tier hit points, cracks on damage, repair cost and payment, upgrades through both tiers, top tier, prompt text, tier and hit points saved, undo window, half refund, two-click demolish, piece breaking at 0 hp. New screenshot view `14_tiers`.

**Try:** build a wall, then select the hammer (1) and left click it to upgrade to scrap metal. Look for cement in supply crates to make it concrete.
**Next:** v0.11, the base build zone on the ground, a storage chest and the workbench (hammer, bandage, spike barricade).

## v0.9.0 (2026-11-25): More building pieces
- **New pieces** (mouse wheel or 1–8 in build mode):
  - **Doorway with gate** (4 wood, 4 nails): a plank gate on a hinge. Look at it and press **E** to open or close it.
  - **Wall with window** (3 wood, 3 nails): a hole at chest height to look (and later shoot) through.
  - **Wooden floor** (3 wood, 3 nails) for an upper storey.
  - **Wooden stairs** (5 wood, 4 nails) and **scrap ramp** (3 scrap, 2 wood, 3 nails): two squares long, climbing one storey. R turns them to face any of the 4 directions.
  - **Scrap roof** (3 scrap, 2 nails): a corrugated metal sheet that keeps the sun off.
- **Storeys:** pieces stack 2.4 m apart, up to 3 storeys above the ground. Aim at the top of a wall or at an upper floor to build on that level. Anything upstairs must be held up by a wall below it, or by a floor or roof right next to it (so you can build a small overhang). The line above the hotbar says "Needs a wall or floor to hold it up" when it isn't.
- Stairs and ramps are walkable slopes (about 31°). Stairs show steps but walk like a ramp, which is smoother.
- **Saved:** storey and gate open/closed for every piece. v0.8 saves load as before (everything on the ground floor).
- Internals: building.gd was rewritten around a piece table (shapes, colliders, costs) and an "occupied squares" map so pieces can be more than one square big. This replaces the v0.8 version, which only knew foundations and walls.
- **Tests:** upstairs needs support, walls hold up a floor, walls stack, roof overhang, aiming picks the level, window has a hole, gate prompt/open/close/saved, stairs take two squares and free both when taken down, and the player really walks up a ramp. The `13_build` screenshot now shows a hut with every piece.

**Try:** build a 2×2 hut with a doorway, a window and a roof, then stairs up to the roof to look out over the dunes.
**Next:** v0.10, material tiers (wood, scrap metal, concrete) with hit points, and the hammer to upgrade, repair and demolish.

## v0.8.0 (2026-11-25): Build mode
- **Build mode (B):** a see-through preview of the selected piece snaps to a 2 m grid where you look (up to 9 m away). **Green** means you can build it, **red** means you can't, and the line above the hotbar says why: not enough materials, ground too steep, something in the way, or already built.
- **Pieces:** **wooden foundation** (4 wood, 4 nails) fills a grid square and levels out the sand. **Wooden wall** (3 wood, 3 nails) stands on the edge between squares; on a foundation it sits on top of it, otherwise it's planted in the sand.
- **Controls while building:** left click builds, **R** turns walls 90°, the mouse wheel or 1–2 picks the piece, B leaves build mode. **Right click takes a piece down** and gives back everything it cost (the hammer in v0.10 will make this a partial refund and add repairs).
- Pieces are solid (you and, later, mutants collide with them) and they cast shade, which helps with the midday heat.
- You can't build a piece on top of yourself, inside rocks, wrecks or other pieces.
- **Saved:** every piece. Older saves load with nothing built.
- Shorter controls line so it fits at 1280×720.
- The test runner now fails if the game scripts don't compile (before, a parse error could still print "ALL TESTS PASSED").
- **Tests:** build checks (preview snaps to the grid, needs materials, cost taken, no double building, walls on edges and on top of foundations, R turns walls, can't build on yourself, saved and loaded, take down refunds). New screenshot view `13_build`.

**Try:** loot a few crates for wood and nails, then press B near the flag and lay out a 2×2 floor with walls around it.
**Next:** v0.9, more pieces: doorway with a gate, window wall, floor, stairs, ramp and roof.

## v0.7.0 (2026-11-25): Map, morning loot and supply crates
- **Map (M):** a top-down view of the desert inside the mountain ring. Shows the base, every wreck and ruin you have been within 45 m of, supply crates, and a blue arrow for where you are and which way you face. A green dot marks places that still have something to search. M or Esc closes it. The game keeps running while it's open.
- **Loot refills each morning:** at 06:00 up to 4 searched gloveboxes, trunks or crates get new loot (different from last time), picked at random.
- **Supply crates:** most mornings (50%) an olive-green supply crate is dropped somewhere in the desert, with much better loot (lots of nails and wood, food and water). A banner tells you to check the map. Searched supply crates are gone the next morning.
- **Saved:** discovered places, refills, and supply crates. Older saves load with nothing discovered yet.
- This finishes **M2: Scavenging and survival**.
- **Tests:** discovery, place loot dot, refill, re-searching a refilled spot, supply crate spawn/loot/save/cleanup, morning event, map open and close. New screenshot view `12_map`.

**Try:** walk around a bit, then press M. Sleep through a night (or wait for 06:00) and look for the green supply square.
**Next:** M3, building. v0.8 is build mode (B) with wooden foundations and walls.

## v0.6.0 (2026-11-25): Health, hunger and thirst
- **Three needs**, shown as bars in the bottom-left: **health**, **food** and **water**. Gentle by default: food lasts about 40 minutes and water about 25. Sprinting makes both go faster; night is cooler and slower.
- **Midday heat (11:00–16:00):** out in the sun, water drains 1.8× faster and the HUD says "Hot sun: find shade". Standing where a wall, wreck, rock or dune blocks the sun counts as shade.
- **Eat and drink (F):** uses one of the selected hotbar item. Canned food: +35 food. Water bottle: +40 water. Banners warn you when you get hungry or thirsty, and the bar blinks when low.
- **Damage:** an empty food or water bar slowly hurts you; a long fall hurts (jumping off a dune is fine, a cliff isn't). Health slowly comes back while you are fed and watered.
- **Death screen:** shows what killed you, then **Respawn at base** (full health, food and water back up to at least 60%), keeping everything you carry. Main menu also respawns you first, so the autosave isn't a dead player.
- **Saved:** health, food and water. Older saves start full.
- Eating is only on F for now: left click is kept free for the melee weapon in v0.12.
- **Tests:** survival checks (heat vs shade, sprint hunger, thirst damage, drinking, fall damage, eat from hotbar, can't eat scrap, sun check on open sand, death screen, respawn at base with items, needs saved). New screenshot view `11_death`.

**Try:** stand in the open at noon and watch the water bar, then step behind a ruin wall. Eat a can with F.
**Next:** v0.7, the map (M) and loot that refills each morning.

## v0.5.0 (2026-11-25): Inventory and hotbar
- **Inventory (Tab or I):** a 30-slot grid. Items stack (nails up to 50, most things 20, food and water 10). Click a stack, then another slot to move it; dropping it on the same item merges, on a different one swaps. Right-click drops the whole stack. Esc or Tab closes it.
- **Weight limit:** 50 kg. Over that you can't sprint; the inventory screen shows your weight. Scrap is heavy (1.5 kg), nails are light. I chose 50 instead of a tighter limit so a few trunks of scrap don't stop you sprinting before building arrives.
- **Hotbar:** the first 9 slots, shown at the bottom of the screen. Keys 1–9 or the mouse wheel select one. Eating and drinking from it comes in v0.6.
- **Drop (Q):** drops the selected hotbar stack in a bag on the sand. Walk up and press E to pick it back up. If your pockets are full when you search something, what doesn't fit is left in a bag at your feet ("Inventory full").
- **Saved:** the inventory, the selected hotbar slot and dropped bags. v0.4 saves keep the items they had.
- **Tests:** inventory checks (stacking, top-up, swap, merge, remove, weight limit, full inventory, no sprint when overloaded, drop and pick up a bag, bags saved, v0.4 saves). New screenshot view `10_inventory`.

**Try:** loot a couple of wrecks, press Tab and rearrange your hotbar. Drop something with Q and pick it up again.
**Next:** v0.6, health, hunger and thirst.

## v0.4.0 (2026-11-25): Scavenging
- **Interact key (E):** look at something searchable within reach and a prompt appears under the crosshair ("[E] Search trunk"). Walls block it, so no looting through concrete.
- **Wrecks** have a **glovebox** (reach in through the doors) and a **trunk** (at the back). **Ruins** now hide 1–2 wooden **supply crates** in the corner of the wall; searching knocks the lid off.
- **Loot:** scrap metal, wood, cloth, nails, canned food and water bottles. Gloveboxes hold small things, trunks hold scrap and nails, crates hold wood and supplies. Each container's loot is fixed for a given world, so reloading doesn't reroll it.
- **Pickup pop-ups** on the right ("+3 Scrap metal") that fade out.
- **Saved:** which containers are searched and everything you picked up. Older saves still load (nothing searched, empty pockets).
- Crates use their own random stream, so the rest of an existing world stays where it was.
- **Tests:** loot checks (crosshair finds a crate, search gives loot, empty after, saved and restored, repeatable rolls). New screenshot view `09_crate`.

**Try:** walk to a wreck, aim at the doors and press E, then the trunk. Ruins have crates tucked in the corner.
**Next:** v0.5, the inventory screen (Tab) and the hotbar, so you can see what you've collected.

## v0.3.0 (2026-11-25): Title screen, saving and loading
- **Title screen:** the desert at sunset with a slowly circling camera behind the menu. Buttons: **Continue** (loads your most recent save), **New game**, **Load game**, **Settings** and **Quit to desktop**.
- **New game:** each new game generates a different desert. The world seed is stored in the save.
- **Saving:** three manual save slots, plus a **quicksave** (F5, load with F9) and an **autosave**. Each slot shows a screenshot thumbnail, the day and time, how long you've played, and when it was saved. Saving over a used slot asks you to confirm.
- **Autosave:** every morning at 06:00, when you go to the main menu, when you quit, and when you close the window.
- **Pause menu:** Resume, Save game, Load game, Settings, Main menu and Quit to desktop. Esc goes back a page.
- **What a save keeps:** world seed, day and time, player position, facing and stamina. Inventory, buildings and waves will be added as those features arrive. The save format is versioned.
- Save files go in `~/.local/share/godot/app_userdata/Desert Fortress/saves/`.
- **Tests:** 29 headless checks (new: save, load, restore, slot descriptions, title screen). The new `tools/flow_test.gd` runs title, new game, save, main menu and continue with a real display.

**Next:** M2, scavenging.

## v0.2.0 (2026-11-25): Day and night, menu, sound
- **Day/night cycle:** 10-minute days and 4-minute nights. The sun moves across the sky, sunsets are orange, nights are dark blue with stars and soft moonlight. The HUD shows the day and the time, and counts down "Night in m:ss" for the last 2 minutes. Banners announce dusk, night and the new day. The cycle sends dusk, night and day events for the wave system later.
- **Pause menu (Esc):** resume, mouse sensitivity, field of view, volume, fullscreen and quit. Settings are saved between sessions.
- **Sound, made in code:** gusting wind (calmer at night), footsteps in the sand and a thump when you land from a jump.
- **Crouch (Ctrl or C):** slower and lower. You can't stand up under something.
- **Drifting dust** around the player.
- **Props sit properly on the ground:** a new exact terrain height lookup fixes floating or buried rocks. Ruin blocks are each planted on the sand.
- **New car wrecks:** a car shape with windows, bumpers, wheels and rust patches, tilted to follow the dune slope.
- **Lighting:** midday is less washed out.
- 18 headless tests (new: height lookup matches the collision surface, crouch, day/night events, pause). The screenshot tool now covers 8 views, including sunset, night, wreck, ruin and menu.

**Try:** stay out until the sun sets (about 9 minutes in), then press Esc to adjust your mouse sensitivity.
**Next:** M2, scavenging (interact key and loot in wrecks and ruins).

## v0.1.0 (2026-11-25): Walking around the desert
- Procedural low-poly desert (512 × 512 m) with dunes, a mountain ring at the edge and a flat clearing in the centre for the future fortress
- First-person player: walk, sprint with stamina, jump, mouse look, head bob
- Props: about 260 rocks, 140 cacti, 500 shrubs, 14 rusted car wrecks and 9 ruined concrete walls (future loot spots), plus a flag and crates marking the base
- HUD: compass, distance and direction to base, stamina bar, controls help
- Launcher `play.sh` downloads Godot on first run
- Headless tests (10 checks) and a screenshot tool for visual checks

**Next:** day/night cycle (see ROADMAP M1).
