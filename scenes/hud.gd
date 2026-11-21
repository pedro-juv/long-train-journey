extends CanvasLayer
## HUD — painel ferroviário (v0.3.0).
##
## Bilhete do estoque (canto superior esquerdo), placa da rota com as estações
## (topo), placa de estado/avisos, painel de instrumentos com velocímetro,
## manômetro da caldeira e o botão de atiçar (canto inferior esquerdo),
## armazém (loja) à direita, avisos em fita e botão de opções (ESC).
##
## Adapta-se à estação do ano da região (TrainView.theme_changed): acento de
## cor, decoração dos painéis e carimbo do bilhete — uma só HUD, sem cópias.
##
## Lê o estado pelo GameController/EventBus e chama ações nele.
## Não contém regras de jogo: preços, desbloqueios e efeitos vêm do GameState.
## Áudio e parada automática ficam no menu de opções (scenes/options_menu.gd).

@export var game_path: NodePath
@export var view_path: NodePath = NodePath("../TrainView")
@export var options_path: NodePath = NodePath("../OptionsMenu")
@export var float_path: NodePath = NodePath("../FloatMode")

## Frequência de atualização dos textos e botões da loja (segundos).
const SHOP_REFRESH_INTERVAL := 0.1
## Velocidade (m/s) no fim da escala do velocímetro (escala em raiz quadrada).
const SPEED_GAUGE_MAX := 60.0

@onready var _game: GameController = get_node(game_path)

@onready var _stock_label: Label = %StockLabel
@onready var _production_label: Label = %ProductionLabel
@onready var _state_label: Label = %StateLabel
@onready var _state_plate: PanelContainer = %StatePlate
@onready var _speed_label: Label = %SpeedLabel
@onready var _speed_hint: Label = %SpeedHint
@onready var _distance_label: Label = %DistanceLabel
@onready var _station_label: Label = %StationLabel
@onready var _route_strip: RouteStrip = %RouteStrip
@onready var _click_button: Button = %ClickButton
@onready var _message_label: Label = %MessageLabel
@onready var _toast: PanelContainer = %Toast
@onready var _shop_list: VBoxContainer = %ShopList
@onready var _offline_popup: PanelContainer = %OfflinePopup
@onready var _offline_text: Label = %OfflineText
@onready var _offline_ok: Button = %OfflineOk
@onready var _banner: PanelContainer = %StationBanner
@onready var _banner_text: Label = %BannerText
@onready var _float_layer: Control = %FloatLayer
@onready var _production_tab: Button = %ProductionTab
@onready var _train_tab: Button = %TrainTab
@onready var _maintenance_bar: ProgressBar = %MaintenanceBar
@onready var _warning_label: Label = %WarningLabel
@onready var _warning_plate: PanelContainer = %WarningPlate
@onready var _speed_gauge: DialGauge = %SpeedGauge
@onready var _pressure_gauge: DialGauge = %PressureGauge
@onready var _options_button: Button = %OptionsButton

const C_BRASS := HudSkin.BRASS
const C_CREAM := HudSkin.CREAM

var _message_timer: float = 0.0
var _shop_timer: float = 0.0

## Linhas da loja: id do produtor -> { "info": Label, "detail": Label, "button": Button }
var _producer_rows: Dictionary = {}
## Botões de melhoria: id -> Button
var _upgrade_buttons: Dictionary = {}
## Linhas da aba Trem: id da peça -> { "title", "bar", "detail", "repair", "reinforce", "auto" }
var _component_rows: Dictionary = {}
## Aba atual da loja: "producao" ou "trem".
var _tab: String = "producao"
## Assinatura do conteúdo da loja: se mudar, a lista é reconstruída.
var _shop_signature: String = ""
var _version_label: Label
var _version_text: String = ""
var _fps_timer: float = 0.0
## Modo trem flutuante: a HUD esconde tudo e a loja vira o painel compacto.
var floating: bool = false
## Layout normal da loja (âncoras e margens), para voltar do modo flutuante.
var _shop_layout: Array = []
var _float_button: Button
## Pele atual (tema da região).
var _skin_id: String = SeasonThemes.DEFAULT
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	EventBus.stock_changed.connect(_on_stock_changed)
	EventBus.shop_changed.connect(_on_shop_changed)
	EventBus.train_state_changed.connect(_on_train_state_changed)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.distance_changed.connect(_on_distance_changed)
	EventBus.station_reached.connect(_on_station_reached)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.offline_summary.connect(_on_offline_summary)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.component_failed.connect(_on_component_failed)
	EventBus.component_repaired.connect(_on_component_repaired)
	EventBus.component_reinforced.connect(_on_component_reinforced)
	EventBus.maintenance_finished.connect(_on_maintenance_finished)
	_production_tab.pressed.connect(_select_tab.bind("producao"))
	_train_tab.pressed.connect(_select_tab.bind("trem"))

	_click_button.pressed.connect(_on_click_pressed)
	EventBus.producer_bought.connect(_on_producer_bought)
	_offline_ok.pressed.connect(func(): _offline_popup.visible = false)
	_options_button.pressed.connect(_on_options_pressed)
	_options_button.draw.connect(_draw_options_icon)
	_add_float_button()
	_click_button.tooltip_text = "Cada clique gera carvão e aumenta a pressão da caldeira (velocidade extra que baixa sozinha)."
	_speed_gauge.caption = "m/s"
	_speed_gauge.tooltip_text = "A velocidade vem da produção e dos reforços das peças; a caldeira atiçada dá um extra."
	_pressure_gauge.caption = "CALDEIRA"
	_pressure_gauge.tooltip_text = "Pressão da caldeira: cada clique aumenta; dá velocidade extra e baixa sozinha."
	_message_label.text = ""
	_add_version_label()
	var view := get_node_or_null(view_path)
	if view:
		view.theme_changed.connect(_apply_skin)
	# decoração desenhada por cima do fundo de cada painel
	for panel in [$Ticket, $RoutePlate, $Dashboard, $ShopPanel, _offline_popup]:
		panel.draw.connect(_draw_decor.bind(panel))
	_apply_skin(SeasonThemes.DEFAULT)


