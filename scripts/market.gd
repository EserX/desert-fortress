extends RefCounted
## The market at the shop terminal (v1.15): sell crops, flowers, fruit and
## goods for cash, and buy food back. Prices change every morning (seeded
## from the world seed and the day, so the same world has the same prices),
## and fall when you sell a lot of one thing: each item sold adds to its
## glut, which wears off by GLUT_KEEP every morning.

const Items = preload("res://scripts/items.gd")

## What the market buys: item -> "base" price ($ per item), "sat" (how many
## sold halve the price) and "swing" (how far the daily price moves, 0.3 = ±30%).
const GOODS := {
	"millet": {"base": 3, "sat": 30, "swing": 0.3},
	"melon": {"base": 7, "sat": 15, "swing": 0.3},
	"dates": {"base": 4, "sat": 25, "swing": 0.3},
	"cotton": {"base": 3, "sat": 30, "swing": 0.25},
	"fibre": {"base": 2, "sat": 40, "swing": 0.25},
	"rope": {"base": 9, "sat": 15, "swing": 0.25},
	"cloth": {"base": 1, "sat": 40, "swing": 0.2},
	"log": {"base": 2, "sat": 20, "swing": 0.2},
	"flowers": {"base": 5, "sat": 20, "swing": 0.4},
	"dragon_fruit": {"base": 18, "sat": 10, "swing": 0.45},
	"saffron": {"base": 80, "sat": 4, "swing": 0.5},
}
## What the market sells: food at BUY_MARKUP times today's price.
const FOR_SALE := ["millet", "melon", "dates", "dragon_fruit"]
const BUY_MARKUP := 2.0
## Share of the glut left after each morning.
const GLUT_KEEP := 0.5

signal sold(item: String, count: int, cash: int)

var world_seed := 1337
var day := 1
## Item -> how many sold lately (wears off each morning).
var glut := {}
var _daily := {}
var _daily_day := -1


## How today's price compares with the base price (1.0 = normal).
func daily_factor(item: String) -> float:
	if _daily_day != day:
		_daily.clear()
		_daily_day = day
	if not _daily.has(item):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("market:%d:%d:%s" % [world_seed, day, item])
		var sw: float = GOODS[item].swing
		_daily[item] = rng.randf_range(1.0 - sw, 1.0 + sw)
	return _daily[item]


func _unit_price(item: String, extra_glut: float) -> int:
	var g: float = float(glut.get(item, 0.0)) + extra_glut
	var p: float = GOODS[item].base * daily_factor(item) / (1.0 + g / float(GOODS[item].sat))
	return maxi(int(round(p)), 1)


## What the next one sells for right now.
func price(item: String) -> int:
	return _unit_price(item, 0.0) if GOODS.has(item) else 0


## What selling n of an item would bring (each one sold lowers the next).
func sale_value(item: String, n: int) -> int:
	if not GOODS.has(item):
		return 0
	var total := 0
	for i in n:  # n is at most a pocketful (a few hundred)
		total += _unit_price(item, float(i))
	return total


## What buying one costs today.
func buy_price(item: String) -> int:
	return maxi(int(round(GOODS[item].base * daily_factor(item) * BUY_MARKUP)), 1)


## "high", "low" or "" for today's price against the base (glut included).
func trend(item: String) -> String:
	var r: float = float(price(item)) / float(GOODS[item].base)
	if r >= 1.15:
		return "high"
	if r <= 0.85:
		return "low"
	return ""


## Sells up to n of an item from the inventory and pays the shop. Returns the cash made.
func sell(item: String, n: int, inventory, shop) -> int:
	if not GOODS.has(item):
		return 0
	n = mini(n, inventory.count_of(item))
	if n <= 0:
		return 0
	var cash := sale_value(item, n)
	inventory.remove(item, n)
	glut[item] = float(glut.get(item, 0.0)) + n
	shop.add_cash(cash)
	sold.emit(item, n, cash)
	return cash


func can_buy(item: String, shop) -> bool:
	return shop.cash >= buy_price(item)


## Buys one food item into the inventory. Returns false if you can't afford it
## or it doesn't fit.
func buy(item: String, inventory, shop) -> bool:
	if not FOR_SALE.has(item) or not can_buy(item, shop):
		return false
	if inventory.add(item, 1) > 0:
		return false
	shop.add_cash(-buy_price(item))
	return true


## The item with the best price today against its base (for the market news).
func best_today() -> String:
	var best := ""
	var best_r := 0.0
	for item in GOODS:  # 11 goods
		var r := daily_factor(item)
		if r > best_r:
			best_r = r
			best = item
	return best


func on_morning(d: int) -> void:
	day = d
	for item in glut.keys():
		glut[item] = float(glut[item]) * GLUT_KEEP
		if glut[item] < 0.5:
			glut.erase(item)


func save_data() -> Dictionary:
	return {"glut": glut.duplicate()}


## day: today (prices come from it, so they are not saved).
func load_data(data: Dictionary, d: int) -> void:
	day = d
	glut = {}
	var g = data.get("glut", {})
	if g is Dictionary:
		for item in g:
			var v = g[item]
			if GOODS.has(str(item)) and (v is float or v is int) and float(v) > 0.0:
				glut[str(item)] = minf(float(v), 10000.0)
