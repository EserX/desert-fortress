# Dev log

Newest entries on top. Each development run adds one entry.

## v0.4.0 (2026-11-26): Scavenging
- **Interact key (E):** look at something searchable within arm's reach and a prompt appears under the crosshair: "[E] Search trunk". Pressing E starts a short search with a progress bar and a rustling sound. Walking off or looking away cancels it.
- **What you can search:** every car wreck has a **glovebox** (stand by either front door) and a **trunk** (stand behind the car; the lid swings open). Every ruin has one or two **wooden supply crates** tucked inside the corner of the wall, with a lid that flips open. That's 28 wreck spots and about 15 crates per desert.
- **Loot:** scrap metal, wood, cloth, nails, canned food and water bottles. Each kind of container has its own loot table: gloveboxes give small things (cloth, nails, food, water) and are sometimes empty, trunks mostly give scrap, crates mostly wood and nails.
- **Pick-up pop-ups** on the right show what you found and your new total, e.g. "+3 Scrap metal (7)", with a soft chime.
- **Saved:** searched containers stay open (and empty) after loading, and what you carry is kept in the save. Older v0.3 saves still load, just with empty pockets. Loot is fixed per world, so reloading doesn't reroll it.
- **Decisions:** for now your items are a simple tally (no inventory screen yet; that's v0.5, which will use the item weights already defined). Containers use their own random stream, so wrecks, rocks and ruins in existing worlds didn't move. The base crates are decoration, not loot.
- **Tests:** 46 headless checks (new: containers placed with unique ids, repeatable loot rolls, aiming at a trunk shows the prompt, searching fills the inventory, lid opens, can't search twice, looking away cancels, save and load of opened containers and inventory, loading a v0.3 save). Screenshot tool has 4 new views: trunk closed and open, crate closed and open.

**Try:** head out to a car wreck, stand behind it and press E on the trunk, then open the glovebox from the side. Find a concrete ruin and check the crates in its corner. Quicksave (F5), quickload (F9) and see that they stay searched.
**Next:** v0.5, inventory screen (Tab) with a grid, stacking, weight limit, hotbar and dropping items.

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