## Etiqueta no canto inferior direito com a branch/commit em teste.
## Na exportação Web vem de res://build_info.txt (gerado pelo jogar-web.ps1);
## no editor, lê direto o .git/HEAD.
func _add_version_label() -> void:
	var info := ""
	if not OS.has_feature("editor") and FileAccess.file_exists("res://build_info.txt"):
		info = FileAccess.get_file_as_string("res://build_info.txt").strip_edges()
	elif FileAccess.file_exists("res://.git/HEAD"):
		var head := FileAccess.get_file_as_string("res://.git/HEAD").strip_edges()
		info = head.trim_prefix("ref: refs/heads/") if head.begins_with("ref:") else head.left(7)
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var label := Label.new()
	_version_text = ("v" + version if version else "") + ("  ·  " + info if info else "")
	label.text = _version_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(C_CREAM, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(label)
	_version_label = label


func _process(delta: float) -> void:
	# FPS no canto (fase de desenvolvimento), para medir desempenho.
	if _version_label:
		_fps_timer += delta
		if _fps_timer >= 0.5:
			_fps_timer = 0.0
			_version_label.text = "%d FPS  ·  %s" % [Engine.get_frames_per_second(), _version_text]
	_shop_timer += delta
	if _shop_timer >= SHOP_REFRESH_INTERVAL:
		_shop_timer = 0.0
		_refresh_shop()
		_production_label.text = "Produção: %s carvão/s" % NumFormat.rate(_state().total_production())
		_click_button.text = "ATIÇAR A CALDEIRA\n+%s carvão" % NumFormat.rate(_state().click_value())
		_refresh_maintenance_status()
		_refresh_state_label()
	var stoke := _state().stoke
	_pressure_gauge.set_reading(stoke, "+%d%%" % roundi(_state().stoke_bonus() * 100.0))

	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.text = ""
			_toast.visible = false


func _state() -> GameState:
	return _game.state


# ---------------------------------------------------------------------------
# Pele da estação do ano
# ---------------------------------------------------------------------------

## Troca acento, estilos e decoração conforme o tema da região.
func _apply_skin(theme_id: String) -> void:
	_skin_id = theme_id if HudSkin.SKINS.has(theme_id) else SeasonThemes.DEFAULT
	var sk := HudSkin.skin(_skin_id)
	var accent: Color = sk["accent"]
	var theme := HudSkin.make_theme(_skin_id)
	for root_control in [$Ticket, $RoutePlate, $StateArea, $Dashboard, $ShopPanel, $Toast, _options_button, _offline_popup, _banner, _float_button]:
		if root_control:
			root_control.theme = theme
			root_control.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var wood := HudSkin.panel_style(_skin_id)
	for panel in [$RoutePlate, $Dashboard, $ShopPanel]:
		panel.add_theme_stylebox_override("panel", wood)
	$Ticket.add_theme_stylebox_override("panel", HudSkin.ticket_style())
	var telegram := HudSkin.ticket_style()
	telegram.set_content_margin_all(18)
	_offline_popup.add_theme_stylebox_override("panel", telegram)
	_state_plate.add_theme_stylebox_override("panel", HudSkin.plate_style(HudSkin.WINE))
	_warning_plate.add_theme_stylebox_override("panel", HudSkin.plate_style(Color(0.62, 0.30, 0.08)))
	_toast.add_theme_stylebox_override("panel", HudSkin.plate_style(HudSkin.CHARCOAL))
	var banner := HudSkin.plate_style(HudSkin.WINE)
	banner.border_width_bottom = 8
	_banner.add_theme_stylebox_override("panel", banner)
	# textos escuros no papel (bilhete e telegrama)
	for label in [$Ticket/Margin/VBox/TicketTitle, _stock_label, _production_label, $OfflinePopup/Margin/VBox/OfflineTitle, _offline_text]:
		label.add_theme_color_override("font_color", HudSkin.INK)
	$Ticket/Margin/VBox/TicketTitle.add_theme_color_override("font_color", HudSkin.WINE)
	# títulos com contorno de tinta
	for label in [$ShopPanel/VBox/ShopTitle, _banner_text, _state_label]:
		label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.25))
		label.add_theme_color_override("font_outline_color", HudSkin.INK)
		label.add_theme_constant_override("outline_size", 6)
	_message_label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.4))
	# botão de atiçar: grande e vermelho
	_click_button.add_theme_stylebox_override("normal", HudSkin.button_style(HudSkin.WINE_LIGHT))
	_click_button.add_theme_stylebox_override("hover", HudSkin.button_style(HudSkin.WINE_LIGHT.lightened(0.12)))
	_click_button.add_theme_stylebox_override("pressed", HudSkin.button_style(HudSkin.WINE, true))
	_speed_gauge.set_accent(accent)
	_pressure_gauge.set_accent(accent)
	_route_strip.set_accent(accent)
	for panel in [$Ticket, $RoutePlate, $Dashboard, $ShopPanel, _offline_popup]:
		panel.queue_redraw()
	_options_button.queue_redraw()


