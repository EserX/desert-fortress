# Roadmap

## Player feedback
<!-- Write bugs, feelings and ideas here. Each run handles these BEFORE roadmap items. -->
<!-- Example: - Sprint feels too slow. - Fell through the ground near a big rock. -->

## Milestones
One version per development run, in this order. The full plan with reasons is in the "Desert Fortress: Version Plan" doc. Player feedback above always comes first.

### Done
- [x] v0.1: procedural desert, first-person movement, props, compass HUD
- [x] v0.2: day/night cycle, pause menu and settings, generated audio, crouch, dust
- [x] v0.3: title screen, New game, Continue, save slots, quicksave and autosave, quit to desktop

### M2: Scavenging and survival
- [x] v0.4: Interact key (E) with an on-screen prompt. Search wrecks (glovebox, trunk) and ruins (crates). Pickup pop-ups. Loot: scrap metal, wood, cloth, nails, canned food, water bottles. Opened containers are saved
- [x] v0.5: Inventory (Tab) with a grid, stacking and a weight limit (too heavy means no sprint). Hotbar 1–9, drop items. Saved with the game
- [x] v0.6: Health, hunger and thirst. Midday heat drains water faster, and shade helps. Eat and drink from the hotbar. Death screen, then respawn at the base flag, keeping your items
- [x] v0.7: Map (M) showing discovered places. Loot refills each morning at random spots. Rare supply crates with better loot

### M3: Building the fortress
- [x] v0.8: Build mode (B): see-through preview that snaps to a grid and turns green or red, with rotate (R). Wooden foundations and walls that cost wood and nails. Saved
- [x] v0.9: More pieces: doorway with a gate (E opens it), wall with window, floor, stairs, ramp, roof
- [x] v0.10: Material tiers (wood, then scrap metal, then concrete) with hit points. Hammer to upgrade, repair and demolish (part refund). Cracks when damaged
- [x] v0.11: Base build zone shown on the ground, storage chest, workbench crafting (hammer, bandage, spike barricade)

### M4: Combat and mutant waves
- [x] v0.12: First-person hands, melee weapon (rusty pipe, then machete), swing and hit feedback, stamina cost, training dummy
- [x] v0.13: First mutant, the Walker: wanders, spots you, chases and attacks. Health, death and a fall
- [x] v0.14: Wave system: siren at dusk, mutants come from the map edge at night, wave counter, night ends at dawn or when all are dead, end-of-wave summary
- [x] v0.15: Mutants head for the base, attack walls in their way and break in. Walls collapse
- [x] v0.16: Runner (fast, weak), Brute (slow, tanky, wrecks walls) and Spitter (ranged acid). Waves mix types and scale up each night

### M5: Defence
- [x] v0.17: Pistol: aim down sights, recoil, muzzle flash, reload, ammo as an item, sound
- [x] v0.18: Shotgun and rifle, weapon switching, ammo types, headshot bonus
- [x] v0.19: Traps: spike strip, barbed wire (slows), landmine
- [x] v0.20: Fire pit, electric fence with a fuel generator, floodlights
- [x] v0.21: Auto-turret fed from an ammo box, range circle shown while placing

### M6: Economy and v1.0
- [x] v0.22: Cash per wave (kills, waves survived, base condition). Shop terminal at the base: materials, weapons, ammo, traps
- [x] v0.23: Drone delivery to a landing pad. Blueprints unlock new builds
- [x] v0.24: Base upgrades: bigger build zone, storage, workbench tiers, a radio warning which mutant types are coming
- [x] v1.0: Balance and polish: difficulty settings, first-time hints, performance pass, standalone Linux export, README as a short manual

### Focus after 1.0 (owner, 2026-11-26)
Keep the visuals simple (low-poly primitives, no art or animation work) and put the effort into **game logic, physics, building and digging**. M7 to M9 below are in order; player feedback still comes first.

