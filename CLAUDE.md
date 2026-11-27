# Instructions for development runs

This is **Desert Fortress**, a 3D low-poly survival and fortress-defence game in Godot 4.5.1 (GDScript). The owner plays on Linux Mint (MSI GF63 laptop) and checks progress in the evening. You usually run unattended on a schedule, so nobody can answer questions. Make sensible decisions and write them down in DEVLOG.md.

## Each run
1. **Get Godot** if it's missing. The engine is not checked in.
   `mkdir -p /tmp/godot && cd /tmp/godot && curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip && unzip -o -q g.zip && mv Godot_v4.5.1-stable_linux.x86_64 godot && chmod +x godot`
2. **Read** ROADMAP.md (the *Player feedback* section first), the top of DEVLOG.md, and the code you will touch.
3. **Pick the work:** player feedback items first, otherwise the next `[ ]` roadmap item. Do **one** item well. A small, solid step beats a big broken one.
4. **Implement** it. Keep the existing style: the world is built in code, scripts are preloaded (no `class_name`), autoloads are Settings, Game and InputSetup (in test scripts reach them with `root.get_node("Game")`), and there are typed GDScript, tabs and short doc comments.
5. **Test:**
   - `godot --headless --path . --import`
   - `godot --headless --path . -s tests/run_tests.gd --fixed-fps 60`. All tests must pass. Add tests for new logic where practical.
   - `xvfb-run -a -s "-screen 0 1600x900x24" godot --path . -s tools/screenshot.gd --rendering-method gl_compatibility --resolution 1280x720`. Look at the PNGs in `screenshots/` (ignored by git) to check that it looks right. Add viewpoints to the tool if your feature needs them.
   - If you touched menus, saving or scene flow, run `xvfb-run -a -s "-screen 0 1600x900x24" godot --path . -s tools/flow_test.gd --rendering-method gl_compatibility --resolution 1280x720`.
   - New game state (inventory, buildings...) must be added to `collect_save_data` / `apply_save_data` in main.gd, with a test. Bump `SAVE_VERSION` in game.gd only if old saves can't load, and keep loading older saves where you can.
   - Read the Godot output for `SCRIPT ERROR` / `ERROR` lines, even when tests pass.
6. **Record:** tick the item in ROADMAP.md, clear feedback items you handled, and add a DEVLOG.md entry at the top (version bump, what changed, anything the player should try, what's next). Bump `config/version` in project.godot (the HUD, title screen and saves read it from there) and the "Current version" line in README.md. If the change affects how to play, update the README manual too.
7. **Commit and push** to `main` with a clear message. If you can't finish the item, push only working code. Leave a note in DEVLOG.md and keep the item unticked.

## Rules
- Never leave `main` broken. If tests fail and you can't fix them, revert your changes and only log what happened.
- The game must keep working with both the Forward+ (default) and the gl_compatibility renderer.
- Performance target: smooth on a GTX 1650-class laptop. Use MultiMesh for many repeated props.
- Assets: generate them in code (low-poly primitives) or use CC0 assets with the source noted in `assets/CREDITS.md`.
- Don't rewrite large working systems without a reason recorded in DEVLOG.md.
- Don't add outside libraries, plugins or addons. Everything is made in code. The only download is Godot itself, from the official link in step 1.

## Code rules
- **Keep main.gd from growing.** It is already about 1,900 lines. A new system (the main well, farming, the market, greening, animals...) gets its own script in `scripts/`, like `nav.gd`, `power.gd` and `traps.gd`. main.gd only creates it, connects its signals and passes its data to saving and loading.
- **One place for shared logic.** Paying from pockets and chests, placing pieces, support values and save data each already have one home (inventory, building, main's `collect_save_data` / `apply_save_data`). Call those rather than writing a second version.
- **Bugs before features.** If you find a bug while working, or the tests or Godot output show one, fix it before starting a new feature, or write it under *Player feedback* in ROADMAP.md so the next run handles it. For a bug fix, write the test that fails first, then fix it, and only call it fixed once that test passes.
- **Saves.** Old saves must keep loading. Missing fields get sensible defaults. When the shape of saved data changes (not just new fields), bump `SAVE_VERSION` in game.gd and add an explicit upgrade step from the old version, with a test that loads an old-style save. A broken or hand-edited save must not crash the game: check types when reading and fall back to defaults.
- **Repeatable world.** Anything that is saved or generated (the world layout, loot, trees, oases, crop growth) comes from seeded random number generators, so the same seed gives the same world. Short-lived effects (debris spin, particles) can use plain randomness.
- **Delayed and spread-out work.** After `await`, `call_deferred`, tweens and work spread over frames (like the nav flow fields), check with `is_instance_valid()` that the nodes still exist. Mark results that can go out of date (a counter or "dirty" flag) and throw them away when the world changed in between.
- **Loops.** Don't add or remove items in a dictionary or array while looping over it (loop over `.keys()` or a copy). Use queues with a visited set instead of recursion for things that spread (collapses, support, water, greening). For a loop over all pieces, mutants, terrain cells, cables, plants or props, add a short comment on how often it runs and how big it can get. Measure before optimising (`tools/nav_bench.gd` and `tools/soak_test.gd` are there for that), and keep a benchmark for anything you optimise.