func _draw_decor(panel: Control) -> void:
	if panel == $Ticket:
		_draw_ticket_decor(panel)
	elif panel == _offline_popup:
		# telegrama: faixa de cabeçalho e carimbo
		HudSkin.rect(panel, Rect2(10, 10, panel.size.x - 20, 6), Color(HudSkin.WINE, 0.8))
		HudSkin.draw_stamp(panel, Vector2(panel.size.x - 52, 50), _skin_id, _font)
	else:
		HudSkin.draw_panel_decor(panel, panel.size, _skin_id)


## Bilhete: picote nas laterais, faixa da cor da estação e carimbo.
func _draw_ticket_decor(panel: Control) -> void:
	var accent: Color = HudSkin.skin(_skin_id)["accent"]
	var s := panel.size
	HudSkin.rect(panel, Rect2(3, 3, 9, s.y - 6), accent.darkened(0.1))
	var y := 10.0
	while y < s.y - 6.0:
		HudSkin.circle(panel, Vector2(s.x - 66, y), 2.0, Color(HudSkin.INK, 0.35))
		y += 9.0
	HudSkin.draw_stamp(panel, Vector2(s.x - 33, s.y / 2.0), _skin_id, _font)


## Ícone de engrenagem no botão de opções (desenhado no próprio botão).
func _draw_options_icon() -> void:
	var b := _options_button
	var c := b.size / 2.0 + Vector2(0, -1)
	HudSkin.ink_gear(b, c, 17, 12, 9, 0.2, C_CREAM, 2.0)
	HudSkin.ink_circle(b, c, 5.0, HudSkin.skin(_skin_id)["accent"], 2.0)
	b.draw_string(_font, Vector2(0, b.size.y + 13), "ESC", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 11, C_CREAM)


## Botão do modo trem flutuante, embaixo da engrenagem (só no desktop).
func _add_float_button() -> void:
	var float_mode := get_node_or_null(float_path)
	if float_mode == null or not FloatMode.supported():
		return
	var b := Button.new()
	b.name = "FloatButton"
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Trem flutuante: o trem vira uma janelinha transparente sobre o desktop"
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -420.0   # embaixo da engrenagem (ESC), fora da placa da rota
	b.offset_top = 100.0
	b.offset_right = -364.0
	b.offset_bottom = 148.0
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.pressed.connect(float_mode.enter)
	b.draw.connect(_draw_float_icon.bind(b))
	add_child(b)
	move_child(b, _options_button.get_index() + 1)
	_float_button = b


