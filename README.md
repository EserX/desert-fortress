# Desert Fortress

A 3D low-poly survival and fortress-defence game for Linux, made with Godot 4.5. Scavenge the desert by day, build and arm a fortress around the flag, and survive a bigger mutant wave every night. Each night pays cash you spend at the shop terminal on supplies, weapons, drone deliveries and base upgrades.

**Current version: v1.0.** See [ROADMAP.md](ROADMAP.md) for the plan and [DEVLOG.md](DEVLOG.md) for what changed in each update.

## Play (Linux Mint)

```bash
git clone https://github.com/EserX/desert-fortress.git
cd desert-fortress
./play.sh
```

The first run downloads the Godot engine (about 50 MB) into `~/.local/share/desert-fortress`. After that it starts straight away. If the game won't start or looks broken, try the OpenGL renderer with `./play.sh --compat`.

To get the latest version:

```bash
cd ~/desert-fortress
git pull
./play.sh
```

If `git pull` complains about untracked `.uid` files, they are safe to delete.

### Standalone build

`./export.sh` makes a single file, `build/desert-fortress.x86_64`, that runs without Godot or this folder. The first time it downloads Godot's export templates (about 1.3 GB, one time only) and keeps only the Linux ones.

## How to play

**Your first day.** You start by the flag with a hammer and a rusty pipe. Walk out to the car wrecks and ruins, and search gloveboxes, trunks and crates with **E** for wood, scrap, nails, cloth, food and water. Press **M** for the map. Come back before dark.

**Survival.** Health, food and water are in the bottom left. The midday sun (11:00–16:00) makes you thirsty faster unless you stand in shade. Eat and drink with **F** from the hotbar. When you die you wake up at the flag with your items.

**Building.** Press **B** near the flag. Pick a piece with the mouse wheel (or 1–9), turn it with **R**, build with left click. Everything must be inside the ring of stakes (the base zone). Right click undoes a piece built in the last minute. With the **hammer** selected, left click a piece to repair it or upgrade it (wood, then scrap metal, then concrete), and right click twice to demolish it for half the cost back. Upstairs pieces need walls or floors under them; if those break, they fall.

**Nights.** At 18:30 a siren warns you. At 20:00 a wave of mutants comes in from the edge of the map and marches on the base. Close to you they know where you are, walls or not, and tear through anything in their way. The wave ends when all are dead or at dawn. A summary shows your kills and your pay.

| Mutant | What to know |
|---|---|
| Walker | Slow and steady. 3 pipe hits or 3 pistol shots. |
| Runner (night 2+) | Faster than you walk, weak. Sprint or shoot. |
| Spitter (night 3+) | Keeps its distance and lobs acid that also eats walls. Hide, then rush it. |
| Brute (night 4+) | Huge, slow, very tough, wrecks walls in a few blows. Kill it before it reaches them. |

**Weapons.** Melee costs stamina. Guns are loud and bring mutants running. Hold **right click** to aim (the rifle has a scope), **R** reloads. Headshots do double damage.

**Defences.** Spike barricades, spike strips, barbed wire (slows them) and landmines. An electric fence and floodlights need a fuel generator within 18 m (fuel cans come from car trunks). A fire pit burns mutants that walk through it. Auto-turrets stand on tall masts and shoot anything they can see within 22 m, over your walls, using the 9mm rounds you load into them with **E**.

**Cash and the shop.** Every night pays for kills, for surviving, and for how much of the base still stands (more if you kill the whole wave). The **shop terminal** next to the flag has three pages:
- **Counter:** materials, food, weapons, ammo and trap parts, straight into your pockets.
- **Drone orders:** big loads and **blueprints** (auto-turret, electric fence, sandbag wall), flown to a **drone landing pad** you build.
- **Base upgrades:** a bigger build zone, bigger chests, workbench tiers (shotgun at tier 2, rifle and medkits at tier 3), and a radio that tells you at dusk which mutants are coming.

**Difficulty.** New game asks for Easy, Normal or Hard (wave size, mutant toughness, pay, and how fast you get hungry). First-time tips explain each thing as you meet it; turn them on or off in Settings.

## Controls

| Key | Action |
|---|---|
| W A S D / arrows | Move |
| Shift | Sprint (uses stamina; not when carrying too much) |
| Space | Jump |
| Ctrl / C | Crouch (quieter) |
| Mouse | Look |
| Left click | Swing, shoot, build, or use the hammer |
| Right click | Aim a gun; hammer: demolish; build mode: undo |
| R | Reload; build mode: turn the piece |
| E | Search, open, use (gates, chests, workbench, generator, fire pit, turret, shop) |
| Tab / I | Inventory |
| 1–9, mouse wheel | Hotbar slot (build mode: piece) |
| F | Eat, drink, use a bandage or medkit |
| Q | Drop the selected stack |
| B | Build mode |
| M | Map |
| F5 / F9 | Quicksave / quickload |
| Esc | Pause menu (save, load, settings, quit) |
| F11 | Fullscreen |

## Settings and performance

Settings (title screen or pause menu): mouse sensitivity, field of view, volume, fullscreen, first-time hints, and **graphics quality**. **Low** turns off sun shadows, renders at 75% resolution and shortens the view distance; use it if the game stutters. **Medium** keeps shorter shadows. **High** is the default (shadows to 160 m, 2× anti-aliasing).

Saves and settings live in `~/.local/share/godot/app_userdata/Desert Fortress/`.

## Giving feedback

Add notes under **Player feedback** at the top of `ROADMAP.md` (bugs, how something feels, ideas), then commit and push them. The next development run reads them first.

## Development

- `scripts/`: all game code (GDScript). The world is built in code, so there are hardly any scene files.
- `tests/run_tests.gd`: headless tests. Run with
  `godot --headless --path . -s tests/run_tests.gd --fixed-fps 60`
- `tools/flow_test.gd`: runs title, new game, save, main menu and continue with a display.
- `tools/screenshot.gd`: renders screenshots for visual checks. Run with
  `xvfb-run godot --path . -s tools/screenshot.gd --rendering-method gl_compatibility`
- `tools/soak_test.gd`: builds a fortress and plays a whole big night headless, to catch errors and check speed.
- `export_presets.cfg` and `export.sh`: the standalone Linux build.
- `CLAUDE.md`: instructions for the scheduled development runs.