### M7: Digging and terrain
- [x] v1.1: **Deformable ground.** Replace the base area (first the build zone, later the whole map) with a finer height grid in chunks (1 m cells) that can be lowered and raised. Rebuild a chunk's mesh and collision when it changes, and save changes as height deltas (old saves load flat). **Shovel** (workbench and shop): left click digs a 1 m patch (gives **sand**), right click fills (uses sand). Bedrock about 4 m down, and pieces can't be undermined without falling. Tests for dig, fill, collision height, saving
- [x] v1.2: **Trenches and pits.** Mutants can't climb steep pit walls: they fall in and climb out slowly (or not at all past 2 m), so a trench ring is a defence. Spiked pit trap (a pit with stakes), ramps and ladders out of pits for you. Sandbags made from sand + cloth. Foundations level the ground under them
- [x] v1.3: **Mining.** Pickaxe: rocks become breakable for **stone**, and digging deeper hits clay and stone layers. A stone building tier between scrap metal and concrete. Buried caches found with a craftable metal detector
- [x] v1.4: **Water well.** Dig down at the base to strike water: a well piece gives a slow, endless water supply. Digging and building use stamina

### M8: Building capabilities
- [x] v1.5: **Structural stability.** Each piece gets a support value counted from the ground (foundation 100%, less with every piece out or up from it). Long overhangs and tall towers lose stability, heavier tiers need more support, and the hammer shows the %. Pieces below a minimum collapse, with simple physics debris (rigid-body chunks that settle, then vanish)
- [x] v1.6: **More pieces:** half wall and low wall (to shoot over), gun slit wall, corner pillar, ladder, trapdoor in floors, triangle foundation and roof for round-ish towers, metal door. Simple shapes only
- [x] v1.7: **Faster building:** drag to lay a line of walls or foundations, upgrade or repair everything in an area at once (paid from your pockets or a chest in reach), pick up a piece and put it down elsewhere
- [x] v1.8: **Doors, switches and wiring:** gates that close by themselves at night, a lockable metal gate, and power carried by cables you lay from the generator to switches, lights, fences and turrets (instead of the fixed 18 m range)

### Owner requests (2026-11-27)
Building is to be a big part of the game, with the fine-tuned feel of survival-builder games: turn pieces freely before placing them, ready-made buildings such as cabins, and a stand with a button that calls the enemies to you.
- [x] v1.9: **Building overhaul:** objects turn in 15° steps (Z / X) and the preview swings round smoothly; ready-made buildings (shelter, cabin, big cabin, watchtower, gatehouse) laid as free blueprints and built piece by piece with E (hold to keep going), paid from pockets and chests; the **horde button** stand at the spawn point calls a wave on demand; build-mode key help; walls at corners no longer blocked
- [ ] Later building ideas (not scheduled): more ready-made buildings (a walled compound, a bunker with a well), choosing the tier of a blueprint, a blueprint menu with pictures

### Owner requests (2026-11-27, later)
Resource gathering and processing: trees and an axe, rocks to pick up, machines bought for cash and delivered by drone (a rock crusher for cement), and traps made from gathered resources.
- [x] v1.11: **Gathering and processing:** groves of palms and acacias felled with an axe for logs (they grow back), loose stones to pick up, a sawmill, rock crusher and nail press bought by drone and run on generator power, splitting logs by hand at the workbench, log stakes trap
- [ ] Later resource ideas (not scheduled): a furnace and the v2.2 crafting chain feeding off these machines, a water purifier, machines that feed a chest automatically

### New direction (owner, 2026-11-27): terraform the desert
The aim of the game shifts from pure base defence to **turning the dead desert green and making it livable**. A **main well** at the centre (the spawn point) is the heart of the base: all water starts there, it greens the land through a watering system, and its water is what draws the mutants in at night. Water brings life: **animals by day** (food), **mutants by night**. Seeds are bought, crops are grown and sold, and cash buys food and goods (grow exotic crops, sell them, buy what you need). Base defence stays as one part of the game, not the whole of it. M10 comes **before** the rest of M9 (v2.0 to v2.3 wait until M10 is done, unless the owner says otherwise).

Design notes for every M10 run:
- Track greening on a **coarse grid** over the whole map (for example 4 to 8 m cells: moisture and a stage from dead sand to firm ground, soil, grassland and grove) and blend ground colour and MultiMesh plants from it. Keep the fine diggable ground only where you build. Smooth on a GTX 1650-class laptop.
- Every step must be playable on its own and saved.
- Keep the existing systems (digging, dug wells, power, machines, shop and drone, waves) and connect them rather than replace them. Dug wells (v1.4) stay as smaller extra water sources.
- Plants have different jobs: **food** (millet, melons, dates), **resources** (cotton to cloth, agave to fibre and rope, fast acacia to wood), **flowers** (speed up crops and greening nearby, sell well), **fruit trees** (slow, give shade and fruit for years, push the green out) and **exotic cash crops** (saffron, dragon fruit: dear seeds, fussy, big profit).

