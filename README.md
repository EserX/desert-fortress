# Desert Fortress

A 3D low-poly survival and fortress-defence game for Linux, made with Godot 4.5. Scavenge the desert by day, build and arm a fortress around the flag, and survive a bigger mutant wave every night. Each night pays cash you spend at the shop terminal on supplies, weapons, drone deliveries and base upgrades. Now also: turning the desert green from a main well at the centre, farming it and selling the harvest at the market, and hunting the animals the green land draws in (by night the water draws the mutants); claiming hidden oases as outposts, and green milestones that end with the rain coming back (then free play). A peaceful mode leaves out the mutants altogether.

**Current version: v2.8.9.** See [ROADMAP.md](ROADMAP.md) for the plan and [DEVLOG.md](DEVLOG.md) for what changed in each update.

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

**Cold nights, wounds, food and weight.** The fourth bar is **warmth**. From 21:00 to 05:00 the desert gets cold: in the open your warmth runs down in about two and a half minutes. Stand within 5 m of a **burning fire pit** to warm up fast; a **roof** over your head keeps some of the cold off, and a roof with walls all round (inside a cabin) keeps it all off. Below a third you are **cold** (hungrier, no healing); at nothing you freeze and lose health. By day you warm back up. **Walker and runner claws** can open **bleeding wounds** (the HUD says so): each wound costs a little health every second for two minutes, and you don't heal while bleeding. A **bandage** or medkit (F) stops all bleeding. **Fresh food goes bad:** each morning some raw meat (half), cooked meat and stew, melons, dragon fruit and prickly pears turn into **rotten food** (eat it only if you must: it fills a little and makes you sick). Food in a **storage chest** rots half as often; canned food, millet, dates, olives and flatbread keep. **A heavy bag** (over half your 50 kg) makes digging, mining and chopping cost more stamina and makes you climb ladders and jump slower, up to twice as hard when you carry too much.

**Building.** Press **B** near the flag. Pick a piece with the mouse wheel (or 1–9), turn it with **R**, build with left click. Everything must be inside the ring of stakes (the base zone). Right click undoes a piece built in the last minute. With the **hammer** selected, left click a piece to repair it or upgrade it (wood, then scrap metal, then stone, then concrete), and right click twice to demolish it for half the cost back. Upstairs pieces need walls or floors under them; if those break, they fall.

**Faster building.** In build mode, hold left click on the first square (or edge) and let go on the last to build a whole **line** of up to 12 walls, foundations, floors or pillars, each one paid as it goes. With the hammer, **R** repairs everything damaged within 8 m and **G** upgrades every piece of the same tier as the one you look at within 8 m; both pay from your pockets and any chest within reach. In build mode, **G** picks up the piece you look at (a chest keeps its contents, a turret its ammo, damage stays) and left click puts it down elsewhere for free; G again (or leaving build mode) puts it back. Foundations and pieces that hold something up can't be moved.

