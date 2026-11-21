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
## Na janelinha: carvão (pequeno, no canto) com "+" para a loja; música,
## efeitos, voltar e fechar; alça no canto superior esquerdo para mudar o
## tamanho (o trem acompanha). Arrastar em qualquer parte move a janela; fora
## do trem e da barra, os cliques passam para o que está atrás. Tamanho e
## posição da janelinha ficam salvos em user://settings.cfg (seção "float").

signal changed(active: bool)

@export var game_path: NodePath = NodePath("../Game")
@export var view_path: NodePath = NodePath("../TrainView")
@export var hud_path: NodePath = NodePath("../HUD")
@export var options_path: NodePath = NodePath("../OptionsMenu")
@export var audio_path: NodePath = NodePath("../AudioDirector")

## Tamanho padrão da janelinha (px) sem a loja.
const WINDOW_SIZE := Vector2i(520, 250)
## Menor e maior tamanho que o jogador pode escolher.
const MIN_SIZE := Vector2i(280, 140)
const MAX_SIZE := Vector2i(1600, 800)
## Altura (px) que a janela cresce para cima quando a loja abre.
const SHOP_HEIGHT := 400
## Distância (px) da borda da área útil da tela (acima da barra de tarefas).
const SCREEN_MARGIN := 12
## Quadros por segundo no modo flutuante: suficiente para as rodas e a fumaça,
## e bem mais leve para ficar aberto o dia todo.
const FLOAT_MAX_FPS := 30
## Alça de redimensionar (px), no canto superior esquerdo.
const GRIP := 22
const SETTINGS_PATH := "user://settings.cfg"

var active: bool = false
var shop_open: bool = false

var _saved: Dictionary = {}
var _layer: CanvasLayer
var _coal_label: Label
var _coal_box: HBoxContainer
var _plus: Button
var _music: Button
var _sfx: Button
var _restore: Button
var _close: Button
var _grip: Control
var _buttons: Array[Button] = []
var _skin_id: String = SeasonThemes.DEFAULT


## Só no desktop: no navegador não há como mexer na janela.
static func supported() -> bool:
	return not OS.has_feature("web") and OS.has_feature("pc")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_bar()
	EventBus.stock_changed.connect(_on_stock_changed)
	EventBus.game_loaded.connect(func(): _on_stock_changed(_amount()))
	get_window().size_changed.connect(_on_window_resized)
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
		options.close(true)
	var win := get_window()
	_saved = {
		"mode": win.mode, "size": win.size, "position": win.position, "borderless": win.borderless,
		"on_top": win.always_on_top, "transparent": win.transparent, "transparent_bg": win.transparent_bg,
		"scale_mode": win.content_scale_mode, "max_fps": Engine.max_fps, "min_size": win.min_size,
	}
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
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
	win.min_size = MIN_SIZE
	# último tamanho/lugar escolhido (se ainda couber na tela)
	var rect := _load_float_rect(usable)
	win.size = rect.size
	win.position = rect.position
	Engine.max_fps = FLOAT_MAX_FPS
	get_node(view_path).set_floating(true)
	get_node(hud_path).set_floating(true)
	_on_stock_changed(_amount())
	_refresh_sound_icons()
	_layer.visible = true
	_on_window_resized()
	changed.emit(true)


func exit() -> void:
	if not active:
		return
	if shop_open:
		_set_shop(false)
	_save_float_rect()
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
	win.min_size = _saved.get("min_size", Vector2i.ZERO)
	win.size = _saved.get("size", Vector2i(1280, 720))
	win.position = _saved.get("position", win.position)
	var mode: int = _saved.get("mode", Window.MODE_WINDOWED)
	if mode != Window.MODE_WINDOWED:
		win.mode = mode
	Engine.max_fps = _saved.get("max_fps", 0)
	changed.emit(false)


## Fecha o jogo pela janelinha (salva antes, como o X da janela normal).
func quit_game() -> void:
	if shop_open:
		_set_shop(false)
	_save_float_rect()
	var game := get_node_or_null(game_path)
	if game:
		game.save_now()
	get_tree().quit()