## Ícone: janelinha com um trenzinho, e o texto embaixo.
func _draw_float_icon(b: Button) -> void:
	var c := b.size / 2.0
	var win := Rect2(c - Vector2(16, 12), Vector2(32, 24))
	HudSkin.rect(b, win.grow(2), HudSkin.INK)
	HudSkin.rect(b, win, Color(C_CREAM, 0.25))
	HudSkin.rect(b, Rect2(win.position, Vector2(win.size.x, 5)), C_CREAM)
	HudSkin.rect(b, Rect2(c + Vector2(-9, 0), Vector2(14, 7)), C_CREAM)
	HudSkin.rect(b, Rect2(c + Vector2(1, -5), Vector2(4, 5)), C_CREAM)
	HudSkin.circle(b, c + Vector2(-5, 8), 2.5, C_CREAM)
	HudSkin.circle(b, c + Vector2(3, 8), 2.5, C_CREAM)
	b.draw_string(_font, Vector2(-10, b.size.y + 13), "FLUTUAR", HORIZONTAL_ALIGNMENT_CENTER, b.size.x + 20, 11, C_CREAM)


## Modo trem flutuante: só a loja fica (escondida até o botão "+").
func set_floating(on: bool) -> void:
	if on == floating:
		return
	floating = on
	for c in [$Ticket, $RoutePlate, $StateArea, $Dashboard, _options_button, _float_button, _version_label]:
		if c:
			c.visible = not on
	var shop: Control = $ShopPanel
	if on:
		_toast.visible = false
		_banner.visible = false
		_offline_popup.visible = false
		_shop_layout = [shop.anchor_left, shop.anchor_top, shop.anchor_right, shop.anchor_bottom,
			shop.offset_left, shop.offset_top, shop.offset_right, shop.offset_bottom]
		shop.visible = false
	else:
		shop.anchor_left = _shop_layout[0]
		shop.anchor_top = _shop_layout[1]
		shop.anchor_right = _shop_layout[2]
		shop.anchor_bottom = _shop_layout[3]
		shop.offset_left = _shop_layout[4]
		shop.offset_top = _shop_layout[5]
		shop.offset_right = _shop_layout[6]
		shop.offset_bottom = _shop_layout[7]
		shop.visible = true


## Loja compacta do modo flutuante: a MESMA loja (mesmas linhas, mesmas
## compras), presa no topo da janela com a altura dada.
func show_float_shop(on: bool, height: float) -> void:
	var shop: Control = $ShopPanel
	shop.visible = on
	if on:
		shop.anchor_left = 0.0
		shop.anchor_right = 1.0
		shop.anchor_top = 0.0
		shop.anchor_bottom = 0.0
		shop.offset_left = 8.0
		shop.offset_right = -16.0
		shop.offset_top = 16.0   # folga para a engrenagem desenhada no canto
		shop.offset_bottom = height
		_refresh_shop()


func _on_options_pressed() -> void:
	var options := get_node_or_null(options_path)
	if options:
		options.open()


# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------

func _on_stock_changed(amount: float) -> void:
	_stock_label.text = "%s carvão" % NumFormat.amount(amount)


## Placa de estado: só aparece quando algo especial acontece.
func _on_train_state_changed(_state_value: int) -> void:
	_refresh_state_label()


func _refresh_state_label() -> void:
	var s := _state()
	var text := ""
	var plate := HudSkin.WINE
	match s.train.state:
		TrainMovement.State.BRAKING:
			var c := s.component(s.maintenance.stop_component_id)
			text = "Falha: %s! Freando..." % (c.display_name if c else "peça")
			plate = Color(0.70, 0.14, 0.10)
		TrainMovement.State.MAINTENANCE:
			var c := s.component(s.maintenance.stop_component_id)
			text = "Em manutenção (%s) — %d s" % [c.display_name if c else "peça", int(ceil(s.maintenance.stop_left))]
			plate = Color(0.55, 0.30, 0.10)
		TrainMovement.State.APPROACHING:
			text = "Chegando em %s..." % s.route.next_station_name()
		TrainMovement.State.AT_STATION:
			var index := s.route.reached_count - 1
			text = "Parado em %s — partida em %d s" % [s.route.station_name(index), int(ceil(s.station_stop_left))]
	var show := not text.is_empty()
	_state_label.visible = show
	_state_label.text = text
	if show and not _state_plate.visible:
		_pop_in(_state_plate)
	_state_plate.visible = show
	if show:
		var sb: StyleBoxFlat = _state_plate.get_theme_stylebox("panel")
		if sb and sb.bg_color != plate:
			_state_plate.add_theme_stylebox_override("panel", HudSkin.plate_style(plate))


func _on_speed_changed(speed_mps: float, _target_speed_mps: float, _stoke: float) -> void:
	var s := _state()
	var extras := ""
	var bonus := s.reinforce_speed_bonus()
	if bonus > 0.0:
		extras += " · +%d%% peças" % roundi(bonus * 100.0)
	var stoke := s.stoke_bonus()
	if stoke >= 0.005:
		extras += " · +%d%% caldeira" % roundi(stoke * 100.0)
	_speed_label.text = "Velocidade: %s%s" % [NumFormat.speed(speed_mps), extras]
	_speed_gauge.set_reading(sqrt(clampf(speed_mps / SPEED_GAUGE_MAX, 0.0, 1.0)), String.num(speed_mps, 1).replace(".", ","))


