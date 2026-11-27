extends Node
## First-time hints: a short tip the first time something happens (a new
## game, the first night, the first time you hold a gun...). Each one is shown
## once ever; turning hints back on in Settings shows them all again.

const HINTS := {
	"welcome": "Welcome to the desert! Search wrecks and ruins with E for supplies. Build your fortress around the flag with B. Every night mutants attack.",
	"loot": "Tab opens your bag. 1–9 picks a hotbar slot; F eats, drinks or uses what you hold.",
	"build": "Build mode: left click builds, R / Z / X turn the piece, the mouse wheel picks another, T switches to ready-made cabins and towers. Stay inside the ring of stakes.",
	"shovel": "Shovel: left click digs out a 1 m patch and gives sand, right click fills it back in. Deeper down comes clay, then stone (that needs a pickaxe). Dig too close to a wall and it falls down.",
	"detector": "Metal detector: walk around the base and listen. The faster it beeps, the closer a buried cache is. At the steady tone, dig that square 1 m down.",
	"hammer": "Hammer: left click a piece to repair or upgrade it, right click twice to demolish it for half the cost back.",
	"throw": "Throwing: hold left click to draw back and let go to throw; the longer you hold, the further it flies. Stones bruise, molotovs leave a pool of fire (and burn nests), pipe bombs bounce and blow up after 2.5 s.",
	"gun": "Hold right click to aim down the sights and R to reload. Gunshots bring mutants running.",
	"dusk": "The siren means night is coming. Get behind your walls, close the gates and have a weapon ready.",
	"mutant": "A mutant has seen you! Left click to fight, or sprint to get away. Crouching keeps you quiet.",
	"cash": "You were paid for the night. Spend the cash at the shop terminal next to the flag.",
	"hurt": "You are hurt. Eat and drink to heal slowly, or use a bandage (F).",
}

var hud  # HUD


## Shows a hint if hints are on and it has not been shown before. Returns true if shown.
func show_hint(id: String) -> bool:
	if not Settings.hints or id in Settings.hints_seen or not HINTS.has(id):
		return false
	Settings.hints_seen.append(id)
	Settings.save_settings()
	if hud:
		hud.show_hint(HINTS[id])
	return true