# ---------------------------------------------------------------------------
# Tamanho e lugar da janelinha
# ---------------------------------------------------------------------------

## Tamanho da janelinha sem a loja.
func _scene_size() -> Vector2i:
	var s := get_window().size
	return Vector2i(s.x, s.y - (SHOP_HEIGHT if shop_open else 0))


func _on_window_resized() -> void:
	if not active:
		return
	# o trem cresce e diminui com a altura escolhida
	var h := float(_scene_size().y)
	get_node(view_path).set_float_zoom(TrainView.FLOAT_ZOOM * h / float(WINDOW_SIZE.y))
	_update_click_area()


func _start_resize() -> void:
	if not shop_open:
		get_window().start_resize(DisplayServer.WINDOW_EDGE_TOP_LEFT)


func _load_float_rect(usable: Rect2i) -> Rect2i:
	var size := WINDOW_SIZE
	var pos := usable.end - WINDOW_SIZE - Vector2i(SCREEN_MARGIN, SCREEN_MARGIN)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section("float"):
		var s: Vector2i = cfg.get_value("float", "size", size)
		var p: Vector2i = cfg.get_value("float", "position", pos)
		s = s.clamp(MIN_SIZE, MAX_SIZE)
		if usable.encloses(Rect2i(p, s)):
			size = s
			pos = p
		elif s.x <= usable.size.x and s.y <= usable.size.y:
			size = s
			pos = usable.end - s - Vector2i(SCREEN_MARGIN, SCREEN_MARGIN)
	return Rect2i(pos, size)


func _save_float_rect() -> void:
	if not active:
		return
	var win := get_window()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # mantém o áudio
	cfg.set_value("float", "size", _scene_size())
	cfg.set_value("float", "position", win.position + Vector2i(0, SHOP_HEIGHT if shop_open else 0))
	cfg.save(SETTINGS_PATH)


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
	var win := get_window()
	var bottom := win.position.y + win.size.y
	if on:
		var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
		var h := win.size.y + SHOP_HEIGHT
		# cresce para cima; se a janela foi arrastada para perto do topo,
		# desce o necessário para caber inteira na área útil
		var y := clampi(bottom - h, usable.position.y, maxi(usable.position.y, usable.end.y - h))
		shop_open = true
		win.size = Vector2i(win.size.x, h)
		win.position = Vector2i(win.position.x, y)
	else:
		# o trem volta para onde estava (o pé da janela não se move)
		var h := win.size.y - SHOP_HEIGHT
		shop_open = false
		win.size = Vector2i(win.size.x, h)
		win.position = Vector2i(win.position.x, bottom - h)
	get_node(hud_path).show_float_shop(on, SHOP_HEIGHT - 6.0)
	_plus.text = "−" if on else "+"
	_plus.tooltip_text = "Fechar o armazém" if on else "Abrir o armazém (loja)"
	_grip.visible = not on
	_on_window_resized()


## Só o trem, a barra e a alça (ou tudo, com a loja aberta) recebem cliques;
## o resto da janela é transparente também para o mouse.
func _update_click_area() -> void:
	if not active:
		return
	var s := Vector2(get_window().size)
	if shop_open:
		get_window().mouse_passthrough_polygon = PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)])
		return
	var zoom: float = get_node(view_path).camera_zoom
	var top := clampf(s.y - (TrainView.FLOAT_GROUND_MARGIN + 320.0 * zoom), GRIP, s.y)
	get_window().mouse_passthrough_polygon = PackedVector2Array([Vector2.ZERO, Vector2(GRIP, 0), Vector2(GRIP, top),
		Vector2(s.x, top), s, Vector2(0, s.y)])


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
# Som
# ---------------------------------------------------------------------------

func _audio() -> Node:
	return get_node_or_null(audio_path)


func toggle_music() -> void:
	var audio := _audio()
	if audio:
		audio.set_music_enabled(not audio.music_enabled)
	_refresh_sound_icons()


func toggle_sfx() -> void:
	var audio := _audio()
	if audio:
		audio.set_sfx_enabled(not audio.sfx_enabled)
	_refresh_sound_icons()


