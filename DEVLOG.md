# Dev log

Newest entries on top. Each development run adds one entry.

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
