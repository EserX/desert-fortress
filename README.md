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

**Building.** Press **B** near the flag. Pick a piece with the mouse wheel (or 1–9), turn it with **R**, build with left click. Everything must be inside the ring of stakes (the base zone). Right click undoes a piece built in the last minute. With the **hammer** selected, left click a piece to repair it or upgrade it (wood, then scrap metal, then stone, then concrete), and right click twice to demolish it for half the cost back. Upstairs pieces need walls or floors under them; if those break, they fall.

**Faster building.** In build mode, hold left click on the first square (or edge) and let go on the last to build a whole **line** of up to 12 walls, foundations, floors or pillars, each one paid as it goes. With the hammer, **R** repairs everything damaged within 8 m and **G** upgrades every piece of the same tier as the one you look at within 8 m; both pay from your pockets and any chest within reach. In build mode, **G** picks up the piece you look at (a chest keeps its contents, a turret its ammo, damage stays) and left click puts it down elsewhere for free; G again (or leaving build mode) puts it back. Foundations and pieces that hold something up can't be moved.

**Ready-made buildings and turning.** In build mode, **Z / X** turn the piece (chests, turrets, traps and other objects in 15° steps, so they don't have to sit square). **T** switches to ready-made buildings: shelter, cabin, big cabin, watchtower and gatehouse. Left click lays a free blue blueprint of the whole building; then walk up to it and press **E** to build the next piece (hold E to keep going), paid from your pockets and chests in reach. Right click on a blueprint in build mode scraps it. Blueprints are saved, so you can finish one later.

**The horde button.** The yellow post with the red button by the spawn point calls a horde of mutants right away, day or night. It pays the kill bounty.

**More pieces.** Half walls (1.2 m) and low walls (0.7 m) to shoot over, a gun slit wall with a slot at eye height, **pillars** that stand on the corners of the grid and hold up floors in the open, a **floor with a trapdoor** (E opens the hatch; put a ladder under it), **triangle foundations and roofs** for rounder towers, and a **metal door** (8 scrap, 4 nails, 1400 hit points).

**Support.** Every piece has a **support** value counted from the ground: 100% at ground level, 10 points less for each piece resting on what is below it (a floor on walls, a wall on a wall), and 25 less for a floor hanging off the floor next to it. Heavier tiers lose more (scrap metal ×1.15, stone ×1.4, concrete ×1.3). Below **20%** a piece can't be built, and if it drops below that (a wall under it breaks), it comes down in a shower of chunks. So a floor can reach about three squares out from the nearest wall. Build mode shows the support of an upstairs piece before you build it, the hammer shows it on built pieces, and the hammer won't upgrade a piece if the heavier tier would bring something down.

**Digging.** Make a **shovel** at the workbench (3 scrap, 2 wood) or buy one at the shop ($40). Around the base (within about 48 m of the flag) the ground can be dug: hold the shovel and left click to dig out the 1 m square under the crosshair (a yellow square shows it). Each dig lowers it 25 cm and gives you a bag of **sand**; right click fills it back in with a bag of sand. Digging a row of squares makes a level trench. You hit **bedrock** 4 m down, and you can pile sand up to 2 m high. Careful near your base: dig the sand out from under a wall or foundation and it falls down, with everything it held up. Chests, traps and other things on the sand just settle into the hole. Nothing can be dug under the flag, the shop terminal, rocks or wrecks.

**Pits and trenches.** Mutants walk or fall into holes and climb out slowly, but a wall of sand **2 m high or more** holds them: a trench 2.25 m deep (9 digs per square) round your walls is a real defence. Put a **spiked pit** (build mode) in a hole 1 m deep or more, and a **ladder** in your own trench so you can climb out (walk into it and hold W). **Sandbag walls** are made of sand and cloth. A new foundation fills the sand under it.

**Mining.** Below 1.5 m the shovel brings up **clay**, and below 2.75 m comes solid **stone**, which needs a **pickaxe** (workbench: 4 scrap, 2 wood). The pickaxe also breaks rocks out in the desert: a stone per hit, more hits for bigger rocks. Stone and clay upgrade pieces to the **stone** tier (1000 hit points), between scrap metal and concrete. A **metal detector** (workbench: 6 scrap, 4 nails, 2 cloth) beeps faster as you get near a cache buried around the base; at the steady tone, dig that square 1 m down for a bag of ammo, scrap and supplies. Six are buried at the start and another turns up most mornings.

**Water well.** Dig a shaft at least **3.5 m** deep (the last metre is stone, so bring the pickaxe; looking straight down into a hole reaches its bottom), then build a **water well** over it (8 stone, 4 wood, 2 scrap). It fills a bottle of water every 75 seconds, up to 6; press **E** on it to take them. Hard work costs **stamina**: a dig 7 (filling 3.5), a pickaxe hit 9, building a piece 6, a hammer repair or upgrade 5. Out of breath, you have to wait.

**Nights.** At 18:30 a siren warns you. At 20:00 a wave of mutants comes in from the edge of the map and marches on the base. Close to you they know where you are, walls or not, and tear through anything in their way. The wave ends when all are dead or at dawn. A summary shows your kills and your pay.

| Mutant | What to know |
|---|---|
| Walker | Slow and steady. 3 pipe hits or 3 pistol shots. |
| Runner (night 2+) | Faster than you walk, weak. Sprint or shoot. |
| Spitter (night 3+) | Keeps its distance and lobs acid that also eats walls. Hide, then rush it. |
| Brute (night 4+) | Huge, slow, very tough, wrecks walls in a few blows. Kill it before it reaches them. |

**Weapons.** Melee costs stamina. Guns are loud and bring mutants running. Hold **right click** to aim (the rifle has a scope), **R** reloads. Headshots do double damage.

**Defences.** Spike barricades, spike strips, barbed wire (slows them) and landmines. An electric fence and floodlights need power from a fuel generator (fuel cans come from car trunks): within 4 m they plug straight in, further away they need a **cable**. Make cable at the workbench (1 scrap, 1 cloth for 6), hold it, left click the generator and then the light, fence, **power switch** or turret (a cable costs one per 2 m, 24 m at most; right click takes a piece's cables back up). Power passes through switches only when they are on (E). A turret on power turns and fires 40% faster. At night an open gate closes by itself 8 seconds after you leave it, and **R** locks a shut metal door (locked, it takes half damage). A fire pit burns mutants that walk through it. Auto-turrets stand on tall masts and shoot anything they can see within 22 m, over your walls, using the 9mm rounds you load into them with **E**.

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
| Left click | Swing, shoot, build (hold and drag for a line), use the hammer, or dig with the shovel |
| Right click | Aim a gun; hammer: demolish; shovel: fill; build mode: undo |
| R | Reload; build mode: turn the piece; hammer: repair everything nearby; lock or unlock a metal door |
| G | Build mode: pick a piece up and move it; hammer: upgrade everything like it nearby |
| Z / X | Build mode: turn the piece back / on (objects in 15° steps) |
| T | Build mode: switch between single pieces and ready-made buildings |
| E | Search, open, use (gates, chests, workbench, generator, fire pit, turret, switch, well, shop) |
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
