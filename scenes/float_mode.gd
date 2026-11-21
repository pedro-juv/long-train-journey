class_name FloatMode
extends Node
## FloatMode — modo "trem flutuante" (desktop companion), só no desktop.
##
## Transforma a PRÓPRIA janela do jogo numa janelinha sem borda, transparente
## (o desktop aparece por trás) e sempre por cima das outras, num canto da tela.
## Não existe segunda simulação, save ou loja: é a mesma partida (o mesmo
## GameController/GameState em memória e o mesmo user://save.json), só com
## outro enquadramento da TrainView, a HUD escondida e a loja da HUD reposta
## como painel compacto.
##
##   enter()  liga o modo (botão "FLUTUAR" na HUD ou no menu de opções)
##   exit()   volta à janela normal, no tamanho e lugar de antes (botão ou ESC)
##
## Na janelinha: carvão + botão "+" (abre a loja acima do trem), voltar e
## fechar o jogo. Arrastar em qualquer parte vazia move a janela. Fora do trem
## e da barra, os cliques passam para o que está atrás (mouse passthrough).

signal changed(active: bool)

@export var game_path: NodePath = NodePath("../Game")
@export var view_path: NodePath = NodePath("../TrainView")
@export var hud_path: NodePath = NodePath("../HUD")
@export var options_path: NodePath = NodePath("../OptionsMenu")

## Tamanho da janelinha (px) sem a loja.
const WINDOW_SIZE := Vector2i(560, 290)
## Altura (px) que a janela cresce para cima quando a loja abre.
const SHOP_HEIGHT := 400
## Distância (px) da borda da área útil da tela (acima da barra de tarefas).
const SCREEN_MARGIN := 12
## Quadros por segundo no modo flutuante: suficiente para as rodas e a fumaça,
## e bem mais leve para ficar aberto o dia todo.
const FLOAT_MAX_FPS := 30
## Altura (px, a partir do pé da janela) da área que recebe cliques sem a loja:
## trem, fumaça baixa e a barra do carvão. Acima disso o clique atravessa.
const CLICK_AREA_HEIGHT := 210

var active: bool = false
var shop_open: bool = false

var _saved: Dictionary = {}
var _layer: CanvasLayer
var _coal_label: Label
var _plate: PanelContainer
var _plus: Button
var _restore: Button
var _close: Button
var _skin_id: String = SeasonThemes.DEFAULT


## Só no desktop: no navegador não há como mexer na janela.
static func supported() -> bool:
	return not OS.has_feature("web") and OS.has_feature("pc")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_bar()
	EventBus.stock_changed.connect(_on_stock_changed)
	EventBus.game_loaded.connect(func(): _on_stock_changed(_amount()))
	var view := get_node_or_null(view_path)
	if view:
		view.theme_changed.connect(_apply_skin)
	_apply_skin(SeasonThemes.DEFAULT)


# ---------------------------------------------------------------------------
# Ligar / desligar
# ---------------------------------------------------------------------------

func toggle() -> void:
	if active:
		exit()
	else:
		enter()


func enter() -> void:
	if active or not supported():
		return
	var options := get_node_or_null(options_path)
	if options and options.is_open:
		options.close()
	var win := get_window()
	_saved = {
		"mode": win.mode, "size": win.size, "position": win.position, "borderless": win.borderless,
		"on_top": win.always_on_top, "transparent": win.transparent, "transparent_bg": win.transparent_bg,
		"scale_mode": win.content_scale_mode, "max_fps": Engine.max_fps,
	}
	var screen := win.current_screen
	active = true
	shop_open = false
	if win.mode != Window.MODE_WINDOWED:
		win.mode = Window.MODE_WINDOWED
	# 1 unidade = 1 pixel: a janelinha não encolhe a interface
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.borderless = true
	win.transparent = true
	win.transparent_bg = true
	win.always_on_top = true
	win.size = WINDOW_SIZE
	var usable := DisplayServer.screen_get_usable_rect(screen)
	win.position = usable.end - WINDOW_SIZE - Vector2i(SCREEN_MARGIN, SCREEN_MARGIN)
	Engine.max_fps = FLOAT_MAX_FPS
	get_node(view_path).set_floating(true)
	get_node(hud_path).set_floating(true)
	_on_stock_changed(_amount())
	_layer.visible = true
	_update_click_area()
	changed.emit(true)