func _refresh_sound_icons() -> void:
	var audio := _audio()
	if audio == null:
		return
	_music.tooltip_text = "Música: %s (clique para %s)" % ["ligada" if audio.music_enabled else "desligada", "desligar" if audio.music_enabled else "ligar"]
	_sfx.tooltip_text = "Efeitos sonoros: %s (clique para %s)" % ["ligados" if audio.sfx_enabled else "desligados", "desligar" if audio.sfx_enabled else "ligar"]
	_music.queue_redraw()
	_sfx.queue_redraw()


# ---------------------------------------------------------------------------
# Barra: carvão + "+", som, voltar e fechar
# ---------------------------------------------------------------------------

func _amount() -> float:
	var game := get_node_or_null(game_path)
	return game.state.stock.amount if game and game.state else 0.0


func _on_stock_changed(amount: float) -> void:
	if _coal_label:
		_coal_label.text = NumFormat.amount(amount)


func _build_bar() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "FloatBar"
	_layer.layer = 15
	_layer.visible = false
	add_child(_layer)

	# carvão pequeno no canto inferior esquerdo, com o "+" da loja
	_coal_box = HBoxContainer.new()
	_coal_box.name = "Coal"
	_coal_box.add_theme_constant_override("separation", 5)
	_coal_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 6)
	_coal_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_layer.add_child(_coal_box)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(14, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_coal_icon.bind(icon))
	_coal_box.add_child(icon)
	_coal_label = Label.new()
	_coal_label.name = "CoalLabel"
	_coal_label.tooltip_text = "Carvão em estoque"
	_coal_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_coal_label.add_theme_font_size_override("font_size", 14)
	_coal_label.add_theme_color_override("font_color", HudSkin.CREAM)
	_coal_label.add_theme_color_override("font_outline_color", HudSkin.INK)
	_coal_label.add_theme_constant_override("outline_size", 5)
	_coal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coal_box.add_child(_coal_label)
	_plus = _make_button("+", "Abrir o armazém (loja)", toggle_shop)
	_plus.name = "ShopButton"
	_plus.add_theme_font_size_override("font_size", 15)
	_coal_box.add_child(_plus)

	# som, voltar e fechar (canto inferior direito)
	var right := HBoxContainer.new()
	right.name = "WindowButtons"
	right.add_theme_constant_override("separation", 4)
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_layer.add_child(right)
	_music = _make_button("", "Música", toggle_music)
	_music.name = "MusicButton"
	_music.draw.connect(_draw_music_icon)
	right.add_child(_music)
	_sfx = _make_button("", "Efeitos sonoros", toggle_sfx)
	_sfx.name = "SfxButton"
	_sfx.draw.connect(_draw_sfx_icon)
	right.add_child(_sfx)
	_restore = _make_button("", "Voltar à janela normal (ESC ou duplo clique no trem)", exit)
	_restore.name = "RestoreButton"
	_restore.draw.connect(_draw_restore_icon)
	right.add_child(_restore)
	_close = _make_button("", "Fechar o jogo (o progresso é salvo)", quit_game)
	_close.name = "CloseButton"
	_close.draw.connect(_draw_close_icon)
	right.add_child(_close)

	# alça de redimensionar (canto superior esquerdo: a janela fica presa embaixo à direita)
	_grip = Control.new()
	_grip.name = "ResizeGrip"
	_grip.position = Vector2.ZERO
	_grip.size = Vector2(GRIP, GRIP)
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_grip.tooltip_text = "Arraste para mudar o tamanho"
	_grip.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_start_resize()
			_grip.accept_event())
	_grip.draw.connect(_draw_grip)
	_layer.add_child(_grip)


func _make_button(text: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 26)
	b.pressed.connect(action)
	_buttons.append(b)
	return b


func _draw_coal_icon(c: Control) -> void:
	var p := c.size / 2.0 + Vector2(0, 1)
	HudSkin.ink_poly(c, PackedVector2Array([p + Vector2(-6, 3), p + Vector2(-3, -5), p + Vector2(4, -4), p + Vector2(6, 4)]), HudSkin.CHARCOAL, 1.5)
	HudSkin.circle(c, p + Vector2(-1, -2), 1.6, Color(HudSkin.METAL, 0.8))