**Ready-made buildings and turning.** In build mode, **Z / X** turn the piece (chests, turrets, traps and other objects in 15° steps, so they don't have to sit square). **T** opens the **blueprint menu**: a card with a drawing and the full price of each ready-made building, coloured in the material picked along the top. Click one (or press its number) to pick it; the mouse wheel still steps through them, and T in the menu (or its "Single pieces" card) goes back to single pieces. The buildings: shelter, cabin, big cabin, watchtower, gatehouse, **walled compound** (a 5×5 ring of walls with a gate and gun slits round an open yard) and **bunker with a well** (3×3, gun slits, a metal door and a roof; its middle square is left as sand: dig it 3.5 m deep with the pickaxe and the well goes up last). Left click lays a free blue blueprint of the whole building; then walk up to it and press **E** to build the next piece (hold E to keep going), paid from your pockets and chests in reach. **G** picks the material the building goes up in (wood, scrap metal, stone or concrete): each piece then costs its wooden price plus the hammer upgrades on the way, and goes up straight in that material (ladders, doors and other fixed pieces stay as they are). Right click on a blueprint in build mode scraps it. Blueprints are saved, so you can finish one later.

**Gathering and machines.** Chop trees in the palm groves with an **axe** (left click) for logs, and pick up loose stones with **E**. Logs split into 2 wood at the workbench, or 5 at a **sawmill**. Machines come by drone from the shop terminal: the **sawmill** (logs to wood), the **rock crusher** (stone to cement) and the **nail press** (scrap to nails). Place one next to a generator or cable it to one, then **E** loads it and takes what it made. Generators start up by day for machines with work. Put a **storage chest** on a square next to a machine or furnace (sides or corners, same floor) and what it makes goes straight into the chest, so it keeps working while you are away; machines never take anything out of the chest. **Log stakes** are a trap made from logs. Felled trees grow back after 3 days.

**The furnace and steel tools.** Build a **furnace** in build mode (10 stone, 4 clay). Hold **wood** (40 s of fire each) or **logs** (2 minutes) and press **E** to fuel it, then hold what you want to smelt and press **E** to load it (30 at a time, one kind at a time): **2 scrap make a metal plate** (10 s), **3 sand make a glass** (8 s) and **2 clay make 2 bricks** (6 s). It only burns fuel while it is smelting, glows while it works and warms you like a fire pit. **E** always takes out what is ready. With what it makes:
- **Brick wall** (build mode: 12 bricks, 2 clay): 1200 hit points straight away, holds up floors like a wall, mended with bricks. The **brick wall with a glass window** (9 bricks, 1 glass pane, 2 clay; 1000 hit points) lets you see out but nothing gets through.
- **Glass pane** (workbench: 2 glass, 1 wood) for the window wall.
- **Steel shovel** (workbench: 3 metal plates, 2 wood): a shovel that digs twice as fast for less stamina.
- **Sledgehammer** (workbench: 4 metal plates, 3 wood, 1 cloth): left click a building piece to knock it down in **one blow** (half the cost back, like the hammer), or a rock to smash off 3 stone at once. At anything else it is a slow, heavy weapon that throws mutants back.

**How mutants attack.** Wave mutants look for the cheapest way into the base: an open gate first, otherwise the weakest wall on the shortest way in, and the whole wave goes for the same spot. Deep trenches (2 m or more) and traps make them go round. Brutes ignore all that and walk straight through. In build mode, an upstairs piece's preview turns yellow, then orange, as its support gets weaker. While placing a piece that works at a distance, a dashed **circle** on the sand shows its reach: amber for a turret (22 m), blue for a sprinkler (5 m), teal for a dew collector (8 m) and pale blue for a weather station's showers (40 m). The ones already built nearby show their circles too, fainter (sprinklers and dew collectors show each other's, as both water), so you can see gaps and overlaps. Point the hammer at one already built to see its circle again. For a sprinkler or dew collector, the build line also counts the 4 m squares it would water and how many of them are new (not already watered by another), and the hammer on a built one says how many of its squares only it waters (if none, it is spare and could go elsewhere).

**The horde button.** The yellow post with the red button by the spawn point calls a horde of mutants right away, day or night. It pays the kill bounty.

**More pieces.** Half walls (1.2 m) and low walls (0.7 m) to shoot over, a gun slit wall with a slot at eye height, **pillars** that stand on the corners of the grid and hold up floors in the open, a **floor with a trapdoor** (E opens the hatch; put a ladder under it), **triangle foundations and roofs** for rounder towers, and a **metal door** (8 scrap, 4 nails, 1400 hit points).

**Support.** Every piece has a **support** value counted from the ground: 100% at ground level, 10 points less for each piece resting on what is below it (a floor on walls, a wall on a wall), and 25 less for a floor hanging off the floor next to it. Heavier tiers lose more (scrap metal ×1.15, stone ×1.4, concrete ×1.3). Below **20%** a piece can't be built, and if it drops below that (a wall under it breaks), it comes down in a shower of chunks. So a floor can reach about three squares out from the nearest wall. Build mode shows the support of an upstairs piece before you build it, the hammer shows it on built pieces, and the hammer won't upgrade a piece if the heavier tier would bring something down.

**Digging.** Make a **shovel** at the workbench (3 scrap, 2 wood) or buy one at the shop ($40). Around the base (within about 48 m of the flag) the ground can be dug: hold the shovel and left click to dig out the 1 m square under the crosshair (a yellow square shows it). Each dig lowers it 25 cm and gives you a bag of **sand**; right click fills it back in with a bag of sand. Digging a row of squares makes a level trench. You hit **bedrock** 4 m down, and you can pile sand up to 2 m high. Careful near your base: dig the sand out from under a wall or foundation and it falls down, with everything it held up. Chests, traps and other things on the sand just settle into the hole. Nothing can be dug under the flag, the shop terminal, rocks or wrecks.

**Pits and trenches.** Mutants walk or fall into holes and climb out slowly, but a wall of sand **2 m high or more** holds them: a trench 2.25 m deep (9 digs per square) round your walls is a real defence. Put a **spiked pit** (build mode) in a hole 1 m deep or more, and a **ladder** in your own trench so you can climb out (walk into it and hold W). **Sandbag walls** are made of sand and cloth. A new foundation fills the sand under it.

**Mining.** Below 1.5 m the shovel brings up **clay**, and below 2.75 m comes solid **stone**, which needs a **pickaxe** (workbench: 4 scrap, 2 wood). The pickaxe also breaks rocks out in the desert: a stone per hit, more hits for bigger rocks. Stone and clay upgrade pieces to the **stone** tier (1000 hit points), between scrap metal and concrete. A **metal detector** (workbench: 6 scrap, 4 nails, 2 cloth) beeps faster as you get near a cache buried around the base; at the steady tone, dig that square 1 m down for a bag of ammo, scrap and supplies. Six are buried at the start and another turns up most mornings.

**Water well.** Dig a shaft at least **3.5 m** deep (the last metre is stone, so bring the pickaxe; looking straight down into a hole reaches its bottom), then build a **water well** over it (8 stone, 4 wood, 2 scrap). It fills a bottle of water every 75 seconds, up to 6; press **E** on it to take them. Hard work costs **stamina**: a dig 7 (filling 3.5), a pickaxe hit 9, building a piece 6, a hammer repair or upgrade 5. Out of breath, you have to wait.

**The main well and watering.** The big stone well next to the flag holds 200 litres and fills up again every morning (deepen it in the shop for more). Make a **watering can** (workbench: 2 scrap, 2 nails), fill it with **E** at the main well and left click the sand to pour. The ground is a grid of 4 m squares: 6 L turns sand into **soil**, and soil that gets 4 L in a day turns a little greener each morning (grass, then small plants). With the **hand pump** upgrade, lay **water pipes** from the main well to **sprinklers** (build mode), which water the squares round them by day. The map (**M**) shows your pipes, sprinklers, purifiers and dew collectors: blue when water reaches them, grey when it doesn't, dark for a sprinkler you turned off. Turn the **mouse wheel** on the map to zoom in on the base (x1, x2, x4, x8).

**Farming.** Seeds come by drone (shop terminal, Drone orders). Hold a seed packet and left click **soil** to dig a seed bed and plant it (four beds to a square). A plant grows one day each morning if its square got enough water the day before (the prompt says how much). At **13:00** the midday heat hurts plants on squares that are still dry, and a plant hurt twice without water in between dies (E clears it). Look at a plant to see how it is doing, and press **E** to harvest it when it is ripe.

| Crop | Days | Water a day | What it gives |
|---|---|---|---|
| Millet | 3 | 4 L | millet (food) |
| Melon | 4 | 6 L | melons (food and drink) |
| Cotton | 4 | 4 L | cotton: 3 make 2 cloth at the workbench |
| Agave | 5 | 2 L | fibre (3 make rope); never minds the heat |
| Fast acacia | 4 | 4 L | 3 logs |
| Desert marigold | 2 | 4 L | flowers, again every 2 days; crops within 6 m grow half as fast again and the soil round them greens faster |
| Date palm | 6 | 4 L | dates every 3 days; shades plants within 3.5 m, turns the sand round it to soil and greens it, and once grown survives dry days |
| Saffron (exotic) | 4 | 4 to 6 L | saffron; needs shade at midday (a roof or a date palm) and rots with more than 6 L |
| Dragon fruit (exotic) | 5 | 6 L | dragon fruit every 3 days |

Eat millet, melons, dates and dragon fruit with **F**. Sell the harvest at the market (shop terminal, Market page): exotic crops and flowers bring the most. Digging up a bed uproots its plant.

**Green and livable.** The HUD (top right) and the map (**M**) show how much of the whole desert is **green** and how **livable** your base is, out of 100. The livable score has five parts of up to 20 points, all counted inside the build zone: **shade** (4 for each grown date palm, 2 for each roof), **water** (6 for the main well, more for deepening it, 3 for the hand pump, 2 for each dug well), **food** (2.5 for each living millet, melon, date palm or dragon fruit plant, 3 for a fire pit), **plants** (2 for each fully green square) and **shelter** (1 for each wall, floor or roof, 2 each for a chest and a workbench). The map lists the parts. Milestones give comforts while the score holds them:
- **25, Settled:** you heal twice as fast at the base.
- **50, Cool camp:** you rest through the midday heat at the base (no faster thirst there).
- **75, Homestead:** your buildings mend 10% of their hit points every morning.

Green land spreads by itself: a fully green square keeps the sand next to it turning to soil (in about 3 mornings), ready for your water. Grown **date palms** drop saplings on watered soil within 4 m now and then, so a palm grove grows if you keep it watered.

**Oases and outposts.** Three to five **oases** lie hidden out in the desert, 85 to 195 m from the base (the map marks each one once you've been within 35 m). Each has a **spring** (**E** to drink your fill and fill the watering can), **reeds** to cut (**E**, 8 a day; 3 reeds make 2 fibre at the workbench), a **clay bank** to dig (**E**, 6 a day) and an **old stash** of rare seeds (saffron, dragon fruit, date palm). Mutant **guards** come out when you get within about 55 m. Some oases have a **mutant nest**: while it stands the land round it stays dead, the palms are bare stumps and it keeps breeding guards. Bring a **fuel can** and press **E** on the nest to burn it out (or throw a molotov or a pipe bomb at it); then the spring brings the oasis back to life over a few mornings. With the nest gone and the guards dead, press **E** on the marker post to **claim** the oasis as an **outpost** (6 wood, 2 cloth): it gets its own build zone of 16 m round the post (build there just like at the base), and its spring waters the land further out every morning. A **sprinkler** built within 9 m of the pond's middle runs on the spring by day, with no hand pump and no water from the main well; pipe more sprinklers on from it to green the rest of the outpost's zone (spring water doesn't go beyond the zone). The green round wild oases doesn't draw the night waves, but a claimed outpost's does, and an outpost's buildings don't count for the base's livable score.

**Goals and the ending.** The green % of the whole desert (on the HUD as "Green 0.3% / 1%", with the next goal) has four milestones, shown in the GOALS panel on the map (M). Each one is announced and unlocks new drone orders at the shop terminal (locked orders say which goal they need):
- **1%, First green:** olive saplings (a fruit tree: shade, olives, pushes the green out, needs only 2 L a day) and prickly pear pads (hardy food, 2 L a day).
- **2.5%, Green belt:** the **dew collector** machine: build it anywhere you can build (base or outpost), and every morning it waters the ground within 8 m with a day's water, no pipes needed. Also the **water purifier**: cable it to a generator and it turns well water into bottles of drinking water (2 L a bottle, one every 12 s). Set it within 6 m of the main well and it fills its 30 L tank from the well by itself (that water no longer greens the land that day, and counts as water drawn for the night). Set it by the pond of an outpost you've claimed (within 9 m of the pond's middle) and it fills from the spring instead, which never runs dry and takes nothing from the main well. Anywhere else, lay a **water pipe** to it from the main well (it needs the hand pump, and can run through sprinklers on the way) and it draws from the well's store like a sprinkler; at an outpost, a pipe from a sprinkler by the spring brings it spring water. Or press E with a watering can to pour water in. Put a storage chest next to it and the bottles go straight in.
- **5%, Clouds gather:** the **weather station**: most mornings (60%) a rain shower falls on everything within 40 m of it, enough to turn sand to soil in one go. The rain stops at 10:00.
- **10%, The rain returns:** the ending. Rain comes back over the whole desert: on about half the mornings every watered square on the map gets rain, and green land keeps spreading from there. Then you keep playing (free play).

Milestones stay reached even if the green fades later. You can't get to 10% with the main well alone: dew collectors, weather stations at the base and at outposts, springs and the spreading green get you there.

**Animals and hunting.** Water brings life. Between 07:00 and 17:00 animals come in from the desert to graze on your green land and drink at the main well: the greener the land round the base, the more come (about one gazelle for every 3 fully green squares, a jackal for every four grazers, birds in flocks of three). **Gazelles** bolt when you get within 20 m (10 m crouching), so creep up or use the rifle. **Jackals** come for you and bite when you get close, and run when badly hurt. **Birds** peck on the green and fly off when disturbed. Gunshots scare everything nearby. Look at a dead animal and press **E** to butcher it for **raw meat** (a gazelle gives 3). Raw meat has to be cooked: light a **fire pit** with wood, then **E** cooks up to 5 batches of what you carry (each burns 10 seconds of the fire): raw meat into **cooked meat** (a big meal), 2 millet and a water bottle into 2 **flatbread** (keeps forever), and a cooked meat with a melon into 2 bowls of **stew** (food and water). At dusk the animals head back out into the desert.

**Nights.** At 18:30 a siren warns you. At 20:00 a wave of mutants comes in from the edge of the map and marches on the **main well**. The water draws them: on top of the night's usual number comes one more mutant for every 40 L you drew from the main well that day and for every 4 fully green squares (12 more at most; the radio says how many). Every third group goes for your **fields** instead, and any wave mutant at the base goes for the nearest plant or water pipe as well as your walls: a mutant standing on a plant tramples it, and one on a pipe tears it up in a couple of seconds. The night's summary counts what they wrecked. Close to you they know where you are, walls or not. They find their way round your walls: through an open gate if there is one, otherwise they all go for the weakest wall or gate (a damaged or wooden one before stone), and they walk round deep trenches and, if it's short, round barbed wire and spikes. Brutes don't bother and come straight through. The wave ends when all are dead or at dawn. A summary shows your kills and your pay.

| Mutant | What to know |
|---|---|
| Walker | Slow and steady. 3 pipe hits or 3 pistol shots. |
| Runner (night 2+) | Faster than you walk, weak. Sprint or shoot. |
| Spitter (night 3+) | Keeps its distance and lobs acid that also eats walls. Hide, then rush it. |
| Brute (night 4+) | Huge, slow, very tough, wrecks walls in a few blows. Kill it before it reaches them. |
| Behemoth (every 10th night) | A boss twice your height with 2,400 health. Walks straight through walls, tearing one down in a few blows, and its fist sends you flying. Deep pits hold it. Worth $300 and drops scrap and metal plates. |

**Events.** Some days bring trouble by daylight (from day 3 on):
- **Sandstorms:** a banner warns you an hour ahead and names the side it comes from. In the storm the sky turns brown and you see only about 30 m, the wind howls, and a band of mutants comes in on the wind and heads for the main well (they see as little as at night). Drifting sand slowly fills the holes and trenches you dug (but not the ground within about 3 m of your buildings, so wells and spiked pits are safe). When the storm passes, the mutants in it sink back into the sand. The HUD shows "Sandstorm".
- **Raids on outposts:** with an outpost claimed, a band of mutants sometimes attacks it by day (the banner says which one and how far). They wreck what you built there and trample its fields. Kill them all for $40 plus $10 a raider; any still there at 19:00 slink off. The HUD counts them.
- **The Behemoth:** every tenth night (10, 20, 30...) a Behemoth walks at the back of the wave. The dusk banner warns you and its health shows on the HUD.

In Peaceful mode sandstorms still blow (and fill holes) but bring no mutants, and there are no raids or Behemoths.

**Weapons.** Melee costs stamina. Guns are loud and bring mutants running. Hold **right click** to aim (the rifle has a scope), **R** reloads. Headshots do double damage.

**Throwing.** Hold a **stone**, a **molotov** or a **pipe bomb** and hold **left click** to draw back; let go to throw. The longer you hold (up to about a second), the further it flies. Everything flies in an arc and bounces off walls and the ground.
- **Stone:** bruises and shoves a mutant (or an animal) it hits hard, then lies where it stopped; pick it up again with **E** (stones landing close together make one pile).
- **Molotov** (workbench: 1 fuel can, 1 cloth, 2 water bottles for 2): breaks on the first thing it hits and leaves a pool of fire for 8 seconds that burns and slows mutants. Thrown at a **nest** (within about 4 m) it sets it alight, no fuel can needed. Don't stand in it.
- **Pipe bomb** (workbench tier 2: 2 scrap, 4 nails, 1 fuel can): bounces and rolls, and blows up 2.5 seconds after you throw it, harder than a landmine (it hurts you too, and your own walls within 3.5 m). It also burns out a nest close by.

Dropped bags (**Q**) are tossed a step ahead, fall and roll, and blasts throw them about.

**Defences.** Spike barricades, spike strips, barbed wire (slows them) and landmines. An electric fence and floodlights need power from a fuel generator (fuel cans come from car trunks): within 4 m they plug straight in, further away they need a **cable**. Make cable at the workbench (1 scrap, 1 cloth for 6), hold it, left click the generator and then the light, fence, **power switch** or turret (a cable costs one per 2 m, 24 m at most; right click takes a piece's cables back up). Power passes through switches only when they are on (E). A turret on power turns and fires 40% faster. At night an open gate closes by itself 8 seconds after you leave it, and **R** locks a shut metal door (locked, it takes half damage). A fire pit burns mutants that walk through it. Auto-turrets stand on tall masts and shoot anything they can see within 22 m, over your walls, using the 9mm rounds you load into them with **E**.

**Cash and the shop.** Every night pays for kills, for surviving, and for how much of the base still stands (more if you kill the whole wave). The **shop terminal** next to the flag has four pages:
- **Counter:** materials, food, weapons, ammo and trap parts, straight into your pockets.
- **Drone orders:** big loads and **blueprints** (auto-turret, electric fence, sandbag wall), flown to a **drone landing pad** you build.
- **Base upgrades:** a bigger build zone, bigger chests, workbench tiers (shotgun at tier 2, rifle and medkits at tier 3), and a radio that tells you at dusk which mutants are coming.
- **Market:** sell crops, flowers, fruit, cotton, fibre, rope, cloth and logs from your pockets (Sell 1 or Sell all), and buy fresh food. Prices change every morning (the page says what is wanted today; green is a good price, red a poor one) and drop with each one you sell, so spread big harvests over a few days: a glut halves overnight. Saffron is worth the most, then dragon fruit; rope is worth more than the fibre it's made from.

**Difficulty.** New game asks for Easy, Normal, Hard or **Peaceful** (wave size, mutant toughness, pay, and how fast you get hungry). Peaceful is terraform only: no mutants roam the desert, no night waves come (each quiet night still pays at dawn), the horde button does nothing, and oases have no guards (nests still keep the land dead until you burn them). Jackals still bite, softly. First-time tips explain each thing as you meet it; turn them on or off in Settings.

## Controls

| Key | Action |
|---|---|
| W A S D / arrows | Move |
| Shift | Sprint (uses stamina; not when carrying too much) |
| Space | Jump |
| Ctrl / C | Crouch (quieter) |
| Mouse | Look |
| Left click | Swing, shoot, throw (hold to throw further), build (hold and drag for a line), use the hammer, dig with the shovel, pour the watering can, or plant seeds |
| Right click | Aim a gun; hammer: demolish; shovel: fill; build mode: undo |
| R | Reload; build mode: turn the piece; hammer: repair everything nearby; lock or unlock a metal door |
| G | Build mode: pick a piece up and move it (ready-made buildings: pick the material); hammer: upgrade everything like it nearby |
| Z / X | Build mode: turn the piece back / on (objects in 15° steps) |
| T | Build mode: blueprint menu of ready-made buildings (T again: single pieces) |
| E | Search, open, use (gates, chests, workbench, generator, fire pit, turret, switch, well, shop), harvest a ripe plant |
| Tab / I | Inventory |
| 1–9, mouse wheel | Hotbar slot (build mode: piece); on the workbench or chest screen the wheel scrolls the recipes or chest slots when the window is too small to show them all |
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