func exit() -> void:
	if not active:
		return
	if shop_open:
		_set_shop(false)
	active = false
	_layer.visible = false
	get_node(view_path).set_floating(false)
	get_node(hud_path).set_floating(false)
	var win := get_window()
	win.mouse_passthrough_polygon = PackedVector2Array()
	win.always_on_top = _saved.get("on_top", false)
	win.transparent_bg = _saved.get("transparent_bg", false)
	win.transparent = _saved.get("transparent", false)
	win.borderless = _saved.get("borderless", false)
	win.content_scale_mode = _saved.get("scale_mode", Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	win.size = _saved.get("size", Vector2i(1280, 720))
	win.position = _saved.get("position", win.position)
	var mode: int = _saved.get("mode", Window.MODE_WINDOWED)
	if mode != Window.MODE_WINDOWED:
		win.mode = mode
	Engine.max_fps = _saved.get("max_fps", 0)
	changed.emit(false)


## Fecha o jogo pela janelinha (salva antes, como o X da janela normal).
func quit_game() -> void:
	var game := get_node_or_null(game_path)
	if game:
		game.save_now()
	get_tree().quit()


# ---------------------------------------------------------------------------
# Loja compacta
# ---------------------------------------------------------------------------

func toggle_shop() -> void:
	_set_shop(not shop_open)


## A janela cresce para cima (o trem não sai do lugar) e a loja da HUD
## aparece no espaço novo.
func _set_shop(on: bool) -> void:
	if on == shop_open or not active:
		return
	shop_open = on
	var win := get_window()
	if on:
		var bottom := win.position.y + win.size.y
		var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
		var h := win.size.y + SHOP_HEIGHT
		# cresce para cima; se a janela foi arrastada para perto do topo,
		# desce o necessário para caber inteira na área útil
		var y := clampi(bottom - h, usable.position.y, maxi(usable.position.y, usable.end.y - h))
		win.size = Vector2i(win.size.x, h)
		win.position = Vector2i(win.position.x, y)
	else:
		# o trem volta para onde estava (o pé da janela não se move)
		var bottom := win.position.y + win.size.y
		var h := win.size.y - SHOP_HEIGHT
		win.size = Vector2i(win.size.x, h)
		win.position = Vector2i(win.position.x, bottom - h)
	get_node(hud_path).show_float_shop(on, SHOP_HEIGHT - 6.0)
	_plus.text = "−" if on else "+"
	_plus.tooltip_text = "Fechar o armazém" if on else "Abrir o armazém (loja)"
	_update_click_area()


## Só o trem e a barra (e a loja, se aberta) recebem cliques; o resto da
## janela é transparente também para o mouse.
func _update_click_area() -> void:
	if not active:
		return
	var s := Vector2(get_window().size)
	var top := 0.0 if shop_open else maxf(0.0, s.y - CLICK_AREA_HEIGHT)
	get_window().mouse_passthrough_polygon = PackedVector2Array([Vector2(0, top), Vector2(s.x, top), s, Vector2(0, s.y)])


# ---------------------------------------------------------------------------
# Entrada: arrastar a janela e ESC
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("toggle_options") and not event.is_echo():
		if shop_open:
			_set_shop(false)
		else:
			exit()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.double_click:
			exit()   # duplo clique no trem: volta à janela normal
		else:
			get_window().start_drag()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Barra: carvão + "+", voltar e fechar
# ---------------------------------------------------------------------------

func _amount() -> float:
	var game := get_node_or_null(game_path)
	return game.state.stock.amount if game and game.state else 0.0


func _on_stock_changed(amount: float) -> void:
	if _coal_label:
		_coal_label.text = "%s carvão" % NumFormat.amount(amount)


func _build_bar() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "FloatBar"
	_layer.layer = 15
	_layer.visible = false
	add_child(_layer)

	# bilhete do carvão (canto inferior esquerdo) com o "+" da loja
	_plate = PanelContainer.new()
	_plate.name = "CoalPlate"
	_plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 6)
	_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_plate.tooltip_text = "Carvão em estoque"
	_layer.add_child(_plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_plate.add_child(row)
	_coal_label = Label.new()
	_coal_label.name = "CoalLabel"
	_coal_label.add_theme_font_size_override("font_size", 17)
	_coal_label.add_theme_color_override("font_color", HudSkin.INK)
	_coal_label.custom_minimum_size.x = 120
	_coal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_coal_label)
	_plus = _make_button("+", "Abrir o armazém (loja)", toggle_shop)
	_plus.name = "ShopButton"
	_plus.add_theme_font_size_override("font_size", 20)
	row.add_child(_plus)

	# voltar e fechar (canto inferior direito)
	var right := HBoxContainer.new()
	right.name = "WindowButtons"
	right.add_theme_constant_override("separation", 6)
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_layer.add_child(right)
	_restore = _make_button("", "Voltar à janela normal (ESC ou duplo clique no trem)", exit)
	_restore.name = "RestoreButton"
	_restore.draw.connect(_draw_restore_icon)
	right.add_child(_restore)
	_close = _make_button("", "Fechar o jogo (o progresso é salvo)", quit_game)
	_close.name = "CloseButton"
	_close.draw.connect(_draw_close_icon)
	right.add_child(_close)


func _make_button(text: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(34, 34)
	b.pressed.connect(action)
	return b


func _draw_restore_icon() -> void:
	var c := _restore.size / 2.0 + Vector2(0, -1)
	var r := Rect2(c - Vector2(9, 7), Vector2(18, 14))
	HudSkin.rect(_restore, r.grow(1.5), HudSkin.CREAM)
	HudSkin.rect(_restore, r.grow(-1.0), HudSkin.WOOD_LIGHT)
	HudSkin.rect(_restore, Rect2(r.position, Vector2(r.size.x, 4)), HudSkin.CREAM)


func _draw_close_icon() -> void:
	var c := _close.size / 2.0 + Vector2(0, -1)
	HudSkin.line(_close, c + Vector2(-7, -7), c + Vector2(7, 7), HudSkin.CREAM, 3.0)
	HudSkin.line(_close, c + Vector2(7, -7), c + Vector2(-7, 7), HudSkin.CREAM, 3.0)


func _apply_skin(theme_id: String) -> void:
	_skin_id = theme_id if HudSkin.SKINS.has(theme_id) else SeasonThemes.DEFAULT
	var theme := HudSkin.make_theme(_skin_id)
	for c in [_plate, _restore, _close]:
		c.theme = theme
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ticket := HudSkin.ticket_style()
	ticket.set_content_margin_all(6)
	ticket.content_margin_left = 12
	_plate.add_theme_stylebox_override("panel", ticket)