func _on_distance_changed(distance_m: float) -> void:
	_distance_label.text = NumFormat.distance(distance_m)
	_refresh_station(distance_m)


func _refresh_station(distance_m: float) -> void:
	var route := _state().route
	var names := PackedStringArray()
	for i in route.station_count():
		names.append(route.station_name(i).trim_prefix("Estação "))
	if route.is_complete():
		_station_label.text = "Fim da rota atual (%d estações)!" % route.station_count()
		_route_strip.set_route(names, route.reached_count, 0.0)
		return
	var target := route.target_distance(route.reached_count)
	_station_label.text = "Próxima: %s — faltam %s" % [route.next_station_name(), NumFormat.distance(maxf(0.0, target - distance_m))]
	_route_strip.set_route(names, route.reached_count, route.progress(distance_m))


func _on_station_reached(index: int, station_name: String) -> void:
	var extra := ""
	for c in _state().maintenance.components:
		if c.unlock_station == index:
			extra = " Nova peça na aba Trem: %s." % c.display_name if index > 0 else " Nova aba: Trem (manutenção das peças)."
			break
	if index == _state().config.auto_maintenance_unlock_station:
		extra += " Manutenção automática liberada!"
	_show_message("Você chegou à %s! Veja o armazém: há novidades.%s" % [_station_title(station_name), extra])
	_show_banner(_station_title(station_name))


func _on_upgrade_purchased(id: String) -> void:
	if id.begins_with("auto_"):
		var c := _state().component(id.substr(5))
		_show_message("Manutenção automática ativa: %s de %s." % [c.display_name, c.material_name()])
		return
	var entry := _state().upgrades.get_entry(id)
	if not entry.is_empty():
		_show_message("Comprado: %s." % entry["name"])


func _on_game_loaded() -> void:
	_rebuild_shop()
	_refresh_station(_state().train.distance_m)
	_message_label.text = ""
	_message_timer = 0.0
	_toast.visible = false
	_offline_popup.visible = false


# ---------------------------------------------------------------------------
# Resumo offline
# ---------------------------------------------------------------------------

func _on_offline_summary(summary: Dictionary) -> void:
	var lines: Array[String] = []
	var seconds := float(summary["seconds"])
	var real := float(summary.get("elapsed_real", seconds))
	if real > seconds + 1.0:
		lines.append("Tempo fora: %s (contamos até %s)" % [NumFormat.duration(real), NumFormat.duration(seconds)])
	else:
		lines.append("Tempo fora: %s" % NumFormat.duration(seconds))
	var delta := float(summary["stock_delta"])
	lines.append("%s%s carvão no estoque" % ["+" if delta >= 0.0 else "", NumFormat.amount(delta)])
	lines.append("+%s percorridos" % NumFormat.distance(float(summary["distance"])))
	var names: Array[String] = []
	for index in summary["stations"]:
		names.append(_state().route.station_name(int(index)))
	if not names.is_empty():
		lines.append("Estações alcançadas: %s" % ", ".join(names))
	if int(summary.get("failures", 0)) > 0:
		lines.append("%d paradas para manutenção (%s)" % [int(summary["failures"]), NumFormat.duration(float(summary["downtime"]))])
	if int(summary.get("auto_repairs", 0)) > 0:
		lines.append("%d consertos automáticos (%s carvão)" % [int(summary["auto_repairs"]), NumFormat.amount(float(summary["auto_cost"]))])
	if summary.get("waiting_at_station", false) and not names.is_empty():
		lines.append("O trem chegou à %s e esperou você para seguir viagem." % _station_title(names[-1]))
	_offline_text.text = "\n".join(lines)
	_offline_popup.visible = not floating
	_pop_in(_offline_popup)


# ---------------------------------------------------------------------------
# Loja
# ---------------------------------------------------------------------------

## Só reconstrói se o conjunto de itens mudou (ex.: melhoria nova liberada);
## senão basta atualizar os textos. Sempre adiado para fora do clique.
func _on_shop_changed() -> void:
	if _compute_signature() != _shop_signature:
		_rebuild_shop.call_deferred()
	else:
		_refresh_shop()


func _compute_signature() -> String:
	var s := _state()
	var active: Array[String] = []
	for c in s.maintenance.active_components(s.route):
		active.append(c.id + ("A" if c.has_auto() else ""))
	return "%s|%s|%s|%s" % [_tab, s.available_upgrade_ids(), active, s.is_auto_maintenance_unlocked()]


