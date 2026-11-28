extends CanvasLayer
## The shop screen: your cash and two pages, the counter (bought straight into
## your pockets), drone orders (flown to your landing pad), base upgrades and
## the market (sell your harvest, buy food). Click to buy. E, Tab or Esc closes it.

const UI = preload("res://scripts/menu_ui.gd")
const Items = preload("res://scripts/items.gd")
const Goals = preload("res://scripts/goals.gd")

signal bought(index: int, left: Dictionary)
signal ordered(index: int)
signal upgrade_bought(id: String)
signal market_sold(item: String, count: int, cash: int)
signal market_bought(item: String)

const PAGES := ["Counter", "Drone orders", "Base upgrades", "Market"]

var shop  # Shop
var market  # Market (the sell and food pages)
var inventory  # Inventory
var _root: Control
var _cash: Label
var _buttons: Array[Button] = []
var drone_buttons: Array[Button] = []
var _counter: VBoxContainer
var _drone_page: VBoxContainer
var _drone_note: Label
var _tabs: Array[Button] = []
var _upgrade_page: VBoxContainer
var upgrade_buttons := {}
var _market_page: VBoxContainer
var _market_news: Label
## Item -> {"name": Label, "price": Label, "one": Button, "all": Button}
var market_rows := {}
## Item -> its buy button.
var market_buy_buttons := {}


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var col := UI.panel(_root, 760)
	col.add_theme_constant_override("separation", 8)  # the counter page must fit a 720 px window
	UI.title(col, "Shop terminal", 24)
	_cash = UI.title(col, "", 20)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	for t in PAGES:
		var tb := UI.button(tabs, t, show_page.bind(PAGES.find(t)))
		tb.custom_minimum_size = Vector2(176, 36)
		tb.toggle_mode = true
		_tabs.append(tb)
	_counter = VBoxContainer.new()
	_counter.add_theme_constant_override("separation", 8)
	col.add_child(_counter)
	_drone_page = VBoxContainer.new()
	_drone_page.add_theme_constant_override("separation", 8)
	col.add_child(_drone_page)
	_drone_note = UI.note(_drone_page, "")
	_upgrade_page = VBoxContainer.new()
	_upgrade_page.add_theme_constant_override("separation", 8)
	col.add_child(_upgrade_page)
	for id in shop.UPGRADES:
		var b := UI.button(_upgrade_page, "", buy_upgrade.bind(id))
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(0, 54)
		upgrade_buttons[id] = b
	_build_market_page(col)
	var dgrid := GridContainer.new()
	dgrid.columns = 3
	dgrid.add_theme_constant_override("h_separation", 6)
	dgrid.add_theme_constant_override("v_separation", 4)
	_drone_page.add_child(dgrid)
	for i in shop.DRONE.size():
		var b := UI.button(dgrid, "", order.bind(i))
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(244, 40)  # 9 rows must fit a 720 px window
		drone_buttons.append(b)
	var cat := ""
	var grid: GridContainer
	for i in shop.CATALOG.size():
		var e: Dictionary = shop.CATALOG[i]
		if e.cat != cat:
			cat = e.cat
			var l := Label.new()
			l.text = cat
			l.add_theme_font_size_override("font_size", 17)
			l.add_theme_color_override("font_color", UI.ACCENT)
			_counter.add_child(l)
			grid = GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 4)
			_counter.add_child(grid)
		var b := UI.button(grid, "%s\n$%d" % [e.name, e.price], buy.bind(i))
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(182, 40)
		_buttons.append(b)
	UI.note(col, "Cash comes in after each night and from the market.   E or Esc closes.")
	_root.visible = false
	shop.cash_changed.connect(func(_c): refresh())


func is_open() -> bool:
	return _root.visible


## The market page: one row per thing the market buys, then the food it sells.
func _build_market_page(col: VBoxContainer) -> void:
	_market_page = VBoxContainer.new()
	_market_page.add_theme_constant_override("separation", 6)
	col.add_child(_market_page)
	if market == null:
		return
	_market_news = UI.note(_market_page, "")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	_market_page.add_child(grid)
	for item in market.GOODS:
		var nl := Label.new()
		nl.custom_minimum_size = Vector2(250, 0)
		nl.add_theme_font_size_override("font_size", 15)
		grid.add_child(nl)
		var pl := Label.new()
		pl.custom_minimum_size = Vector2(150, 0)
		pl.add_theme_font_size_override("font_size", 15)
		grid.add_child(pl)
		var one := UI.button(grid, "Sell 1", sell.bind(item, 1))
		one.add_theme_font_size_override("font_size", 13)
		one.custom_minimum_size = Vector2(90, 28)
		var all := UI.button(grid, "", sell.bind(item, -1))
		all.add_theme_font_size_override("font_size", 13)
		all.custom_minimum_size = Vector2(190, 28)
		market_rows[item] = {"name": nl, "price": pl, "one": one, "all": all}
	var l := Label.new()
	l.text = "Fresh food (at twice today's price)"
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", UI.ACCENT)
	_market_page.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_market_page.add_child(row)
	for item in market.FOR_SALE:
		var b := UI.button(row, "", buy_food.bind(item))
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(176, 40)
		market_buy_buttons[item] = b


