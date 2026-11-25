# Desert Fortress

A 3D low-poly survival game for Linux, made with Godot 4.5. Build a fortress in the desert, scavenge wrecks and ruins for items, and survive waves of mutants with traps and weapons. Each wave pays money you spend in an in-game online shop to upgrade your base.

**Current version: v0.1, walking around the desert.** See [ROADMAP.md](ROADMAP.md) for what's coming and [DEVLOG.md](DEVLOG.md) for what changed in each update.

## Play (Linux Mint)

```bash
git clone https://github.com/EserX/desert-fortress.git
cd desert-fortress
./play.sh
```

The first run downloads the Godot engine (about 50 MB) into `~/.local/share/desert-fortress`. After that it starts straight away.

To get the latest version:

```bash
cd desert-fortress
git pull
./play.sh
```

If the game won't start or looks broken, try the OpenGL renderer with `./play.sh --compat`.

## Controls

| Key | Action |
|---|---|
| W A S D / arrows | Move |
| Shift | Sprint (uses stamina) |
| Space | Jump |
| Mouse | Look |
| Esc | Release the mouse (click to return to the game) |
| F11 | Fullscreen |

## Giving feedback

Add notes under **Player feedback** at the top of `ROADMAP.md` (bugs, how something feels, ideas), then commit and push them. The next development run reads them first.

## Development

- `scripts/`: all game code (GDScript). The world is built in code, so there are hardly any scene files.
- `tests/run_tests.gd`: headless smoke tests. Run with
  `godot --headless --path . -s tests/run_tests.gd --fixed-fps 60`
- `tools/screenshot.gd`: renders screenshots for visual checks. Run with
  `xvfb-run godot --path . -s tools/screenshot.gd --rendering-method gl_compatibility`
- `CLAUDE.md`: instructions for the scheduled development runs.