func _select_tab(tab: String) -> void:
	_tab = tab
	_production_tab.set_pressed_no_signal(tab == "producao")
	_train_tab.set_pressed_no_signal(tab == "trem")
	_rebuild_shop()


## Reconstrói a lista inteira.
func _rebuild_shop() -> void:
	for child in _shop_list.get_children():
		_shop_list.remove_child(child)
		child.queue_free()
	_producer_rows.clear()
	_upgrade_buttons.clear()
	_component_rows.clear()
	_train_tab.visible = _state().has_active_components()
	if not _train_tab.visible and _tab == "trem":
		_tab = "producao"
	_production_tab.set_pressed_no_signal(_tab == "producao")
	_train_tab.set_pressed_no_signal(_tab == "trem")
	_shop_signature = _compute_signature()

	if _tab == "trem":
		_build_train_tab()
		_refresh_shop()
		return

	_add_section_title("Produtores")
	for p in _state().producers:
		_add_producer_row(p)

	var available := _state().available_upgrade_ids()
	if not available.is_empty():
		_add_section_title("Melhorias")
		for id in available:
			_add_upgrade_button(id)
	_refresh_shop()


func _add_section_title(text: String) -> void:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", (HudSkin.skin(_skin_id)["accent"] as Color).lerp(Color.WHITE, 0.2))
	label.add_theme_color_override("font_outline_color", HudSkin.INK)
	label.add_theme_constant_override("outline_size", 4)
	_shop_list.add_child(label)


func _add_producer_row(p: CoalProducer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 15)
	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(HudSkin.CREAM, 0.75))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 38)
	button.focus_mode = Control.FOCUS_NONE
	var id := p.id
	button.pressed.connect(func(): _game.buy_producer(id))
	box.add_child(info)
	box.add_child(detail)
	box.add_child(button)
	_shop_list.add_child(box)
	_producer_rows[p.id] = {"info": info, "detail": detail, "button": button}


func _add_upgrade_button(id: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 50)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): _game.buy_upgrade(id))
	_shop_list.add_child(button)
	_upgrade_buttons[id] = button


## Atualiza textos e botões habilitados (preço e estoque mudam o tempo todo).
func _refresh_shop() -> void:
	var s := _state()
	for p in s.producers:
		if not _producer_rows.has(p.id):
			continue
		var row: Dictionary = _producer_rows[p.id]
		var cost := p.next_level_cost()
		if not s.is_producer_unlocked(p.id):
			row["info"].text = "%s — bloqueado" % p.display_name
			row["detail"].text = "Libera ao chegar na %s." % _station_title(s.route.station_name(p.unlock_station))
			row["button"].text = "Bloqueado"
			row["button"].disabled = true
			continue
		if p.level == 0:
			row["info"].text = "%s — não contratado" % p.display_name
			row["button"].text = "Contratar — %s" % NumFormat.amount(cost)
		else:
			row["info"].text = "%s · nv %d — %s/s" % [p.display_name, p.level, NumFormat.rate(s.producer_production(p.id))]
			row["button"].text = "Melhorar para nv %d — %s" % [p.level + 1, NumFormat.amount(cost)]
		var gain := s.production_after_level_up(p.id) - s.total_production()
		var detail := "Próximo nível: +%s/s" % NumFormat.rate(gain)
		var milestone := p.next_milestone()
		if milestone > 0:
			detail += "  ·  Nível %d: produção x%s" % [milestone, NumFormat.rate(p.milestone_value())]
		row["detail"].text = detail
		row["button"].disabled = not s.can_buy_producer(p.id)

	_refresh_component_rows()

	for id in _upgrade_buttons:
		var button: Button = _upgrade_buttons[id]
		var entry := s.upgrades.get_entry(id)
		button.text = "%s — %s\n%s" % [entry["name"], NumFormat.amount(entry["cost"]), _effect_text(entry)]
		button.disabled = not s.can_buy_upgrade(id)


func _effect_text(entry: Dictionary) -> String:
	var value := float(entry["value"])
	match entry["effect"]:
		"producer_mult":
			return "%s: produção x%s" % [_state().producer(entry["target"]).display_name, NumFormat.rate(value)]
		"global_mult":
			return "Produção total +%d%%" % roundi((value - 1.0) * 100.0)
		"maintenance_time_mult":
			return "Manutenção %d%% mais rápida" % roundi((1.0 - value) * 100.0)
		"click_mult":
			return "Clique x%s (passa a %s)" % [NumFormat.rate(value), NumFormat.rate(_state().click_value() * value)]
	return ""


## "Cidade Tomada" -> "Estação Cidade Tomada"; "Estação Inicial" continua igual.
func _station_title(station_name: String) -> String:
	return station_name if station_name.begins_with("Estação") else "Estação %s" % station_name