### M10: Terraforming
- [x] v1.13: **The main well and watering:** a big main well at the spawn point (next to the flag) with a water store that refills each day and can be deepened with upgrades; a watering can, then a hand pump, pipes and sprinklers fed from it; watered sand turns to soil on a coarse map-wide grid and slowly greens (grass, small plants), shown on the ground. Saved
- [ ] v1.14: **Seeds and farming:** seeds in the shop (by drone), seed beds and planting on soil, growth stages over days needing water (and shade for some), dying in the midday heat when dry; harvests by type (food, resources, flowers, fruit trees, exotic crops) with their own benefits
- [ ] v1.15: **The market:** sell crops, flowers, fruit and goods at the shop terminal for cash; daily prices, prices that drop when you sell a lot of one thing, exotic crops worth the most; buy food and goods with the cash
- [ ] v1.16: **Water draws life:** by day animals (gazelles, birds, jackals) come to water and green land, hunted for meat (cooked at the fire pit); by night mutants are drawn to the main well, wave size grows with water use and green land rather than only the night count, and they go for fields and pipes too
- [ ] v1.17: **Green and livable:** a **green %** for the whole map and a **livable** score for the base (shade, water, food, plants, shelter) on the HUD and map; fruit trees and groves spread on their own; livable milestones give comforts (faster healing, resting through the heat, a better shelter)
- [ ] v1.18: **Oases and outposts:** 3 to 5 hidden oases with springs, rare and exotic seeds, clay and reeds, guarded by mutants or a nest; claim one as an outpost with its own build zone, water and defences; nests keep the land round them dead until burned out
- [ ] v1.19: **Goals and an ending:** green % milestones (10, 25, 50) unlock new seeds, machines and a weather station; the final milestone brings back rain (an ending, then free play); a peaceful terraform-only mode in the difficulty settings

### M9: Game logic, AI and physics
- [x] v1.10: **Mutant navigation:** a navigation mesh, rebuilt when the base or the ground changes, so mutants path round walls to an open gate or the weakest wall instead of walking straight in. Brutes go straight through, pits and wire are taken into account, and groups pick the same weak point
- [x] v1.12: **Physics pass, part 1:** knockback and stagger tuned per weapon, mine blasts throw mutants (and their bodies) and scatter debris, a Brute's fist shoves you, mutants knocked into pits and off roofs, and long falls hurt them
- [ ] v2.0: **Physics pass, part 2:** dropped items become physics props, throwables (molotov, pipe bomb, rocks) with arcs and bounces that use the v1.12 blasts
- [ ] v2.1: **Survival depth:** cold nights (fire pits and walls keep you warm), bleeding wounds fixed with bandages, cooking at the fire pit, food that spoils, and carried weight slowing digging and climbing
- [ ] v2.2: **Crafting chain:** a furnace (scrap to metal plates, sand to glass, clay to bricks), building parts made at the workbench, better tools (a steel shovel digs faster, a sledgehammer demolishes)
- [ ] v2.3: **Events:** sandstorms (short view range, mutants out by day, dug holes slowly fill in), a boss mutant every 10 nights, and day raids on outposts away from the base

### Later (not scheduled, the owner picks)
A buggy, outposts, animated low-poly characters, a generated soundtrack, Windows and Steam Deck builds.

### Defaults until the owner says otherwise
- Death: respawn at the base and keep your items
- Hunger and thirst: gentle
- Night: 4 minutes
- Camera: first person only
- Weapons: realistic guns
- Order: building before combat
- Aim: terraform the desert and make it livable around a main well at the centre (owner, 2026-11-27); base defence is one part of the game
- Visuals: simple low-poly, no art or animation work (focus on logic, physics, building, digging)
- Testing aid: a green **test box** next to the spawn point holds a stack of every item and tops your cash up to $2000 (`TEST_BOX` in `scripts/main.gd`). Keep it until the owner asks to remove it, and add new items to it automatically (it fills from `Items.ITEMS`)
