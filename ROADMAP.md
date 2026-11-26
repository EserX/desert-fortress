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
- [ ] v1.1: **Deformable ground.** Replace the base area (first the build zone, later the whole map) with a finer height grid in chunks (1 m cells) that can be lowered and raised. Rebuild a chunk's mesh and collision when it changes, and save changes as height deltas (old saves load flat). **Shovel** (workbench and shop): left click digs a 1 m patch (gives **sand**), right click fills (uses sand). Bedrock about 4 m down, and pieces can't be undermined without falling. Tests for dig, fill, collision height, saving
- [ ] v1.2: **Trenches and pits.** Mutants can't climb steep pit walls: they fall in and climb out slowly (or not at all past 2 m), so a trench ring is a defence. Spiked pit trap (a pit with stakes), ramps and ladders out of pits for you. Sandbags made from sand + cloth. Foundations level the ground under them
- [ ] v1.3: **Mining.** Pickaxe: rocks become breakable for **stone**, and digging deeper hits clay and stone layers. A stone building tier between scrap metal and concrete. Buried caches found with a craftable metal detector
- [ ] v1.4: **Water well.** Dig down at the base to strike water: a well piece gives a slow, endless water supply. Digging and building use stamina

### M8: Building capabilities
- [ ] v1.5: **Structural stability.** Each piece gets a support value counted from the ground (foundation 100%, less with every piece out or up from it). Long overhangs and tall towers lose stability, heavier tiers need more support, and the hammer shows the %. Pieces below a minimum collapse, with simple physics debris (rigid-body chunks that settle, then vanish)
- [ ] v1.6: **More pieces:** half wall and low wall (to shoot over), gun slit wall, corner pillar, ladder, trapdoor in floors, triangle foundation and roof for round-ish towers, metal door. Simple shapes only
- [ ] v1.7: **Faster building:** drag to lay a line of walls or foundations, upgrade or repair everything in an area at once (paid from your pockets or a chest in reach), pick up a piece and put it down elsewhere
- [ ] v1.8: **Doors, switches and wiring:** gates that close by themselves at night, a lockable metal gate, and power carried by cables you lay from the generator to switches, lights, fences and turrets (instead of the fixed 18 m range)

### M9: Game logic, AI and physics
- [ ] v1.9: **Mutant navigation:** a navigation mesh, rebuilt when the base or the ground changes, so mutants path round walls to an open gate or the weakest wall instead of walking straight in. Brutes go straight through, pits and wire are taken into account, and groups pick the same weak point
- [ ] v2.0: **Physics pass:** explosions push mutants and loose items, dropped items become physics props, throwables (molotov, pipe bomb, rocks) with arcs and bounces, knockback and stagger tuned per weapon, mutants falling into pits and off roofs
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
- Visuals: simple low-poly, no art or animation work (focus on logic, physics, building, digging)
- Testing aid: a green **test box** next to the spawn point holds a stack of every item and tops your cash up to $2000 (`TEST_BOX` in `scripts/main.gd`). Keep it until the owner asks to remove it, and add new items to it automatically (it fills from `Items.ITEMS`)
