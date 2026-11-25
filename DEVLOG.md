# Dev log

Newest entries on top. Each development run adds one entry.

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
