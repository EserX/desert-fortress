# Dev log

Newest entries on top. Each development run adds one entry.

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