## Sells n of an item from your pockets (-1 = all of it).
func sell(item: String, n: int) -> void:
	if n < 0:
		n = inventory.count_of(item)
	var got: int = market.sell(item, n, inventory, shop)
	if got > 0:
		market_sold.emit(item, n, got)
	refresh()


func buy_food(item: String) -> void:
	if market.buy(item, inventory, shop):
		market_bought.emit(item)
	refresh()


## 0 = counter, 1 = drone orders, 2 = base upgrades, 3 = market (true/false also work for the first two).
func show_page(page) -> void:
	var p := int(page)
	_counter.visible = p == 0
	_drone_page.visible = p == 1
	_upgrade_page.visible = p == 2
	_market_page.visible = p == 3
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(i == p)
	refresh()


func buy_upgrade(id: String) -> void:
	if shop.buy_upgrade(id):
		upgrade_bought.emit(id)
	refresh()


func open() -> void:
	_root.visible = true
	show_page(0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	_root.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func buy(i: int) -> void:
	var left = shop.buy(i, inventory)
	if left != null:
		bought.emit(i, left)
	refresh()


func order(i: int) -> void:
	if shop.order(i):
		ordered.emit(i)
	refresh()


func refresh() -> void:
	_cash.text = "Cash: $%d" % shop.cash
	for i in _buttons.size():
		_buttons[i].disabled = not shop.can_buy(i)
	for id in upgrade_buttons:
		var u: Dictionary = shop.UPGRADES[id]
		var n: Dictionary = shop.next_level(id)
		var have: int = shop.upgrades[id]
		var b: Button = upgrade_buttons[id]
		if n.is_empty():
			b.text = "%s: done (%s)" % [u.name, u.levels[-1].text]
		else:
			b.text = "%s %d/%d: %s\n$%d" % [u.name, have + 1, u.levels.size(), n.text, n.price]
		b.disabled = not shop.can_upgrade(id)
	_refresh_market()
	if shop.drone == null:
		return
	var has_pad: bool = shop.drone.pad_position() != null
	if not has_pad:
		_drone_note.text = "Build a drone landing pad (build mode) to order by drone."
	elif shop.drone.phase != "idle":
		_drone_note.text = "The drone is on its way. New orders go on the next flight."
	else:
		_drone_note.text = "Orders are flown to your landing pad in about 20 seconds. Blueprints unlock new builds."
	for i in drone_buttons.size():
		var e: Dictionary = shop.DRONE[i]
		var owned := false
		for item in e.items:
			if shop.BLUEPRINTS.has(item) and shop.blueprint_owned(item):
				owned = true
		var price := "Owned" if owned else "$%d" % e.price
		if not shop.order_unlocked(i):
			price = "Locked: reach %s green" % Goals.at_text(int(e.goal))
		drone_buttons[i].text = "%s\n%s" % [e.name, price]
		drone_buttons[i].disabled = not shop.can_order(i)


func _refresh_market() -> void:
	if market == null:
		return
	var best: String = market.best_today()
	_market_news.text = "Prices change every morning and drop as you sell. Wanted today: %s." % Items.display_name(best).to_lower()
	for item in market_rows:
		var r: Dictionary = market_rows[item]
		var have: int = inventory.count_of(item)
		r.name.text = "%s   (you have %d)" % [Items.display_name(item), have]
		var t: String = market.trend(item)
		r.price.text = "$%d each%s" % [market.price(item), "  (high)" if t == "high" else ("  (low)" if t == "low" else "")]
		r.price.add_theme_color_override("font_color", Color(0.6, 0.95, 0.55) if t == "high" else (Color(0.95, 0.6, 0.5) if t == "low" else Color(0.92, 0.9, 0.85)))
		r.one.disabled = have <= 0
		r.all.disabled = have <= 0
		r.all.text = "Sell all ($%d)" % market.sale_value(item, have) if have > 0 else "Sell all"
	for item in market_buy_buttons:
		var b: Button = market_buy_buttons[item]
		b.text = "%s\n$%d" % [Items.display_name(item), market.buy_price(item)]
		b.disabled = not market.can_buy(item, shop)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or get_tree().paused:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()
