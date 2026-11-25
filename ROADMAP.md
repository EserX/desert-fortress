# Roadmap

## Player feedback
<!-- Write bugs, feelings and ideas here. Each run handles these BEFORE roadmap items. -->
<!-- Example: - Sprint feels too slow. - Fell through the ground near a big rock. -->

## Milestones
Each `[ ]` is roughly one development run. Do them in order unless player feedback says otherwise.

### M1: Desert world (v0.1–0.2, done apart from polish)
- [x] Procedural low-poly desert with dunes, mountain ring and a flat base clearing
- [x] First-person movement: walk, sprint with stamina, jump, mouse look
- [x] Props: rocks, cacti, shrubs, car wrecks, ruined walls, base flag
- [x] HUD: compass, distance to base, stamina bar
- [x] Day/night cycle (about 10 min day, 4 min night) with a moving sun and a dark blue night
- [x] Ambient audio: wind loop and footsteps on sand (generated in code or CC0 assets)
- [x] Settings menu: mouse sensitivity, FOV, volume, fullscreen. Pause menu with quit
- [x] Crouch
- [x] Props grounded exactly on the terrain. Better car wrecks
- [x] Drifting dust particles
- [ ] Polish: heat haze at a distance, better cactus and rock variety, a moon disc in the sky

### M2: Scavenging and inventory (v0.4–0.6)
- [ ] Interact key (E) with an on-screen prompt
- [ ] Loot containers in wrecks and ruins: scrap metal, wood, cloth, nails, food, water
- [ ] Inventory with a hotbar (1–9 keys) and a grid inventory (Tab)
- [ ] Loot respawns each day at random spots
- [ ] Save and load (world seed, inventory, player position)

### M3: Building the fortress (v0.7–1.0)
- [ ] Build mode (B): grid-snapped placement preview, rotate, valid/invalid colouring
- [ ] Pieces: foundation, wall, wall with window, doorway and gate, floor, stairs, ramp
- [ ] Material tiers: wood, then scrap metal, then concrete. Each piece has HP
- [ ] Repair and demolish (refunds part of the cost)
- [ ] Building is allowed only inside the base zone (it grows with upgrades later)

### M4: Mutants and waves (v1.1–1.4)
- [ ] Wave director: dusk warning siren, then a wave at night. Each wave is bigger
- [ ] Basic mutant: walks toward the base on a navmesh and attacks walls blocking its path
- [ ] Mutant types: runner (fast, weak), brute (slow, tanky, wrecks walls), spitter (ranged)
- [ ] Player health, damage, death, and respawn at the base
- [ ] End-of-wave summary: kills, damage taken, cash earned

### M5: Defence (v1.5–1.8)
- [ ] Melee weapon (pipe, then machete), with hit feedback
- [ ] Guns: pistol, then shotgun, then rifle. Ammo as an item. Recoil and muzzle flash
- [ ] Traps: spike strip, barbed wire (slows), landmine, fire pit, electric fence
- [ ] Turrets: auto-turret that uses ammo from a connected box
- [ ] Power: generator with fuel for electric fences and lights

### M6: Economy and the online shop (v1.9–2.0)
- [ ] Cash from waves
- [ ] Shop terminal at the base: buy materials, weapons, ammo and trap blueprints
- [ ] Drone delivery: the order drops at a landing pad a few seconds later
- [ ] Base upgrades: bigger build zone, storage, workbench tiers

### Later ideas
- Sandstorm events (low visibility, mutants hide in them)
- Boss mutant every 10 waves
- Crafting at the workbench
- Vehicles (buggy) for faster scavenging
- Exported standalone build (.x86_64) so the game runs without the launcher