func _draw_slash(b: Button) -> void:
	var c := b.size / 2.0
	HudSkin.line(b, c + Vector2(-9, 9), c + Vector2(9, -9), HudSkin.INK, 4.5)
	HudSkin.line(b, c + Vector2(-9, 9), c + Vector2(9, -9), Color(0.95, 0.35, 0.28), 2.5)


func _draw_music_icon() -> void:
	var audio := _audio()
	var on: bool = audio.music_enabled if audio else true
	var col := HudSkin.CREAM if on else Color(HudSkin.CREAM, 0.45)
	var c := _music.size / 2.0 + Vector2(-1, 1)
	HudSkin.circle(_music, c + Vector2(-3, 5), 3.5, col)
	HudSkin.line(_music, c + Vector2(0, 5), c + Vector2(0, -7), col, 2.0)
	HudSkin.line(_music, c + Vector2(0, -7), c + Vector2(6, -4), col, 2.5)
	if not on:
		_draw_slash(_music)


func _draw_sfx_icon() -> void:
	var audio := _audio()
	var on: bool = audio.sfx_enabled if audio else true
	var col := HudSkin.CREAM if on else Color(HudSkin.CREAM, 0.45)
	var c := _sfx.size / 2.0 + Vector2(-3, 0)
	HudSkin.rect(_sfx, Rect2(c + Vector2(-5, -3), Vector2(4, 6)), col)
	HudSkin.poly(_sfx, PackedVector2Array([c + Vector2(-2, -3), c + Vector2(3, -7), c + Vector2(3, 7), c + Vector2(-2, 3)]), col)
	HudSkin.arc(_sfx, c + Vector2(3, 0), 5.0, -0.9, 0.9, 6, col, 1.6)
	HudSkin.arc(_sfx, c + Vector2(3, 0), 8.5, -0.9, 0.9, 8, col, 1.6)
	if not on:
		_draw_slash(_sfx)


func _draw_restore_icon() -> void:
	var c := _restore.size / 2.0 + Vector2(0, -1)
	var r := Rect2(c - Vector2(7, 5), Vector2(14, 11))
	HudSkin.rect(_restore, r.grow(1.5), HudSkin.CREAM)
	HudSkin.rect(_restore, r.grow(-0.5), HudSkin.WOOD_LIGHT)
	HudSkin.rect(_restore, Rect2(r.position, Vector2(r.size.x, 3)), HudSkin.CREAM)


func _draw_close_icon() -> void:
	var c := _close.size / 2.0 + Vector2(0, -1)
	HudSkin.line(_close, c + Vector2(-5, -5), c + Vector2(5, 5), HudSkin.CREAM, 2.5)
	HudSkin.line(_close, c + Vector2(5, -5), c + Vector2(-5, 5), HudSkin.CREAM, 2.5)


## Três riscos na diagonal, como a alça de janela, com contorno para aparecer
## sobre qualquer fundo do desktop.
func _draw_grip() -> void:
	for i in 3:
		var d := 5.0 + i * 5.0
		HudSkin.line(_grip, Vector2(3, d + 1), Vector2(d + 1, 3), HudSkin.INK, 4.0)
		HudSkin.line(_grip, Vector2(3, d + 1), Vector2(d + 1, 3), HudSkin.CREAM, 1.8)


func _apply_skin(theme_id: String) -> void:
	_skin_id = theme_id if HudSkin.SKINS.has(theme_id) else SeasonThemes.DEFAULT
	var theme := HudSkin.make_theme(_skin_id)
	for b in _buttons:
		b.theme = theme
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# botões pequenos: relevo e cantos menores que os da HUD
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := (theme.get_stylebox(st, "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.set_corner_radius_all(6)
			sb.set_border_width_all(2)
			sb.border_width_bottom = 2 if st.contains("pressed") else 4
			sb.set_content_margin_all(2)
			b.add_theme_stylebox_override(st, sb)