## Mensagem na fita de avisos (usado também pelo menu de opções).
func show_message(text: String) -> void:
	_show_message(text)


func _show_message(text: String) -> void:
	if floating:   # a janelinha não tem espaço para avisos
		return
	_message_label.text = text
	_message_timer = 5.0
	if not _toast.visible:
		_toast.visible = true
		_pop_in(_toast)


# ---------------------------------------------------------------------------
# Efeitos (só apresentação)
# ---------------------------------------------------------------------------

func _on_click_pressed() -> void:
	_game.click_coal()
	var origin := _click_button.global_position + Vector2(_click_button.size.x * randf_range(0.3, 0.7), 4)
	_float_text("+%s" % NumFormat.rate(_state().click_value()), origin, C_BRASS)
	_squash(_click_button)


func _on_producer_bought(id: String, level: int, milestone: bool) -> void:
	if _producer_rows.has(id):
		var row: Dictionary = _producer_rows[id]
		var button: Button = row["button"]
		_pulse(button)
		_float_text("nv %d!" % level, button.global_position + Vector2(button.size.x - 60, 0), C_CREAM)
		var info: Label = row["info"]
		info.modulate = Color(1.6, 1.3, 0.6)
		create_tween().tween_property(info, "modulate", Color.WHITE, 0.6)
	if milestone:
		_show_message("%s chegou ao nível %d: produção x%s!" % [_state().producer(id).display_name, level, NumFormat.rate(_state().producer(id).milestone_value())])
		_show_banner("Marco! %s nível %d" % [_state().producer(id).display_name, level])


func _float_text(text: String, origin: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", HudSkin.INK)
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = origin - _float_layer.global_position
	label.pivot_offset = Vector2(20, 14)
	label.scale = Vector2(0.6, 0.6)
	_float_layer.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "rotation", randf_range(-0.2, 0.2), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(1.06, 1.06), 0.06)
	tween.tween_property(control, "scale", Vector2.ONE, 0.12)


## Achatamento exagerado de desenho animado (botão de atiçar).
func _squash(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(1.08, 0.88), 0.05)
	tween.tween_property(control, "scale", Vector2(0.97, 1.05), 0.08)
	tween.tween_property(control, "scale", Vector2.ONE, 0.10)


## Entrada com "pulo" (placas, fita de aviso, telegrama).
func _pop_in(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_banner(text: String) -> void:
	if floating:   # a placa da estação no cenário já mostra a chegada
		return
	_banner_text.text = text
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.7, 0.7)
	_banner.rotation = -0.06
	_banner.pivot_offset = _banner.size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_banner, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(2.2)
	tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(func(): _banner.visible = false)


# ---------------------------------------------------------------------------
# Aba "Trem": componentes e manutenção (Fase 1B)
# ---------------------------------------------------------------------------

func _build_train_tab() -> void:
	var s := _state()
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(HudSkin.CREAM, 0.75))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "Peças a 0%% quebram: o trem para %s e a peça volta a 100%%. Cada reforço faz a peça durar 40%% mais e deixa o trem %d%% mais rápido." % [NumFormat.duration(s.maintenance.stop_seconds()), roundi(float(s.config.reinforce_speed_bonus) * 100.0)]
	_shop_list.add_child(info)
	_add_section_title("Componentes")
	for c in s.maintenance.components:
		_add_component_row(c)


func _add_component_row(c: TrainComponent) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 15)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.max_value = 100.0
	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(HudSkin.CREAM, 0.75))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	var repair := Button.new()
	repair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reinforce := Button.new()
	reinforce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var auto := Button.new()
	# Botões das peças com fonte menor e sem largura mínima pelo texto,
	# para o armazém manter a largura fixa.
	for b in [repair, reinforce, auto]:
		b.add_theme_font_size_override("font_size", 13)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 44)
		b.focus_mode = Control.FOCUS_NONE
	var id := c.id
	repair.pressed.connect(func(): _game.repair_component(id))
	reinforce.pressed.connect(func(): _game.reinforce_component(id))
	auto.pressed.connect(func(): _game.buy_auto_maintenance(id))
	buttons.add_child(repair)
	buttons.add_child(reinforce)
	box.add_child(title)
	box.add_child(bar)
	box.add_child(detail)
	box.add_child(buttons)
	box.add_child(auto)
	_shop_list.add_child(box)
	_component_rows[c.id] = {"title": title, "bar": bar, "detail": detail, "repair": repair,
		"reinforce": reinforce, "auto": auto, "buttons": buttons}


