extends CanvasLayer
## OptionsMenu — placa de opções pendurada (abre e fecha com ESC).
##
## Pausa a árvore do jogo (get_tree().paused): a lógica, o cenário e a HUD
## congelam exatamente onde estavam; este menu e o AudioDirector seguem
## rodando (PROCESS_MODE_ALWAYS), então a música continua e as chaves animam.
## Ao abrir, a partida é salva (nada se perde se o jogo for fechado no menu).
##
## Opções (todas persistem):
##   Música / Efeitos     -> AudioDirector (user://settings.cfg)
##   Parada automática    -> GameController/GameState (save da partida;
##                           mantida ao reiniciar a partida)
##   Trem flutuante       -> FloatMode (só no desktop; não aparece na Web)
##   Reiniciar partida    -> pede confirmação (clique duas vezes)

@export var game_path: NodePath = NodePath("../Game")
@export var audio_path: NodePath = NodePath("../AudioDirector")
@export var view_path: NodePath = NodePath("../TrainView")
@export var hud_path: NodePath = NodePath("../HUD")
@export var float_path: NodePath = NodePath("../FloatMode")

## Segundos para confirmar o reinício (segundo clique).
const RESET_CONFIRM_SECONDS := 3.0

@onready var _root: Control = %Root
@onready var _dim: ColorRect = %Dim
@onready var _board: PanelContainer = %Board
@onready var _music_switch: LeverSwitch = %MusicSwitch
@onready var _sfx_switch: LeverSwitch = %SfxSwitch
@onready var _stop_switch: LeverSwitch = %StopSwitch
@onready var _reset_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton

var is_open: bool = false
var _tween: Tween
var _reset_armed: float = 0.0
var _skin_id: String = SeasonThemes.DEFAULT
var _board_home: Vector2 = Vector2.ZERO
## Margens originais da placa (centralizada pelas âncoras). A animação mexe
## na posição; ao abrir, a placa volta a estas margens e recentraliza mesmo
## que a janela tenha mudado de tamanho (ex.: modo trem flutuante).
var _board_offsets: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_board_offsets = [_board.offset_left, _board.offset_top, _board.offset_right, _board.offset_bottom]
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_music_switch.toggled.connect(_on_music_toggled)
	_sfx_switch.toggled.connect(_on_sfx_toggled)
	_stop_switch.toggled.connect(_on_stop_toggled)
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(close)
	_add_float_button()
	EventBus.stop_at_stations_changed.connect(func(on: bool): _stop_switch.set_on_no_signal(on, is_open))
	_board.draw.connect(_draw_board)
	var view := get_node_or_null(view_path)
	if view:
		view.theme_changed.connect(_apply_skin)
	_apply_skin(SeasonThemes.DEFAULT)
	_sync_switches(false)


## "Trem flutuante" (desktop): fecha o menu e vira a janelinha.
func _add_float_button() -> void:
	var float_mode := get_node_or_null(float_path)
	if float_mode == null or not FloatMode.supported():
		return
	var b := Button.new()
	b.name = "FloatButton"
	b.text = "Trem flutuante (janelinha sobre o desktop)"
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		close(true)
		float_mode.enter())
	_reset_button.get_parent().add_child(b)
	_reset_button.get_parent().move_child(b, _reset_button.get_index())


