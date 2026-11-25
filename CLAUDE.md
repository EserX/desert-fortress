# Instructions for development runs

This is **Desert Fortress**, a 3D low-poly survival and fortress-defence game in Godot 4.5.1 (GDScript). The owner plays on Linux Mint (MSI GF63 laptop) and checks progress in the evening. You usually run unattended on a schedule, so nobody can answer questions. Make sensible decisions and write them down in DEVLOG.md.

## Each run
1. **Get Godot** if it's missing. The engine is not checked in.
   `mkdir -p /tmp/godot && cd /tmp/godot && curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip && unzip -o -q g.zip && mv Godot_v4.5.1-stable_linux.x86_64 godot && chmod +x godot`
2. **Read** ROADMAP.md (the *Player feedback* section first), the top of DEVLOG.md, and the code you will touch.
3. **Pick the work:** player feedback items first, otherwise the next `[ ]` roadmap item. Do **one** item well. A small, solid step beats a big broken one.
4. **Implement** it. Keep the existing style: the world is built in code, scripts are preloaded (no `class_name`), and there are typed GDScript, tabs and short doc comments.
5. **Test:**
   - `godot --headless --path . --import`
   - `godot --headless --path . -s tests/run_tests.gd --fixed-fps 60`. All tests must pass. Add tests for new logic where practical.
   - `xvfb-run -a -s "-screen 0 1600x900x24" godot --path . -s tools/screenshot.gd --rendering-method gl_compatibility --resolution 1280x720`. Look at the PNGs in `screenshots/` (ignored by git) to check that it looks right. Add viewpoints to the tool if your feature needs them.
   - Read the Godot output for `SCRIPT ERROR` / `ERROR` lines, even when tests pass.
6. **Record:** tick the item in ROADMAP.md, clear feedback items you handled, and add a DEVLOG.md entry at the top (version bump, what changed, anything the player should try, what's next). Bump `config/version` in project.godot and the HUD title.
7. **Commit and push** to `main` with a clear message. If you can't finish the item, push only working code. Leave a note in DEVLOG.md and keep the item unticked.

## Rules
- Never leave `main` broken. If tests fail and you can't fix them, revert your changes and only log what happened.
- The game must keep working with both the Forward+ (default) and the gl_compatibility renderer.
- Performance target: smooth on a GTX 1650-class laptop. Use MultiMesh for many repeated props.
- Assets: generate them in code (low-poly primitives) or use CC0 assets with the source noted in `assets/CREDITS.md`.
- Don't rewrite large working systems without a reason recorded in DEVLOG.md.