func _refresh_component_rows() -> void:
	var s := _state()
	for id in _component_rows:
		var row: Dictionary = _component_rows[id]
		var c := s.component(id)
		if not s.is_component_active(id):
			row["title"].text = "%s — bloqueado" % c.display_name
			row["detail"].text = "Aparece ao chegar na %s." % _station_title(s.route.station_name(c.unlock_station))
			row["bar"].visible = false
			row["buttons"].visible = false
			row["auto"].visible = false
			continue
		row["bar"].visible = true
		row["buttons"].visible = true
		var pct := c.integrity * 100.0
		var lvl := " · reforço nv %d" % c.level if c.level > 0 else ""
		row["title"].text = "%s de %s%s — %d%%" % [c.display_name, c.material_name(), lvl, int(ceil(pct))]
		row["bar"].value = pct
		row["bar"].modulate = _integrity_color(c.integrity)
		var life := NumFormat.distance(c.life()) if c.wear_kind == TrainComponent.Wear.DISTANCE else NumFormat.duration(c.life()) + " andando"
		var next_life: float = c.life() * s.config.reinforce_life_multiplier
		var next_txt := NumFormat.distance(next_life) if c.wear_kind == TrainComponent.Wear.DISTANCE else NumFormat.duration(next_life)
		var bonus_pct := roundi(float(s.config.reinforce_speed_bonus) * 100.0)
		var detail := "Dura %s · bônus +%d%% velocidade\nPróximo reforço: dura %s e +%d%% velocidade" % [life, roundi(c.level * float(s.config.reinforce_speed_bonus) * 100.0), next_txt, bonus_pct]
		if c.has_auto():
			detail += "  ·  Automática: %d consertos" % c.auto_repairs
		row["detail"].text = detail
		row["repair"].text = "Reparar\n%s" % NumFormat.amount(s.repair_cost(id)) if c.integrity < 1.0 else "Peça\na 100%"
		row["repair"].disabled = not s.can_repair(id)
		row["reinforce"].text = "Reforçar nv %d\n%s" % [c.level + 1, NumFormat.amount(c.reinforce_cost())]
		row["reinforce"].disabled = not s.can_reinforce(id)
		var auto: Button = row["auto"]
		if c.has_auto():
			auto.visible = true
			auto.disabled = true
			auto.text = "Manutenção automática ativa (%s)" % c.material_name()
		elif s.is_auto_maintenance_unlocked():
			auto.visible = true
			auto.text = "Manutenção automática (%s) — %s" % [c.material_name(), NumFormat.amount(c.auto_cost())]
			auto.disabled = not s.can_buy_auto(id)
		else:
			auto.visible = false


func _integrity_color(integrity: float) -> Color:
	if integrity < _state().config.component_warning_threshold:
		return Color(1.0, 0.35, 0.25)
	if integrity < 0.5:
		return Color(1.0, 0.85, 0.3)
	return Color.WHITE


## Estado "em manutenção" com contagem regressiva e aviso de peças gastas.
func _refresh_maintenance_status() -> void:
	var s := _state()
	var m := s.maintenance
	if m.is_stopped():
		_maintenance_bar.visible = s.train.state == TrainMovement.State.MAINTENANCE
		_maintenance_bar.max_value = maxf(m.stop_seconds(), m.stop_left)
		_maintenance_bar.value = _maintenance_bar.max_value - m.stop_left
	else:
		_maintenance_bar.visible = false
	var worn: Array[String] = []
	for c in m.active_components(s.route):
		if c.integrity < s.config.component_warning_threshold and not c.has_auto():
			worn.append("%s a %d%%" % [c.display_name, int(ceil(c.integrity * 100.0))])
	var show := not worn.is_empty()
	if show and not _warning_plate.visible:
		_pop_in(_warning_plate)
	_warning_label.visible = show
	_warning_plate.visible = show
	if show:
		_warning_label.text = "Atenção: %s! (aba Trem)" % ", ".join(worn)


func _on_component_failed(_id: String, component_name: String) -> void:
	_show_message("%s quebrou! O trem vai parar para %s de manutenção." % [component_name, NumFormat.duration(_state().maintenance.stop_seconds())])
	_refresh_maintenance_status()


func _on_component_repaired(id: String, automatic: bool) -> void:
	if automatic:
		return
	var row: Dictionary = _component_rows.get(id, {})
	if not row.is_empty():
		var button: Button = row["repair"]
		_float_text("100%!", button.global_position + Vector2(10, 0), C_BRASS)
		_pulse(button)


func _on_component_reinforced(id: String, level: int) -> void:
	var row: Dictionary = _component_rows.get(id, {})
	if not row.is_empty():
		var button: Button = row["reinforce"]
		_float_text("nv %d!" % level, button.global_position + Vector2(button.size.x - 60, 0), C_CREAM)
		_pulse(button)


func _on_maintenance_finished() -> void:
	_show_message("Manutenção concluída. Seguindo viagem!")
	_refresh_maintenance_status()