func _input(event: InputEvent) -> void:
	var float_mode := get_node_or_null(float_path)
	if float_mode and float_mode.active:
		return   # na janelinha, ESC volta à janela normal (FloatMode)
	if event.is_action_pressed("toggle_options") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _reset_armed > 0.0:
		_reset_armed -= delta
		if _reset_armed <= 0.0:
			_reset_button.text = "Reiniciar partida (apaga o save)"


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Abre a placa e pausa o jogo (estado preservado; partida salva).
func open() -> void:
	if is_open:
		return
	is_open = true
	var game := get_node_or_null(game_path)
	if game and game.state:
		game.save_now()
	get_tree().paused = true
	_sync_switches(false)
	_reset_armed = 0.0
	_reset_button.text = "Reiniciar partida (apaga o save)"
	_root.visible = true
	_reset_board_layout()
	_board_home = _board.position
	if _tween:
		_tween.kill()
	_dim.modulate.a = 0.0
	_board.pivot_offset = Vector2(_board.size.x / 2.0, -40.0)
	_board.position = _board_home + Vector2(0, -_board.size.y - 120.0)
	_board.rotation = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.2)
	_tween.tween_property(_board, "position", _board_home, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# balanço de placa pendurada
	_tween.chain().tween_property(_board, "rotation", 0.035, 0.12)
	_tween.chain().tween_property(_board, "rotation", 0.0, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_back_button.grab_focus.call_deferred()


## Fecha a placa e retoma o jogo de onde parou. `instant`: sem animação
## (usado quando a janela vai mudar de tamanho logo em seguida).
func close(instant: bool = false) -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	if _tween:
		_tween.kill()
	if instant:
		_dim.modulate.a = 0.0
		_finish_close()
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 0.0, 0.2)
	_tween.tween_property(_board, "position", _board_home + Vector2(0, -_board.size.y - 120.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	_root.visible = false
	_board.rotation = 0.0
	_reset_board_layout()


## Devolve a placa ao centro (margens originais das âncoras).
func _reset_board_layout() -> void:
	if _board_offsets.size() == 4:
		_board.offset_left = _board_offsets[0]
		_board.offset_top = _board_offsets[1]
		_board.offset_right = _board_offsets[2]
		_board.offset_bottom = _board_offsets[3]


## Lê as configurações atuais (áudio salvo e parada da partida).
func _sync_switches(animate: bool) -> void:
	var audio := get_node_or_null(audio_path)
	_music_switch.set_on_no_signal(audio.music_enabled if audio else false, animate)
	_sfx_switch.set_on_no_signal(audio.sfx_enabled if audio else false, animate)
	var game := get_node_or_null(game_path)
	_stop_switch.set_on_no_signal(game.state.stop_at_stations if game and game.state else true, animate)


func _on_music_toggled(on: bool) -> void:
	var audio := get_node_or_null(audio_path)
	if audio:
		audio.set_music_enabled(on)


func _on_sfx_toggled(on: bool) -> void:
	var audio := get_node_or_null(audio_path)
	if audio:
		audio.set_sfx_enabled(on)
		if on:
			audio.play_ui_click()


func _on_stop_toggled(on: bool) -> void:
	var game := get_node_or_null(game_path)
	if game:
		game.set_stop_at_stations(on)


func _on_reset_pressed() -> void:
	if _reset_armed <= 0.0:
		_reset_armed = RESET_CONFIRM_SECONDS
		_reset_button.text = "Tem certeza? Clique de novo para apagar o save"
		return
	_reset_armed = 0.0
	var game := get_node_or_null(game_path)
	if game:
		game.reset_game()
	close()
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("show_message"):
		hud.show_message("Partida reiniciada.")


# ---------------------------------------------------------------------------
# Visual: placa esmaltada vinho pendurada por correntes, com a pele da estação
# ---------------------------------------------------------------------------

func _apply_skin(theme_id: String) -> void:
	_skin_id = theme_id if HudSkin.SKINS.has(theme_id) else SeasonThemes.DEFAULT
	var accent: Color = HudSkin.skin(_skin_id)["accent"]
	_board.theme = HudSkin.make_theme(_skin_id)
	var sb := HudSkin.box(HudSkin.WINE, HudSkin.INK, 5, 16, 22.0)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 8)
	_board.add_theme_stylebox_override("panel", sb)
	for label in [%Title, %AudioHeader, %GameplayHeader]:
		label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.2))
		label.add_theme_color_override("font_outline_color", HudSkin.INK)
		label.add_theme_constant_override("outline_size", 7 if label == %Title else 5)
	_back_button.add_theme_stylebox_override("normal", HudSkin.button_style(accent.darkened(0.25)))
	_back_button.add_theme_stylebox_override("hover", HudSkin.button_style(accent.darkened(0.1)))
	_back_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for s in [_music_switch, _sfx_switch, _stop_switch]:
		s.accent = accent
		s.queue_redraw()
	_board.queue_redraw()


func _draw_board() -> void:
	var s := _board.size
	var accent: Color = HudSkin.skin(_skin_id)["accent"]
	# correntes até o alto da tela
	for x in [s.x * 0.22, s.x * 0.78]:
		var y := -6.0
		var i := 0
		while y > -_board.position.y - 40.0:
			var link := Rect2(x - (4.0 if i % 2 == 0 else 2.5), y - 16.0, 8.0 if i % 2 == 0 else 5.0, 16.0)
			HudSkin.rect(_board, link.grow(2.0), HudSkin.INK)
			HudSkin.rect(_board, link, HudSkin.METAL)
			y -= 14.0
			i += 1
		HudSkin.ink_circle(_board, Vector2(x, 4), 6.0, HudSkin.BRASS, 2.0)
	# friso dourado, faixas separadoras e rebites
	HudSkin.polyline(_board, HudSkin.round_rect_points(Rect2(Vector2.ZERO, s).grow(-10), 10.0), Color(HudSkin.BRASS, 0.9), 3.0)
	for p in [Vector2(20, 20), Vector2(s.x - 20, 20), Vector2(20, s.y - 20), Vector2(s.x - 20, s.y - 20)]:
		HudSkin.ink_circle(_board, p, 4.5, HudSkin.BRASS, 1.5)
	for header in [%AudioHeader, %GameplayHeader]:
		var y: float = header.get_global_rect().end.y - _board.get_global_rect().position.y + 1.0
		HudSkin.line(_board, Vector2(28, y), Vector2(s.x - 28, y), Color(accent, 0.6), 2.0)
	HudSkin.draw_season_ornament(_board, s, _skin_id)
