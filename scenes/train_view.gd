extends Node2D
## TrainView — cenário e locomotiva, desenhados por código em estilo cartoon.
##
## Só apresentação: lê a velocidade e os eventos do EventBus e anima.
## Nenhuma regra de jogo vive aqui; tudo pode ser trocado por arte definitiva.
##
## Direção de arte (v0.3.0): cartoon 2D "desenhado à mão" — contornos fortes
## de tinta, silhuetas simples, sombras chapadas (cel) e animação exagerada.
## Paleta ferroviária antiga: vinho, madeira, carvão, metal, bronze, cobre,
## ouro envelhecido e creme, com acentos vivos por estação.
##
## Câmera (v0.3.0): a TrainView inteira é desenhada num "mundo" maior que a
## tela e reduzida por `camera_zoom` (escala do nó). Assim a câmera fica mais
## afastada, aparece mais trilho e o trem fica como uma composição (locomotiva
## + tender) com espaço atrás para vagões futuros. É a ÚNICA câmera do jogo.
##
## Camadas (do fundo para a frente): céu, estrelas/raios, sol/lua, nuvens,
## montanhas, colinas, cidade, árvores, campo, trilhos, placas das estações,
## postes, fumaça antiga, tender, locomotiva (com o maquinista), fumaça nova,
## clima e mato em primeiro plano.
##
## Cada região da rota tem um tema (scenes/season_themes.gd).
##
## Desempenho: cada camada é um nó filho. As camadas FIXAS são desenhadas UMA
## vez e só deslizam/balançam mudando a posição do nó; elas só se redesenham
## quando o tema muda ou a janela muda de tamanho. Só as camadas VIVAS (rodas,
## bielas, maquinista, fumaça, clima, brilhos) redesenham a cada quadro.


## Uma camada de desenho: chama `fn` com a TrainView desenhando nela.
class Layer extends Node2D:
	var fn: Callable
	var view: Node2D
	var layer_name: String
	## Camada viva: redesenha a cada N quadros (animações lentas não precisam de 60/s).
	var every: int = 1

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		view._ci = self
		fn.call()
		view._ci = view
		if view.profile_layers:
			view.layer_usec[layer_name] = view.layer_usec.get(layer_name, 0) + Time.get_ticks_usec() - t0

## Emitido a cada "baforada" da locomotiva (sincronizado com as rodas).
## intensity: 0..1 conforme a velocidade. Usado pelo AudioDirector.
signal chuffed(intensity: float)

## Emitido quando o tema da região muda (e ao carregar o jogo).
## Usado pelo AudioDirector (música) e pela HUD (decoração da estação do ano).
signal theme_changed(theme_id: String)

@export var game_path: NodePath
## Afastamento da câmera: 1.0 = mundo do tamanho da tela; menor = mais longe.
@export_range(0.4, 1.0, 0.01) var camera_zoom: float = 0.58

# Coordenadas do MUNDO (antes do zoom da câmera).
const GROUND_Y := 790.0          # topo do trilho
const LOCO_X := 940.0            # origem da locomotiva (fundo da cabine)
const TENDER_X := LOCO_X - 242.0 # origem do tender
const DRIVER_R := 44.0           # raio das rodas motrizes
const CRANK_R := 16.0            # raio da manivela (bielas)
const SMOKE_MAX := 70
const SKY_SCALE := GROUND_Y / 470.0  # alturas do céu dos temas (feitos para 470 px)

const MOUNTAIN_TILE := 1920.0
const HILL_TILE := 1700.0
const CITY_TILE := 2000.0
const TREE_TILE := 1800.0
const CLOUD_TILE := 2200.0
const FRONT_TILE := 1900.0
const TRACK_TILE := 1300.0       # múltiplo de 52 (dormentes)
const POLE_SPACING := 360.0
const WEATHER_TILE := 2800.0
const WEATHER_COUNT := 130
## Segundos da fusão entre dois temas (formato das árvores, clima).
const THEME_BLEND_SECONDS := 5.0

## Rolagem visual = scroll_per_sqrt_speed * raiz(velocidade) px/s do mundo — estético.
@export var scroll_per_sqrt_speed: float = 115.0
## Velocidade (m/s) a partir da qual os efeitos estão no máximo — estético.
@export var full_effect_speed: float = 40.0

# Paleta (ferrovia antiga, cartoon)
const INK := Color(0.13, 0.07, 0.07)
const INK_W := 3.5
const WINE := Color(0.58, 0.13, 0.16)
const WINE_DARK := Color(0.38, 0.07, 0.10)
const WINE_LIGHT := Color(0.76, 0.26, 0.25)
const WOOD := Color(0.58, 0.36, 0.19)
const WOOD_DARK := Color(0.40, 0.23, 0.12)
const CHARCOAL := Color(0.18, 0.16, 0.17)
const CHARCOAL_LIGHT := Color(0.32, 0.30, 0.31)
const METAL := Color(0.62, 0.61, 0.60)
const BRASS := Color(0.92, 0.70, 0.30)       # ouro envelhecido
const BRASS_DARK := Color(0.64, 0.44, 0.17)
const COPPER := Color(0.82, 0.46, 0.24)
const BRONZE := Color(0.68, 0.47, 0.25)
const CREAM := Color(0.98, 0.92, 0.78)
const WARM_LIGHT := Color(1.0, 0.80, 0.40)
const SKIN := Color(0.98, 0.77, 0.60)
const OVERALL := Color(0.26, 0.32, 0.46)
const CONFETTI := [Color(0.92, 0.70, 0.30), Color(0.76, 0.26, 0.25), Color(0.98, 0.92, 0.78), Color(0.30, 0.66, 0.62), Color(0.95, 0.52, 0.20)]

var _speed_mps: float = 0.0
var _speed_ratio: float = 0.0
var _time: float = 0.0
var _wheel_angle: float = 0.0
var _last_chuff_quarter: int = 0

# Deslocamentos de rolagem (cada um volta no próprio tamanho de bloco).
var _off_mountain: float = 0.0
var _off_hill: float = 0.0
var _off_city: float = 0.0
var _off_tree: float = 0.0
var _off_cloud: float = 0.0
var _off_track: float = 0.0
var _off_poles: float = 0.0
var _off_front: float = 0.0
var _off_dots: float = 0.0

## Tema atual, tema anterior e fusão entre eles (1 = troca concluída).
var _theme_id: String = SeasonThemes.DEFAULT
var _prev_theme_id: String = SeasonThemes.DEFAULT
var _blend: float = 1.0
## Valores contínuos do tema (cores e números), interpolados a cada frame.
var _cur: Dictionary = {}

var _trees: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _stars: Array[Vector3] = []
var _weather: Array[Dictionary] = []
var _dots: Array[Vector3] = []

var _mountain_points: PackedVector2Array
var _hill_points: PackedVector2Array
var _buildings: Array[Dictionary] = []
var _tufts: Array[Vector2] = []

var _smoke: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _celebration: Array[Dictionary] = []
var _station_signs: Array[Dictionary] = []

## Peças gastas (< limite de aviso), atualizado algumas vezes por segundo.
var _worn: Dictionary = {}
var _worn_timer: float = 0.0
var _in_maintenance: bool = false
## Estado atual do trem (TrainMovement.State) e pressão da caldeira (0 a 1).
var _train_state: int = TrainMovement.State.CRUISING
var _stoke: float = 0.0
## Peça que quebrou (para soltar vapor dela enquanto freia/conserta).
var _failed_id: String = ""
## Placa da estação em aproximação (desliza até parar ao lado do trem).
var _approach_sign: Dictionary = {}
var _approach_start_m: float = 0.0
## Tremor da câmera (falha de peça, frenagem forte).
var _shake: float = 0.0

var _rng := RandomNumberGenerator.new()
var _font: Font

## Canvas onde as funções de desenho escrevem (a camada sendo desenhada).
var _ci: CanvasItem = self
## Tamanho do mundo visível (tela / zoom) usado pelas camadas.
var _size := Vector2(1280, 720) / 0.58
## Camadas fixas precisam ser redesenhadas (tema mudou, janela mudou).
var _static_dirty: bool = true
var _static_layers: Array[Layer] = []
var _live_layers: Array[Layer] = []
var _layers: Dictionary = {}
## Medição de tempo por camada (usado pelo benchmark).
var profile_layers: bool = false
var layer_usec: Dictionary = {}
var _frame: int = 0


func _ready() -> void:
	_rng.seed = 1857
	_font = ThemeDB.fallback_font
	_dot = HudSkin.dot_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_build_mountains()
	_build_city()
	for i in 22:
		_tufts.append(Vector2(_rng.randf_range(0, FRONT_TILE), _rng.randf_range(0.0, 1.0)))
	_build_scenery_extras()
	_cur = SeasonThemes.continuous_of(_theme_id)
	_build_layers()
	get_viewport().size_changed.connect(func(): _static_dirty = true)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.station_reached.connect(_on_station_reached)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.component_failed.connect(_on_component_failed)
	EventBus.train_state_changed.connect(_on_train_state_changed)


func _on_speed_changed(speed_mps: float, _target: float, stoke: float) -> void:
	_speed_mps = speed_mps
	_stoke = stoke
	_speed_ratio = clampf(speed_mps / full_effect_speed, 0.0, 1.0)


func _on_game_loaded() -> void:
	var game := get_node_or_null(game_path)
	if game and game.state:
		# Ao carregar, o tema entra direto, sem transição.
		_theme_id = SeasonThemes.id_for_route(game.state.route)
		_prev_theme_id = _theme_id
		_blend = 1.0
		_cur = SeasonThemes.continuous_of(_theme_id)
		_static_dirty = true
		theme_changed.emit(_theme_id)


func _on_station_reached(index: int, station_name: String) -> void:
	var new_theme := str(Balance.stations[index].get("theme", SeasonThemes.DEFAULT))
	if SeasonThemes.has(new_theme) and new_theme != _theme_id:
		_prev_theme_id = _theme_id
		_theme_id = new_theme
		_blend = 0.0
		theme_changed.emit(_theme_id)
	if _approach_sign.is_empty() or _approach_sign["name"] != station_name:
		_station_signs.append({"x": _size.x + 40.0, "name": station_name})
	for i in 90:
		_celebration.append({
			"pos": Vector2(LOCO_X + 120.0, GROUND_Y - 300.0),
			"vel": Vector2(_rng.randf_range(-380, 380), _rng.randf_range(-620, -180)),
			"rot": _rng.randf_range(0, TAU), "spin": _rng.randf_range(-9, 9),
			"life": _rng.randf_range(1.8, 2.8), "size": _rng.randf_range(6, 13),
			"gear": _rng.randf() < 0.35, "color": _rng.randi_range(0, CONFETTI.size() - 1),
		})


func _on_train_state_changed(st: int) -> void:
	var previous := _train_state
	_train_state = st
	_in_maintenance = st == TrainMovement.State.MAINTENANCE or st == TrainMovement.State.BRAKING
	if not _in_maintenance:
		_failed_id = ""
	if st == TrainMovement.State.APPROACHING and previous != TrainMovement.State.APPROACHING:
		_start_station_approach()
	elif st != TrainMovement.State.APPROACHING and st != TrainMovement.State.AT_STATION:
		_approach_sign = {}


## A placa entra pela direita e desliza conforme a distância que falta,
## parando com a plataforma embaixo do trem.
func _start_station_approach() -> void:
	var game := get_node_or_null(game_path)
	if not game or not game.state:
		return
	var st: GameState = game.state
	_approach_sign = {"x": _size.x + 40.0, "name": st.route.next_station_name(), "start_x": _size.x + 40.0}
	_approach_start_m = st.route.target_distance(st.route.reached_count) - st.train.distance_m
	_station_signs.append(_approach_sign)


## Peça quebrou: nuvem de vapor, faíscas e um tranco na câmera.
func _on_component_failed(id: String, _name: String) -> void:
	_in_maintenance = true
	_failed_id = id
	_shake = 1.0
	for i in 30:
		_smoke.append({
			"pos": Vector2(LOCO_X + _rng.randf_range(80, 400), GROUND_Y - _rng.randf_range(40, 200)),
			"vel": Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-130, -30)),
			"r": _rng.randf_range(9, 20), "life": 1.0, "decay": _rng.randf_range(0.5, 0.9), "shade": 1.0, "steam": true,
		})
	for i in 14:
		_sparks.append({"pos": Vector2(LOCO_X + _rng.randf_range(80, 320), GROUND_Y - 40.0),
			"vel": Vector2(_rng.randf_range(-240, 240), _rng.randf_range(-380, -140)), "life": _rng.randf_range(0.4, 0.9)})


func _refresh_worn() -> void:
	_worn.clear()
	var game := get_node_or_null(game_path)
	if not game or not game.state:
		return
	var st: GameState = game.state
	for c in st.maintenance.active_components(st.route):
		if c.integrity < st.config.component_warning_threshold and not c.has_auto():
			_worn[c.id] = true


const WHEEL_XS := [50.0, 145.0, 245.0, 345.0]


## Sinais de peças gastas enquanto o trem anda.
func _emit_wear_effects(delta: float) -> void:
	if _speed_mps <= 0.05:
		return
	if (_worn.has("rodas") or _worn.has("freios")) and _rng.randf() < delta * 14.0:
		var wx: float = WHEEL_XS[_rng.randi() % WHEEL_XS.size()]
		_sparks.append({"pos": Vector2(LOCO_X + wx, GROUND_Y - 3.0),
			"vel": Vector2(_rng.randf_range(-300, -90), _rng.randf_range(-180, -40)), "life": _rng.randf_range(0.2, 0.45)})
	if _worn.has("caldeira") and _rng.randf() < delta * 6.0:
		_smoke.append({"pos": Vector2(LOCO_X + _rng.randf_range(150, 320), GROUND_Y - 180.0 + _bob()),
			"vel": Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-100, -60)), "r": 5.0, "life": 0.7, "decay": 1.3,
			"shade": 1.0, "steam": true})
	if _worn.has("engates") and _rng.randf() < delta * 8.0:
		_sparks.append({"pos": Vector2(LOCO_X - 8.0, GROUND_Y - 58.0),
			"vel": Vector2(_rng.randf_range(-120, 60), _rng.randf_range(-130, -30)), "life": 0.3})


# ---------------------------------------------------------------------------
# Animação
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var scroll := scroll_per_sqrt_speed * sqrt(maxf(_speed_mps, 0.0))
	_off_mountain = fmod(_off_mountain + scroll * 0.05 * delta, MOUNTAIN_TILE)
	_off_hill = fmod(_off_hill + scroll * 0.12 * delta, HILL_TILE)
	_off_city = fmod(_off_city + scroll * 0.22 * delta, CITY_TILE)
	_off_tree = fmod(_off_tree + scroll * 0.45 * delta, TREE_TILE)
	_off_cloud = fmod(_off_cloud + (8.0 + scroll * 0.02) * delta, CLOUD_TILE)
	_off_track = fmod(_off_track + scroll * delta, TRACK_TILE)
	_off_poles = fmod(_off_poles + scroll * delta, POLE_SPACING)
	_off_front = fmod(_off_front + scroll * 1.5 * delta, FRONT_TILE)
	_off_dots = fmod(_off_dots + scroll * 1.2 * delta, FRONT_TILE)
	_wheel_angle += scroll / DRIVER_R * delta

	# Baforadas: 4 por volta da roda, como numa locomotiva de dois cilindros.
	var quarter := int(floor(_wheel_angle / (TAU / 4.0)))
	if quarter != _last_chuff_quarter and _speed_mps > 0.05:
		_last_chuff_quarter = quarter
		_emit_puff()
		chuffed.emit(_speed_ratio)

	# Céu muda suavemente de paleta quando a estação muda.
	var target := SeasonThemes.get_theme(_theme_id)
	var k := minf(1.0, delta * 0.7)
	for key in SeasonThemes.CONTINUOUS:
		if target[key] is Color:
			var from: Color = _cur[key]
			var to: Color = target[key]
			if from != to:
				_static_dirty = true
				var diff := absf(from.r - to.r) + absf(from.g - to.g) + absf(from.b - to.b) + absf(from.a - to.a)
				_cur[key] = to if diff < 0.004 else from.lerp(to, k)
		elif _cur[key] != target[key]:
			_static_dirty = true
			var fv: float = _cur[key]
			var tv: float = target[key]
			_cur[key] = tv if absf(fv - tv) < 0.002 * maxf(1.0, absf(tv)) else lerpf(fv, tv, k)
	if _blend < 1.0:
		_static_dirty = true
	_blend = minf(1.0, _blend + delta / THEME_BLEND_SECONDS)

	_worn_timer -= delta
	if _worn_timer <= 0.0:
		_worn_timer = 0.3
		_refresh_worn()
	_emit_wear_effects(delta)
	_emit_state_effects(delta)

	_update_particles(delta, scroll)
	_update_layers(delta)


## Efeitos de frenagem, falha e caldeira atiçada.
func _emit_state_effects(delta: float) -> void:
	var braking := _train_state == TrainMovement.State.BRAKING
	var approaching := _train_state == TrainMovement.State.APPROACHING
	# Faíscas das rodas travando (forte na falha, leve chegando na estação).
	if (braking or approaching) and _speed_mps > 0.3:
		var rate := 40.0 if braking else 10.0
		if _rng.randf() < delta * rate:
			var wx: float = WHEEL_XS[_rng.randi() % WHEEL_XS.size()]
			for i in (3 if braking else 1):
				_sparks.append({"pos": Vector2(LOCO_X + wx + _rng.randf_range(-10, 10), GROUND_Y - 3.0),
					"vel": Vector2(_rng.randf_range(120, 380), _rng.randf_range(-200, -40)), "life": _rng.randf_range(0.25, 0.5)})
		if braking:
			_shake = maxf(_shake, 0.25)
	# Vapor escapando da peça quebrada (freando e durante o conserto).
	if _in_maintenance and _rng.randf() < delta * (14.0 if braking else 5.0):
		var at := _failed_part_position()
		_smoke.append({"pos": at + Vector2(_rng.randf_range(-16, 16), _rng.randf_range(-10, 10)),
			"vel": Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-150, -60)), "r": _rng.randf_range(7, 14),
			"life": 1.0, "decay": _rng.randf_range(0.7, 1.1), "shade": -0.6 if braking else 1.0, "steam": not braking})
	# Caldeira atiçada: brasas extras saindo da chaminé.
	if _stoke > 0.15 and _speed_mps > 0.3 and _rng.randf() < delta * 12.0 * _stoke:
		_sparks.append({"pos": _chimney_top(), "vel": Vector2(_rng.randf_range(-140, 40), _rng.randf_range(-380, -170)), "life": _rng.randf_range(0.4, 0.9)})


func _chimney_top() -> Vector2:
	return Vector2(LOCO_X + 316.0, GROUND_Y - 266.0 + _bob())


## Onde fica (aproximadamente) cada peça na locomotiva.
func _failed_part_position() -> Vector2:
	match _failed_id:
		"rodas", "freios":
			return Vector2(LOCO_X + 195.0, GROUND_Y - 40.0)
		"pistoes":
			return Vector2(LOCO_X + 338.0, GROUND_Y - 71.0)
		"chamine":
			return Vector2(LOCO_X + 316.0, GROUND_Y - 255.0)
		"engates":
			return Vector2(LOCO_X - 8.0, GROUND_Y - 58.0)
		_:
			return Vector2(LOCO_X + 225.0, GROUND_Y - 140.0)  # caldeira


func _emit_puff() -> void:
	if _smoke.size() >= SMOKE_MAX:
		_smoke.pop_front()
	var chimney := _chimney_top()
	_smoke.append({
		"pos": chimney, "vel": Vector2(_rng.randf_range(-30, 15), _rng.randf_range(-160, -100) * (0.7 + _speed_ratio)),
		"r": _rng.randf_range(11, 16), "life": 1.0, "decay": _rng.randf_range(0.35, 0.55),
		"shade": _rng.randf_range(0.0, 0.25) - (1.2 if _worn.has("chamine") else 0.0), "steam": false,
	})
	var cylinder := Vector2(LOCO_X + 380.0, GROUND_Y - 60.0)
	# Vapor escapando do cilindro (bem mais com os pistões gastos)
	if _worn.has("pistoes"):
		for i in 3:
			_smoke.append({"pos": cylinder, "vel": Vector2(_rng.randf_range(30, 130), _rng.randf_range(-70, 0)),
				"r": 8.0, "life": 0.8, "decay": 1.1, "shade": 1.0, "steam": true})
	_smoke.append({
		"pos": cylinder, "vel": Vector2(_rng.randf_range(40, 90), _rng.randf_range(-35, -5)),
		"r": 6.0, "life": 0.6, "decay": 1.4, "shade": 1.0, "steam": true,
	})
	# Faíscas quando o trem está rápido
	if _speed_ratio > 0.35 and _rng.randf() < _speed_ratio:
		for i in 3:
			_sparks.append({"pos": chimney, "vel": Vector2(_rng.randf_range(-170, 60), _rng.randf_range(-320, -120)), "life": _rng.randf_range(0.4, 0.8)})


func _update_particles(delta: float, scroll: float) -> void:
	var wind := -scroll * 0.55  # a fumaça fica para trás conforme a velocidade
	for p in _smoke:
		var steam: bool = p["steam"]
		p["pos"] += (p["vel"] + Vector2(wind * (0.3 if steam else 1.0), 0.0)) * delta
		p["vel"] *= 0.985
		p["r"] += (20.0 if steam else 30.0) * delta
		p["life"] -= p["decay"] * delta
	_smoke = _smoke.filter(func(p): return p["life"] > 0.0)

	for s in _sparks:
		s["pos"] += (s["vel"] + Vector2(wind * 0.6, 0.0)) * delta
		s["vel"].y += 380.0 * delta
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)

	for c in _celebration:
		c["pos"] += c["vel"] * delta
		c["vel"].y += 480.0 * delta
		c["vel"].x *= 0.99
		c["rot"] += c["spin"] * delta
		c["life"] -= delta
	_celebration = _celebration.filter(func(c): return c["life"] > 0.0)

	# Clima: cada partícula anda sozinha (sem saltos quando o deslocamento volta).
	var drift := (28.0 + scroll * 0.5) * delta
	for w in _weather:
		w["x"] = fposmod(float(w["x"]) - drift * float(w["speed"]), WEATHER_TILE)

	var game := get_node_or_null(game_path)
	for station_sign in _station_signs:
		if station_sign == _approach_sign and game and game.state:
			var st: GameState = game.state
			var stop_x := _platform_stop_x()
			var remaining := 0.0
			if _train_state == TrainMovement.State.APPROACHING and not st.route.is_complete():
				remaining = st.route.target_distance(st.route.reached_count) - st.train.distance_m
			var f := clampf(remaining / maxf(_approach_start_m, 1.0), 0.0, 1.0)
			# curva suave: a placa desacelera junto com o trem
			station_sign["x"] = stop_x + (float(station_sign["start_x"]) - stop_x) * f * f
			continue
		station_sign["x"] -= scroll * delta
	_station_signs = _station_signs.filter(func(s): return s["x"] > -PLATFORM_W - 80.0)


## Balanço vertical da locomotiva (aumenta com a velocidade).
func _bob() -> float:
	return sin(_wheel_angle * 2.0) * (0.8 + 2.2 * _speed_ratio)


# ---------------------------------------------------------------------------
# Geração do cenário
# ---------------------------------------------------------------------------

func _build_mountains() -> void:
	var pts := PackedVector2Array()
	var phases := [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU]
	var x := 0.0
	while x <= MOUNTAIN_TILE:
		var u := x / MOUNTAIN_TILE * TAU
		var h: float = 120.0 + 80.0 * sin(u * 2.0 + phases[0]) + 40.0 * sin(u * 5.0 + phases[1]) + 14.0 * sin(u * 11.0 + phases[2])
		pts.append(Vector2(x, GROUND_Y - 90.0 - h))
		x += 20.0
	_mountain_points = pts
	# Colinas mais perto: curvas suaves e baixas.
	var hills := PackedVector2Array()
	var hp := [_rng.randf() * TAU, _rng.randf() * TAU]
	x = 0.0
	while x <= HILL_TILE:
		var u := x / HILL_TILE * TAU
		var h: float = 70.0 + 34.0 * sin(u * 3.0 + hp[0]) + 16.0 * sin(u * 7.0 + hp[1])
		hills.append(Vector2(x, GROUND_Y - 10.0 - h))
		x += 20.0
	_hill_points = hills


func _build_city() -> void:
	var x := 0.0
	while x < CITY_TILE - 90.0:
		var w := _rng.randf_range(70, 160)
		var h := _rng.randf_range(70, 210)
		_buildings.append({
			"x": x, "w": w, "h": h,
			"chimney": _rng.randf() < 0.55, "cx": _rng.randf_range(0.2, 0.8), "ch": _rng.randf_range(40, 95),
			"gear": _rng.randf() < 0.18, "windows": _rng.randi_range(1, 4), "roof": _rng.randf() < 0.4,
		})
		x += w + _rng.randf_range(14, 90)


## Árvores, nuvens, estrelas, partículas de clima e pontos do campo: posições
## fixas geradas uma vez; o tema decide cor, formato e o que aparece.
func _build_scenery_extras() -> void:
	var x := 0.0
	while x < TREE_TILE - 60.0:
		_trees.append({"x": x, "scale": _rng.randf_range(1.6, 2.6), "color": _rng.randi_range(0, 5),
			"rand": _rng.randf(), "y": _rng.randf_range(-6.0, 8.0)})
		x += _rng.randf_range(110.0, 230.0)
	for i in 9:
		_clouds.append({"x": _rng.randf_range(0, CLOUD_TILE), "y": _rng.randf_range(50, GROUND_Y * 0.42), "scale": _rng.randf_range(1.0, 2.0)})
	for i in 110:
		_stars.append(Vector3(_rng.randf_range(0, 2600), _rng.randf_range(0, GROUND_Y * 0.62), _rng.randf_range(0, TAU)))
	for i in WEATHER_COUNT:
		_weather.append({"x": _rng.randf_range(0, WEATHER_TILE), "y": _rng.randf_range(0, 1100), "speed": _rng.randf_range(0.7, 1.3),
			"phase": _rng.randf_range(0, TAU), "size": _rng.randf_range(0.9, 1.8), "color": _rng.randi_range(0, 5)})
	for i in 150:
		_dots.append(Vector3(_rng.randf_range(0, FRONT_TILE), _rng.randf_range(0.0, 1.0), _rng.randi_range(0, 5)))


## Pesos da fusão entre o tema anterior e o atual: a primeira metade faz o
## novo aparecer por cima; a segunda faz o antigo sumir.
func _blend_weights() -> Array:
	if _blend >= 1.0 or _prev_theme_id == _theme_id:
		return [[_theme_id, 1.0]]
	return [[_prev_theme_id, clampf((1.0 - _blend) * 2.0, 0.0, 1.0)], [_theme_id, clampf(_blend * 2.0, 0.0, 1.0)]]


# ---------------------------------------------------------------------------
# Traço cartoon em quads (desempenho)
# ---------------------------------------------------------------------------
# No renderizador de compatibilidade cada círculo/polígono/linha grossa vira
# uma chamada de desenho própria. Aqui QUASE TUDO é um quad (draw_primitive de
# 4 pontos) com a MESMA textura (um círculo branco suavizado): o círculo usa a
# textura inteira; retângulos, linhas e triângulos usam o centro branco. Quads
# com a mesma textura entram no mesmo lote: milhares de formas, poucas chamadas.

var _dot: Texture2D
var UV_FULL := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
var UV_FILL := PackedVector2Array([Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5)])


func _quad(p: PackedVector2Array, col: Color) -> void:
	_ci.draw_primitive(p, PackedColorArray([col, col, col, col]), UV_FILL, _dot)


func _rect(r: Rect2, col: Color, filled: bool = true, width: float = 1.0) -> void:
	if not filled:
		var h := width * 0.5
		_rect(Rect2(r.position.x - h, r.position.y - h, r.size.x + width, width), col)
		_rect(Rect2(r.position.x - h, r.end.y - h, r.size.x + width, width), col)
		_rect(Rect2(r.position.x - h, r.position.y + h, width, r.size.y - width), col)
		_rect(Rect2(r.end.x - h, r.position.y + h, width, r.size.y - width), col)
		return
	_quad(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col)


func _circle(c: Vector2, r: float, col: Color) -> void:
	_ci.draw_primitive(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)]),
		PackedColorArray([col, col, col, col]), UV_FULL, _dot)


func _line(a: Vector2, b: Vector2, col: Color, w: float = 1.0) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := d.normalized().orthogonal() * (w * 0.5)
	_quad(PackedVector2Array([a + n, b + n, b - n, a - n]), col)


## Linha com vários pontos: segmentos + juntas redondas (linhas grossas).
func _polyline(pts: PackedVector2Array, col: Color, w: float = 1.0) -> void:
	for i in range(pts.size() - 1):
		_line(pts[i], pts[i + 1], col, w)
	if w > 2.5:
		for i in range(1, pts.size() - 1):
			_circle(pts[i], w * 0.5, col)


func _arc(c: Vector2, r: float, a0: float, a1: float, segs: int, col: Color, w: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in segs + 1:
		var a := a0 + (a1 - a0) * i / segs
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	_polyline(pts, col, w)


## Polígono: até 4 pontos vira quad (em lote); mais que isso, polígono comum.
func _poly(pts: PackedVector2Array, col: Color) -> void:
	match pts.size():
		3:
			_quad(PackedVector2Array([pts[0], pts[1], pts[2], pts[2]]), col)
		4:
			_quad(pts, col)
		_:
			_ci.draw_colored_polygon(pts, col)


## Degradê de 4 pontos (céu, campo) com cor por vértice.
func _grad(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	_ci.draw_primitive(pts, cols, UV_FILL, _dot)


## Retângulo de cantos arredondados: 3 retângulos + 4 círculos (tudo quad).
func _rrect(r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2.0, r.size.y), col)
	_rect(Rect2(r.position.x, r.position.y + rad, rad, r.size.y - rad * 2.0), col)
	_rect(Rect2(r.end.x - rad, r.position.y + rad, rad, r.size.y - rad * 2.0), col)
	for c in [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad), r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]:
		_circle(c, rad, col)


func _ink_rect(r: Rect2, fill: Color, w: float = INK_W, ink: Color = INK) -> void:
	_rect(r.grow(w), ink)
	_rect(r, fill)


func _ink_circle(c: Vector2, r: float, fill: Color, w: float = INK_W, ink: Color = INK) -> void:
	_circle(c, r + w, ink)
	_circle(c, r, fill)


func _ink_rrect(r: Rect2, rad: float, fill: Color, w: float = INK_W, ink: Color = INK) -> void:
	_rrect(r.grow(w), rad + w, ink)
	_rrect(r, rad, fill)


## Polígono deslocado `w` para fora (contorno de tinta de formas convexas ou
## quase: triângulos, quadriláteros, chaminé, monte de carvão).
func _offset_poly(pts: PackedVector2Array, w: float) -> PackedVector2Array:
	var n := pts.size()
	var area := 0.0
	for i in n:
		area += pts[i].cross(pts[(i + 1) % n])
	var sgn := 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		var e1 := (b - a).normalized()
		var e2 := (c - b).normalized()
		if e1 == Vector2.ZERO:
			e1 = e2
		if e2 == Vector2.ZERO:
			e2 = e1
		var n1 := Vector2(e1.y, -e1.x) * sgn
		var n2 := Vector2(e2.y, -e2.x) * sgn
		var nm := (n1 + n2).normalized()
		if nm == Vector2.ZERO:
			nm = n1
		out[i] = b + nm * (w / maxf(nm.dot(n1), 0.35))
	return out


## Contorno de um polígono (desenhado por baixo do preenchimento).
func _ink_outline(pts: PackedVector2Array, w: float, ink: Color) -> void:
	_poly(_offset_poly(pts, w), ink)


func _ink_poly(pts: PackedVector2Array, fill: Color, w: float = INK_W, ink: Color = INK) -> void:
	_ink_outline(pts, w, ink)
	_poly(pts, fill)


## Engrenagem com contorno exato (engrenagem maior por baixo).
func _ink_gear(c: Vector2, r_out: float, r_in: float, teeth: int, rot: float, fill: Color, w: float = INK_W, ink: Color = INK) -> void:
	_poly(_gear(c, r_out + w, r_in + w, teeth, rot), ink)
	_poly(_gear(c, r_out, r_in, teeth, rot), fill)


## Grupo de formas com UM contorno (silhueta): primeiro a tinta de todas,
## depois os preenchimentos. Formas: ["r", Rect2, cor], ["c", centro, raio, cor],
## ["q", Rect2, raio do canto, cor], ["p", pontos, cor].
func _ink_group(shapes: Array, w: float = INK_W, ink: Color = INK) -> void:
	for s in shapes:
		match s[0]:
			"r":
				_rect((s[1] as Rect2).grow(w), ink)
			"c":
				_circle(s[1], float(s[2]) + w, ink)
			"q":
				_rrect((s[1] as Rect2).grow(w), float(s[2]) + w, ink)
			"p":
				_ink_outline(s[1], w, ink)
	for s in shapes:
		match s[0]:
			"r":
				_rect(s[1], s[2])
			"c":
				_circle(s[1], s[2], s[3])
			"q":
				_rrect(s[1], s[2], s[3])
			"p":
				_poly(s[1], s[2])


# ---------------------------------------------------------------------------
# Camadas
# ---------------------------------------------------------------------------

## A TrainView não desenha nada nela mesma: tudo vai para as camadas.
func _draw() -> void:
	pass


func _add_layer(layer_name: String, fn: Callable, live: bool, every: int = 1) -> Layer:
	var layer := Layer.new()
	layer.every = every
	layer.name = layer_name
	layer.layer_name = layer_name
	layer.fn = fn
	layer.view = self
	add_child(layer)
	_layers[layer_name] = layer
	if live:
		_live_layers.append(layer)
	else:
		_static_layers.append(layer)
	return layer


## Ordem = ordem de desenho (do fundo para a frente).
func _build_layers() -> void:
	_add_layer("SkyGradient", _layer_sky_gradient, false)
	_add_layer("SkyFx", _layer_sky_fx, true, 4)       # estrelas/raios: lentos
	_add_layer("Sun", _layer_sun, false)
	_add_layer("Clouds", _layer_clouds, false)
	_add_layer("Mountains", _layer_mountains, false)
	_add_layer("Hills", _layer_hills, false)
	_add_layer("City", _layer_city, false)
	_add_layer("CityFx", _layer_city_fx, true, 3)     # fumacinha distante: lenta
	_add_layer("Trees", _layer_trees, false)
	_add_layer("Ground", _layer_ground, false)
	_add_layer("GroundFx", _layer_ground_fx, true)
	_add_layer("Dots", _layer_dots, false)
	_add_layer("Track", _layer_track, false)
	_add_layer("Rail", _layer_rail, false)
	_add_layer("Signs", _draw_station_signs, true)
	_add_layer("Poles", _layer_poles, false)
	_add_layer("SmokeBack", _draw_smoke.bind(true), true)
	_add_layer("TenderBody", _layer_tender_body, false)
	_add_layer("TenderRims", _layer_tender_rims, false)
	_add_layer("TenderWheels", _layer_tender_wheels, true)
	_add_layer("Beam", _layer_beam, true)
	_add_layer("LocoBody", _layer_loco_body, false)
	_add_layer("LocoRims", _layer_loco_rims, false)
	_add_layer("LocoFx", _layer_loco_fx, true)
	_add_layer("Front", _layer_front, true)
	_add_layer("Tufts", _layer_tufts, false)
	_add_layer("Overlay", _layer_overlay, true)


## Uma vez por quadro: câmera, posição das camadas fixas e redesenho do necessário.
func _update_layers(delta: float = 0.0) -> void:
	scale = Vector2.ONE * camera_zoom
	var size := get_viewport_rect().size / camera_zoom
	if size != _size:
		_size = size
		_static_dirty = true
	# Tranco da câmera (decai rápido). Só move o nó: nada é redesenhado.
	_shake = maxf(0.0, _shake - delta * 2.2)
	position = Vector2(sin(_time * 53.0), cos(_time * 41.0)) * 7.0 * _shake * _shake if _shake > 0.0 else Vector2.ZERO
	_layers["Clouds"].position.x = -_off_cloud
	_layers["Mountains"].position.x = -_off_mountain
	_layers["Hills"].position.x = -_off_hill
	_layers["City"].position.x = -_off_city
	_layers["CityFx"].position.x = -_off_city
	_layers["Trees"].position.x = -_off_tree
	_layers["Dots"].position.x = -_off_dots
	_layers["Track"].position.x = -_off_track
	_layers["Poles"].position.x = -_off_poles
	_layers["Tufts"].position.x = -_off_front
	var by := _bob()
	_layers["LocoBody"].position.y = by
	_layers["TenderBody"].position.y = by * 0.6
	if _static_dirty:
		_static_dirty = false
		for layer in _static_layers:
			layer.queue_redraw()
	_frame += 1
	for layer in _live_layers:
		if _frame % layer.every == 0:
			layer.queue_redraw()


## Repete `fn(origem_x)` em blocos de `tile` cobrindo a tela mais um bloco
## (a camada desliza até -tile).
func _tiled(tile: float, fn: Callable) -> void:
	var copies := int(ceil((tile + _size.x) / tile))
	for k in range(-1, copies):
		fn.call(k * tile)


# --- Camadas fixas (desenhadas com deslocamento zero; o nó é que se move) ---

func _layer_sky_gradient() -> void:
	var top: Color = _cur["sky_top"]
	var mid: Color = _cur["sky_mid"]
	var hor: Color = _cur["sky_horizon"]
	var mid_y := GROUND_Y * 0.55
	var w := _size.x + 40.0
	_grad(PackedVector2Array([Vector2(-20, -20), Vector2(w, -20), Vector2(w, mid_y), Vector2(-20, mid_y)]),
		PackedColorArray([top, top, mid, mid]))
	_grad(PackedVector2Array([Vector2(-20, mid_y), Vector2(w, mid_y), Vector2(w, GROUND_Y), Vector2(-20, GROUND_Y)]),
		PackedColorArray([mid, mid, hor, hor]))


func _sun_pos() -> Vector2:
	# limitado para o sol do meio-dia não ficar escondido atrás da placa da rota
	return Vector2(_size.x * float(_cur["sun_x"]), GROUND_Y - minf(float(_cur["sun_y"]) * SKY_SCALE, GROUND_Y - 330.0))


## Sol (dia) ou lua (noite), com contorno suave e brilho em anéis.
func _layer_sun() -> void:
	var sun: Color = _cur["sun"]
	var r: float = float(_cur["sun_r"]) * 1.45
	var moon: float = _cur["moon"]
	var p := _sun_pos()
	for i in 5:
		_circle(p, r + 8.0 + i * 30.0, Color(sun, (0.10 - i * 0.018) * (1.0 - 0.4 * moon)))
	_ink_circle(p, r, sun, 4.0, Color(sun.darkened(0.35), 0.9))
	_circle(p + Vector2(-r * 0.25, -r * 0.28), r * 0.45, Color(1, 1, 1, 0.35))   # brilho
	if moon > 0.02:  # crateras da lua
		var crater := Color(0.66, 0.70, 0.82, 0.65 * moon)
		_circle(p + Vector2(-r * 0.30, -r * 0.05), r * 0.20, crater)
		_circle(p + Vector2(r * 0.28, r * 0.32), r * 0.14, crater)
		_circle(p + Vector2(r * 0.35, -r * 0.35), r * 0.10, crater)


## Nuvens fofas com contorno (opacas: a cor do tema é misturada com o céu).
func _layer_clouds() -> void:
	var cc: Color = _cur["cloud"]
	var col := (_cur["sky_mid"] as Color).lerp(Color(cc, 1.0), cc.a)
	var shade := col.darkened(0.12)
	var ink := Color(col.darkened(0.38), 0.85)
	var parts := [[0, 0, 34], [40, 8, 27], [-38, 10, 25], [14, -18, 26], [72, 16, 19], [-68, 17, 17]]
	_tiled(CLOUD_TILE, func(ox: float):
		for c in _clouds:
			var sc: float = c["scale"]
			var base := Vector2(ox + float(c["x"]), c["y"])
			for part in parts:
				_circle(base + Vector2(part[0], part[1]) * sc, (part[2] + 3.0) * sc, ink)
			for part in parts:
				_circle(base + Vector2(part[0], part[1]) * sc, part[2] * sc, shade)
			for part in parts:  # topo mais claro (luz de cima)
				_circle(base + Vector2(part[0], part[1] - 5.0) * sc, part[2] * 0.85 * sc, col)
	)


func _layer_mountains() -> void:
	var col: Color = _cur["mountain"]
	var caps: float = _cur["caps"]
	var ink := col.darkened(0.35)
	_tiled(MOUNTAIN_TILE, func(ox: float):
		var poly := PackedVector2Array()
		for p in _mountain_points:
			poly.append(Vector2(p.x + ox, p.y))
		var ridge := poly.duplicate()
		poly.append(Vector2(ox + MOUNTAIN_TILE, GROUND_Y))
		poly.append(Vector2(ox, GROUND_Y))
		_poly(poly, col)
		_polyline(ridge, ink, 5.0)
		if caps > 0.02:  # neve nos picos
			var snow_line := GROUND_Y - 290.0
			for i in range(_mountain_points.size() - 1):
				var a := _mountain_points[i] + Vector2(ox, 0)
				var b := _mountain_points[i + 1] + Vector2(ox, 0)
				if a.y < snow_line or b.y < snow_line:
					# fundo da neve nunca acima do próprio ponto (evita polígono invertido)
					var a_bot := Vector2(a.x, maxf(a.y, minf(snow_line, a.y + 30.0)))
					var b_bot := Vector2(b.x, maxf(b.y, minf(snow_line, b.y + 30.0)))
					var cap := PackedVector2Array([a, b])
					if b_bot.y - b.y > 0.5:
						cap.append(b_bot)
					if a_bot.y - a.y > 0.5:
						cap.append(a_bot)
					if cap.size() >= 3:
						_poly(cap, Color(0.92, 0.95, 1.0, 0.9 * caps))
	)


## Colinas entre as montanhas e a cidade: dão profundidade ao mundo maior.
func _layer_hills() -> void:
	var col := (_cur["mountain"] as Color).lerp(_cur["ground_top"], 0.5).darkened(0.08)
	var ink := col.darkened(0.4)
	var light := col.lightened(0.1)
	_tiled(HILL_TILE, func(ox: float):
		var poly := PackedVector2Array()
		for p in _hill_points:
			poly.append(Vector2(p.x + ox, p.y))
		var ridge := poly.duplicate()
		poly.append(Vector2(ox + HILL_TILE, GROUND_Y))
		poly.append(Vector2(ox, GROUND_Y))
		_poly(poly, col)
		var shine := PackedVector2Array()
		for p in ridge:
			shine.append(p + Vector2(0, 10))
		_polyline(shine, light, 6.0)
		_polyline(ridge, ink, 4.5)
	)


func _layer_city() -> void:
	var col: Color = _cur["city"]
	var ink := col.darkened(0.5)
	var lit := Color(WARM_LIGHT, float(_cur["window"]))
	var unlit := col.darkened(0.25)
	var snow: float = _cur["snow"]
	_tiled(CITY_TILE, func(ox: float):
		for b in _buildings:
			var x: float = ox + b["x"]
			if x > _size.x + CITY_TILE or x + b["w"] < -CITY_TILE:
				continue
			var top: float = GROUND_Y - 30.0 - b["h"]
			var shapes := [["r", Rect2(x, top, b["w"], b["h"] + 30.0), col]]
			if b["roof"]:
				shapes.append(["p", PackedVector2Array([Vector2(x - 6, top), Vector2(x + b["w"] * 0.5, top - 34.0), Vector2(x + b["w"] + 6, top)]), col.darkened(0.12)])
			if b["chimney"]:
				var cx: float = x + b["w"] * b["cx"]
				shapes.append(["r", Rect2(cx - 8, top - b["ch"], 16, b["ch"]), col])
			_ink_group(shapes, 3.0, ink)
			if snow > 0.02:  # neve no telhado
				_rect(Rect2(x - 3, top - 4, b["w"] + 6, 7), Color(0.90, 0.94, 1.0, 0.9 * snow))
			# janelas (acesas conforme o tema)
			for wi in b["windows"]:
				var wr := Rect2(x + 12 + wi * 30, top + 20, 13, 17)
				if wr.end.x > x + b["w"] - 6:
					break
				_rect(wr.grow(2), ink)
				_rect(wr, unlit.lerp(lit, lit.a))
				_line(Vector2(wr.position.x, wr.get_center().y), Vector2(wr.end.x, wr.get_center().y), ink, 1.5)
	)


func _layer_trees() -> void:
	for pair in _blend_weights():
		var theme := SeasonThemes.get_theme(pair[0])
		var alpha: float = pair[1]
		if alpha <= 0.01:
			continue
		var colors: Array = theme["tree_colors"]
		_tiled(TREE_TILE, func(ox: float):
			for t in _trees:
				if t["rand"] > theme["tree_density"]:
					continue
				var x: float = ox + t["x"]
				if x < -120.0 or x > _size.x + TREE_TILE:
					continue
				var sc: float = t["scale"]
				var foot := Vector2(x, GROUND_Y - 10.0 + t["y"])
				var col: Color = colors[int(t["color"]) % colors.size()]
				if theme["tree_shape"] == "pine":
					_draw_pine(foot, sc, col, alpha, float(_cur["snow"]))
				else:
					_draw_round_tree(foot, sc, col, alpha, theme["blossom"])
		)


func _draw_round_tree(foot: Vector2, sc: float, col: Color, alpha: float, blossom: bool) -> void:
	var ink := Color(INK, alpha * alpha)
	var c := Color(col, alpha)
	var top := foot + Vector2(0, -66 * sc)
	var blobs := [[Vector2.ZERO, 30.0], [Vector2(-23, 12), 22.0], [Vector2(23, 12), 22.0], [Vector2(0, 16), 22.0]]
	_rect(Rect2(foot.x - 5 * sc, foot.y - 46 * sc, 10 * sc, 46 * sc).grow(2.5), ink)
	for bl in blobs:
		_circle(top + bl[0] * sc, bl[1] * sc + 3.0, ink)
	_rect(Rect2(foot.x - 5 * sc, foot.y - 46 * sc, 10 * sc, 46 * sc), Color(WOOD_DARK, alpha))
	for bl in blobs:
		_circle(top + bl[0] * sc, bl[1] * sc, Color(col.darkened(0.18), alpha))   # sombra
	_circle(top + Vector2(-4, -4) * sc, 26 * sc, c)
	_circle(top + Vector2(-18, 8) * sc, 15 * sc, c)
	_circle(top + Vector2(-10, -12) * sc, 11 * sc, Color(col.lightened(0.22), alpha))  # brilho
	if blossom:
		for i in 7:
			var a := i * 0.9 + foot.x * 0.05
			_circle(top + Vector2(cos(a), sin(a) * 0.8) * (10.0 + (i % 3) * 9.0) * sc, 3.2 * sc, Color(1, 1, 1, 0.85 * alpha))


func _draw_pine(foot: Vector2, sc: float, col: Color, alpha: float, snow: float) -> void:
	var ink := Color(INK, alpha * alpha)
	var trunk := Rect2(foot.x - 4 * sc, foot.y - 16 * sc, 8 * sc, 16 * sc)
	var tiers: Array[PackedVector2Array] = []
	for i in 3:
		var base_y := foot.y - (12.0 + i * 28.0) * sc
		var half := (30.0 - i * 7.0) * sc
		tiers.append(PackedVector2Array([Vector2(foot.x - half, base_y), Vector2(foot.x + half, base_y), Vector2(foot.x, base_y - 42.0 * sc)]))
	_rect(trunk.grow(2.5), ink)
	for t in tiers:
		_ink_outline(t, 2.5, ink)
	_rect(trunk, Color(WOOD_DARK, alpha))
	for t in tiers:
		_poly(t, Color(col, alpha))
		# lado iluminado
		_poly(PackedVector2Array([t[0], t[2], t[0].lerp(t[1], 0.4)]), Color(col.lightened(0.12), alpha))
		if snow > 0.02:  # neve nos galhos
			var tip := t[2]
			var half := (t[1].x - t[0].x) * 0.5
			_poly(PackedVector2Array([tip, tip + Vector2(-half * 0.45, 19.0 * sc), tip + Vector2(0, 13.0 * sc), tip + Vector2(half * 0.45, 19.0 * sc)]),
				Color(0.94, 0.97, 1.0, 0.92 * alpha * snow))


func _layer_ground() -> void:
	# campo (grama, trigo, folhas ou neve, conforme o tema)
	var g_top: Color = _cur["ground_top"]
	var g_bot: Color = _cur["ground_bottom"]
	var w := _size.x + 40.0
	_grad(PackedVector2Array([Vector2(-20, GROUND_Y - 8), Vector2(w, GROUND_Y - 8), Vector2(w, _size.y + 20), Vector2(-20, _size.y + 20)]),
		PackedColorArray([g_top, g_top, g_bot, g_bot]))
	# faixa de luz no horizonte do campo e linha de tinta
	_rect(Rect2(-20, GROUND_Y - 8, w + 20, 6), g_top.lightened(0.12))
	_line(Vector2(-20, GROUND_Y - 8), Vector2(w, GROUND_Y - 8), g_top.darkened(0.45), 3.0)
	# lastro de brita (faixa) com contorno
	var ballast: Color = _cur["ballast"]
	_rect(Rect2(-20, GROUND_Y + 2, w + 20, 34), ballast.darkened(0.45))
	_rect(Rect2(-20, GROUND_Y + 5, w + 20, 28), ballast)


## Calor do verão: faixas tremulando perto do horizonte (camada viva).
func _layer_ground_fx() -> void:
	var haze: float = _cur["haze"]
	if haze > 0.02:
		for i in 5:
			var hy := GROUND_Y - 16.0 - i * 13.0 + sin(_time * 2.2 + i * 1.7) * 3.5
			_line(Vector2(0, hy), Vector2(_size.x, hy), Color(1.0, 0.97, 0.85, 0.07 * haze), 7.0)


## Flores, folhas caídas ou brilho no campo.
func _layer_dots() -> void:
	for pair in _blend_weights():
		var dot_colors: Array = SeasonThemes.get_theme(pair[0])["dots"]
		var a: float = pair[1]
		if dot_colors.is_empty() or a <= 0.01:
			continue
		_tiled(FRONT_TILE, func(ox: float):
			for d in _dots:
				var dy := GROUND_Y + 56.0 + d.y * (_size.y - GROUND_Y - 70.0)
				var col: Color = dot_colors[int(d.z) % dot_colors.size()]
				var r := 3.5 + d.y * 3.5
				var p := Vector2(ox + d.x, dy)
				_circle(p, r + 2.0, Color(INK, 0.55 * a))
				_circle(p, r, Color(col, a))
				_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.5 * a))
		)


## Pedras da brita e dormentes de madeira, em blocos que se repetem.
func _layer_track() -> void:
	var stone: Color = (_cur["ballast"] as Color).lightened(0.2)
	var stone_ink: Color = (_cur["ballast"] as Color).darkened(0.4)
	var tiles := int(ceil(_size.x / TRACK_TILE)) + 1
	for k in tiles:
		var base := k * TRACK_TILE
		for i in 70:
			var r := Rect2(base + fmod(i * 53.0, TRACK_TILE), GROUND_Y + 12 + (i % 4) * 5, 6, 4)
			_rect(r.grow(1.0), stone_ink)
			_rect(r, stone)
	var x := 0.0
	while x < tiles * TRACK_TILE:
		_ink_rect(Rect2(x, GROUND_Y + 1, 36, 12), WOOD, 2.5)
		_rect(Rect2(x, GROUND_Y + 1, 36, 3), WOOD.lightened(0.15))
		x += 52.0


## Trilho de aço com brilho e contorno (fixo, por cima dos dormentes).
func _layer_rail() -> void:
	var w := _size.x + 40.0
	_ink_rect(Rect2(-20, GROUND_Y - 5, w + 20, 9), CHARCOAL_LIGHT, 3.0)
	_rect(Rect2(-20, GROUND_Y - 5, w + 20, 3), METAL.lightened(0.2))


func _layer_poles() -> void:
	var x := -POLE_SPACING
	var tops: Array[Vector2] = []
	var pole := WOOD_DARK
	var ink := INK
	while x < _size.x + POLE_SPACING * 2.0:
		_ink_group([["r", Rect2(x, GROUND_Y - 220, 11, 220), pole], ["r", Rect2(x - 24, GROUND_Y - 208, 59, 8), pole]], 3.0, ink)
		_rect(Rect2(x, GROUND_Y - 220, 4, 220), pole.lightened(0.15))
		for dx in [-18.0, 29.0]:
			_ink_circle(Vector2(x + dx, GROUND_Y - 213), 4.5, CREAM, 2.0, ink)
		tops.append(Vector2(x, GROUND_Y - 213))
		x += POLE_SPACING
	# fios caídos entre os postes
	for i in range(tops.size() - 1):
		for dx in [-18.0, 29.0]:
			var a: Vector2 = tops[i] + Vector2(dx, 0)
			var b: Vector2 = tops[i + 1] + Vector2(dx, 0)
			var pts := PackedVector2Array()
			for s in 9:
				var t := s / 8.0
				pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * 26.0))
			_polyline(pts, Color(INK, 0.85), 2.0)


func _layer_tufts() -> void:
	var c: Color = _cur["tuft"]
	var light := c.lightened(0.18)
	var snow: float = _cur["snow"]
	_tiled(FRONT_TILE, func(ox: float):
		for t in _tufts:
			var x := ox + t.x
			var y := _size.y - 26.0 - t.y * 90.0
			for k in 5:
				var ang := -PI / 2 + (k - 2) * 0.34
				var length := 34.0 + (k % 2) * 16.0 + t.y * 10.0
				var dir := Vector2(cos(ang), sin(ang))
				var side := dir.orthogonal() * 6.5
				var blade := PackedVector2Array([Vector2(x, y) - side, Vector2(x, y) + dir * length, Vector2(x, y) + side])
				_ink_poly(blade, c if k % 2 == 0 else light, 1.8, c.darkened(0.55))
				if snow > 0.02:
					_circle(Vector2(x, y) + dir * length, 4.0, Color(0.96, 0.98, 1.0, snow))
	)


func _layer_tender_body() -> void:
	_draw_tender_body(Vector2(TENDER_X, GROUND_Y))


func _layer_loco_body() -> void:
	_draw_loco_body(Vector2(LOCO_X, GROUND_Y))


func _tender_wheels() -> Array:
	var o := Vector2(TENDER_X, GROUND_Y)
	return [o + Vector2(52, -28), o + Vector2(172, -28)]


func _layer_tender_rims() -> void:
	for c in _tender_wheels():
		_draw_wheel_rim(c, 28.0)


func _layer_loco_rims() -> void:
	for w in _loco_wheels():
		_draw_wheel_rim(w[0], w[1])


## Centro, raio e fator de giro de cada roda da locomotiva.
func _loco_wheels() -> Array:
	var o := Vector2(LOCO_X, GROUND_Y)
	return [[o + Vector2(145, -DRIVER_R), DRIVER_R, 1.0], [o + Vector2(245, -DRIVER_R), DRIVER_R, 1.0],
		[o + Vector2(345, -24), 24.0, DRIVER_R / 24.0], [o + Vector2(50, -24), 24.0, DRIVER_R / 24.0]]


# --- Camadas vivas (redesenhadas a cada quadro) ---

## Estrelas piscando (noite) e raios girando (dia): vivos, mas baratos.
func _layer_sky_fx() -> void:
	var stars: float = _cur["stars"]
	if stars > 0.02:
		for st in _stars:
			if st.x > _size.x:
				continue
			var tw := 0.55 + 0.45 * sin(_time * 1.7 + st.z)
			var c := Color(1, 0.98, 0.9, stars * tw)
			if int(st.z * 10.0) % 5 == 0:  # algumas estrelas em cruz, estilo desenho
				var l := 5.0 + 4.0 * tw
				_line(Vector2(st.x - l, st.y), Vector2(st.x + l, st.y), c, 2.0)
				_line(Vector2(st.x, st.y - l), Vector2(st.x, st.y + l), c, 2.0)
			else:
				_circle(Vector2(st.x, st.y), 1.4 + 1.2 * tw, c)
	var rays: float = _cur["rays"]
	if rays > 0.02:
		var sun: Color = _cur["sun"]
		var r: float = float(_cur["sun_r"]) * 1.45
		var p := _sun_pos()
		for i in 12:
			var ang := i * TAU / 12.0 + _time * 0.08
			var dir := Vector2(cos(ang), sin(ang))
			var length := r * (2.0 + 0.45 * sin(_time * 1.3 + i * 1.9))
			var side := dir.orthogonal() * r * 0.16
			_poly(PackedVector2Array([p + dir * (r + 10.0) - side, p + dir * length, p + dir * (r + 10.0) + side]), Color(sun, 0.30 * rays))


## Fumacinha das chaminés e engrenagens girando da cidade (camada viva).
## Desenhada no espaço da camada da cidade (que se move); só o trecho visível,
## com folga porque ela redesenha a cada poucos quadros.
func _layer_city_fx() -> void:
	var col: Color = _cur["city"]
	var ink := col.darkened(0.5)
	var view_left := _off_city - 200.0
	var view_right := view_left + _size.x + 400.0
	var copies := int(ceil((_size.x + CITY_TILE) / CITY_TILE)) + 1
	for k in copies:
		var base: float = k * CITY_TILE
		for b in _buildings:
			var x: float = base + b["x"]
			if x > view_right or x + b["w"] < view_left:
				continue
			var top: float = GROUND_Y - 30.0 - b["h"]
			if b["chimney"]:
				var cx: float = x + b["w"] * b["cx"]
				for j in 3:
					var t := fmod(_time * 0.4 + j * 0.33 + b["x"] * 0.01, 1.0)
					_circle(Vector2(cx - t * 40.0, top - b["ch"] - 10 - t * 56.0), 7 + t * 14, Color(0.82, 0.78, 0.74, 0.30 * (1.0 - t)))
			if b["gear"]:
				var gc := Vector2(x + b["w"] * 0.5, top - 6)
				_ink_gear(gc, 34, 25, 10, _time * 0.4, col.lightened(0.08), 2.5, ink)
				_ink_circle(gc, 9, (_cur["sky_mid"] as Color).lerp(col, 0.4), 2.0, ink)


func _layer_tender_wheels() -> void:
	for c in _tender_wheels():
		_draw_wheel_spokes(c, 28.0, _wheel_angle * DRIVER_R / 28.0, false)


func _layer_beam() -> void:
	var lamp := Vector2(LOCO_X + 380.0, GROUND_Y - 200.0 + _bob())
	var glow := float(_cur["beam"]) * (1.0 + 0.25 * sin(_time * 7.0))
	if glow > 0.005:
		_poly(PackedVector2Array([lamp, lamp + Vector2(460, -70), lamp + Vector2(460, 120)]), Color(WARM_LIGHT, glow))


func _layer_loco_fx() -> void:
	_draw_loco_fx()


func _layer_front() -> void:
	_draw_smoke(false)
	_draw_sparks()
	_draw_maintenance_icon()
	_draw_weather()


func _layer_overlay() -> void:
	_draw_speed_lines()
	_draw_celebration()


# ---------------------------------------------------------------------------
# Estação: plataforma, postes de luz e placa com o nome
# ---------------------------------------------------------------------------

const PLATFORM_W := 760.0


## Posição de parada da plataforma: o trem inteiro (tender + locomotiva) fica sobre ela.
func _platform_stop_x() -> float:
	return TENDER_X - 60.0


func _draw_station_signs() -> void:
	for station_sign in _station_signs:
		var x: float = station_sign["x"]
		if x > _size.x + 60.0:
			continue
		# plataforma de pedra com borda creme
		var plat := Rect2(x, GROUND_Y - 34, PLATFORM_W, 30)
		_ink_rect(plat, Color(0.62, 0.36, 0.28), 3.0)
		for bx in range(0, int(PLATFORM_W), 38):   # tijolos
			_line(Vector2(x + bx, GROUND_Y - 22), Vector2(x + bx, GROUND_Y - 6), INK, 1.5)
		_line(Vector2(x, GROUND_Y - 16), Vector2(x + PLATFORM_W, GROUND_Y - 16), INK, 1.5)
		_ink_rect(Rect2(x - 6, GROUND_Y - 42, PLATFORM_W + 12, 9), CREAM, 3.0)
		# postes de luz nas pontas
		for lx in [x + 24.0, x + PLATFORM_W - 30.0]:
			_ink_rect(Rect2(lx, GROUND_Y - 190, 8, 150), CHARCOAL, 3.0)
			_circle(Vector2(lx + 4, GROUND_Y - 200), 34, Color(WARM_LIGHT, 0.18))
			_ink_circle(Vector2(lx + 4, GROUND_Y - 200), 12, WARM_LIGHT, 3.0)
			_ink_rect(Rect2(lx - 8, GROUND_Y - 216, 24, 6), CHARCOAL, 2.5)
		# placa pendurada com o nome (acima do trem, para ficar legível)
		var station_name: String = station_sign["name"]
		var fsize := 30
		var w := maxf(220.0, _font.get_string_size(station_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 54.0)
		var cx := x + PLATFORM_W * 0.5
		var board := Rect2(cx - w / 2, GROUND_Y - 420, w, 62)
		for px in [board.position.x + 18.0, board.end.x - 26.0]:
			_ink_rect(Rect2(px, board.end.y, 8, GROUND_Y - 42 - board.end.y), CHARCOAL, 3.0)
		_ink_rrect(board, 10.0, WOOD, 3.5)
		_ink_rrect(board.grow(-8), 6.0, CREAM, 2.5)
		_ci.draw_string(_font, Vector2(board.position.x, board.position.y + 42), station_name, HORIZONTAL_ALIGNMENT_CENTER, w, fsize, WINE_DARK)
		for sx in [board.position.x + 6.0, board.end.x - 6.0]:
			_ink_circle(Vector2(sx, board.get_center().y), 4.0, BRASS, 2.0)


# ---------------------------------------------------------------------------
# Efeitos (fumaça, faíscas, clima, comemoração)
# ---------------------------------------------------------------------------

## behind = true desenha a fumaça antiga (atrás do trem); false, a nova e o vapor.
## Duas passadas (contorno, depois preenchimento) para as baforadas virarem uma
## nuvem só, com traço de desenho.
func _draw_smoke(behind: bool) -> void:
	for pass_i in 2:
		for p in _smoke:
			var steam: bool = p["steam"]
			var is_old: bool = (not steam) and p["life"] <= 0.6
			if is_old != behind:
				continue
			var a: float = clampf(p["life"], 0.0, 1.0)
			var c: Color
			if steam:
				c = Color(1, 1, 1, a * 0.7)
			else:
				var g: float = lerpf(0.40, 0.90, 1.0 - a) + p["shade"] * 0.2
				c = Color(g, g * 0.98, g * 0.95, a * 0.85)
			var r: float = p["r"]
			var pos: Vector2 = p["pos"]
			if pass_i == 0:
				var ink := Color(INK if not steam else Color(0.55, 0.6, 0.7), a * (0.55 if steam else 0.7))
				_circle(pos, r + 3.0, ink)
				if not steam:
					_circle(pos + Vector2(r * 0.6, r * 0.2), r * 0.7 + 3.0, ink)
			else:
				_circle(pos, r, c)
				if not steam:
					_circle(pos + Vector2(r * 0.6, r * 0.2), r * 0.7, c)
					_circle(pos + Vector2(-r * 0.25, -r * 0.3), r * 0.45, Color(1, 1, 1, a * 0.25))


func _draw_sparks() -> void:
	for s in _sparks:
		var a: float = clampf(s["life"] * 1.6, 0.0, 1.0)
		_circle(s["pos"], 8.0, Color(1.0, 0.5, 0.1, a * 0.25))
		_circle(s["pos"], 3.4, Color(1.0, 0.78, 0.3, a))


## Clima em primeiro plano: pétalas (primavera), folhas (outono) ou neve (inverno).
func _draw_weather() -> void:
	for pair in _blend_weights():
		var theme := SeasonThemes.get_theme(pair[0])
		var kind: String = theme["weather"]
		var alpha: float = pair[1]
		if kind == "none" or alpha <= 0.01:
			continue
		var colors: Array = theme["weather_colors"]
		var fall := 50.0 if kind == "petals" else (80.0 if kind == "leaves" else 70.0)
		var count := WEATHER_COUNT if kind == "snow" else WEATHER_COUNT / 2
		for i in count:
			var w: Dictionary = _weather[i]
			var sp: float = w["speed"]
			var ph: float = w["phase"]
			var y := fmod(float(w["y"]) + _time * fall * sp, _size.y + 30.0) - 15.0
			var sway := sin(_time * (1.2 if kind == "snow" else 2.0) * sp + ph) * (14.0 if kind == "snow" else 30.0)
			var x := float(w["x"]) + sway
			if x > _size.x + 20.0:
				continue
			var col := Color(colors[int(w["color"]) % colors.size()], alpha * 0.95)
			var sz: float = w["size"]
			var pos := Vector2(x, y)
			match kind:
				"snow":
					_circle(pos, 3.2 * sz, col)
				"petals":
					var a := _time * 2.5 * sp + ph
					var d := Vector2(cos(a), sin(a)) * 6.0 * sz
					var o := d.orthogonal() * 0.5
					_ink_poly(PackedVector2Array([pos - d, pos + o, pos + d, pos - o]), col, 1.5, Color(INK, 0.5 * alpha))
				"leaves":
					var a := _time * 3.0 * sp + ph
					var u := Vector2(cos(a), sin(a)) * 9.0 * sz
					var v := u.orthogonal() * 0.45
					_ink_poly(PackedVector2Array([pos - u, pos + v, pos + u, pos - v]), col, 1.8, Color(INK, 0.6 * alpha))


func _draw_speed_lines() -> void:
	if _speed_ratio < 0.45:
		return
	var a := (_speed_ratio - 0.45) / 0.55 * 0.35
	for i in 12:
		var y := 100.0 + i * 52.0
		var length := 120.0 + (i * 53) % 160
		var x := fmod(_size.x - fmod(_time * 2000.0 + i * 263.0, _size.x + length), _size.x + length)
		_line(Vector2(x, y), Vector2(x + length, y), Color(1, 1, 1, a), 2.5)


func _draw_celebration() -> void:
	for c in _celebration:
		var a: float = clampf(c["life"], 0.0, 1.0)
		if c["gear"]:
			_ink_gear(c["pos"], c["size"] * 1.3, c["size"], 8, c["rot"], Color(BRASS, a), 2.0, Color(INK, a))
		else:
			var rot: float = c["rot"]
			var d: Vector2 = Vector2(cos(rot), sin(rot)) * float(c["size"]) * 0.7
			var o := d.orthogonal() * 0.5
			var pos: Vector2 = c["pos"]
			_poly(PackedVector2Array([pos - d - o, pos + d - o, pos + d + o, pos - d + o]), Color(CONFETTI[int(c["color"])], a))


# ---------------------------------------------------------------------------
# Locomotiva e tender
# ---------------------------------------------------------------------------

## Carroceria da locomotiva (fixa). O nó da camada aplica o balanço.
## Origem `o`: fundo da cabine, no topo do trilho. Frente para a direita.
func _draw_loco_body(o: Vector2) -> void:
	var b := o
	var boiler := Rect2(b + Vector2(108, -184), Vector2(232, 90))
	var chimney := PackedVector2Array([b + Vector2(298, -182), b + Vector2(334, -182), b + Vector2(340, -220),
		b + Vector2(360, -252), b + Vector2(272, -252), b + Vector2(292, -220)])
	var cow := PackedVector2Array([b + Vector2(380, -60), b + Vector2(436, -4), b + Vector2(380, -4)])
	# Silhueta inteira com um contorno só
	_ink_group([
		["r", Rect2(b + Vector2(-6, -72), Vector2(392, 24)), CHARCOAL],              # chassi
		["p", cow, CHARCOAL_LIGHT],                                                     # limpa-trilhos
		["r", Rect2(b + Vector2(380, -76), Vector2(20, 22)), WINE],                    # para-choque
		["q", boiler, 16.0, WINE],                                         # caldeira
		["r", Rect2(b + Vector2(326, -190), Vector2(48, 106)), CHARCOAL],              # caixa de fumaça
		["c", b + Vector2(376, -137), 50.0, CHARCOAL],                                  # porta da frente
		["p", chimney, CHARCOAL],                                                       # chaminé
		["q", Rect2(b + Vector2(264, -266), Vector2(104, 16)), 6.0, COPPER],
		["c", b + Vector2(232, -184), 27.0, BRASS],                                     # domo de vapor
		["c", b + Vector2(168, -184), 18.0, BRASS],                                     # domo de areia
		["r", Rect2(b + Vector2(126, -212), Vector2(8, 28)), BRASS],                    # apito
		["c", b + Vector2(130, -214), 7.0, BRASS],
		["r", Rect2(b + Vector2(346, -218), Vector2(30, 30)), BRASS],                   # farol
		["r", Rect2(b + Vector2(100, -104), Vector2(282, 12)), WINE_DARK],             # estribo
		["q", Rect2(b + Vector2(298, -92), Vector2(80, 42)), 8.0, BRONZE], # cilindro
		["r", Rect2(b + Vector2(0, -218), Vector2(114, 152)), WINE],                   # cabine
		["q", Rect2(b + Vector2(-16, -240), Vector2(144, 24)), 10.0, CHARCOAL],  # teto
	])

	# Caldeira: sombra embaixo, brilho em cima, cintas de ouro
	_rect(Rect2(b + Vector2(112, -122), Vector2(214, 26)), WINE_DARK)
	_rect(Rect2(b + Vector2(122, -176), Vector2(196, 9)), WINE_LIGHT)
	_rect(Rect2(b + Vector2(140, -173), Vector2(60, 4)), Color(1, 1, 1, 0.25))
	for bx in [158.0, 206.0, 262.0]:
		_rect(Rect2(b + Vector2(bx - 2, -184), Vector2(12, 90)), INK)
		_rect(Rect2(b + Vector2(bx, -184), Vector2(8, 90)), BRASS)
		_rect(Rect2(b + Vector2(bx, -184), Vector2(3, 90)), BRASS.lightened(0.3))
	# Domos: brilho
	_circle(b + Vector2(224, -194), 8.0, BRASS.lightened(0.35))
	_circle(b + Vector2(163, -190), 5.0, BRASS.lightened(0.35))
	# Caixa de fumaça e porta: anéis e rebites
	_arc(b + Vector2(376, -137), 38.0, 0, TAU, 40, INK, 3.0)
	_circle(b + Vector2(376, -137), 36.0, CHARCOAL_LIGHT)
	_arc(b + Vector2(376, -137), 30.0, PI * 1.05, PI * 1.6, 12, METAL, 4.0)
	for i in 8:
		var ang := i * TAU / 8.0
		_ink_circle(b + Vector2(376, -137) + Vector2(cos(ang), sin(ang)) * 26.0, 2.6, BRASS, 1.5)
	_ink_circle(b + Vector2(376, -137), 8.0, BRASS, 2.5)
	_rect(Rect2(b + Vector2(330, -186), Vector2(6, 96)), CHARCOAL_LIGHT)
	# Chaminé: brilho lateral
	_poly(PackedVector2Array([b + Vector2(300, -182), b + Vector2(307, -182), b + Vector2(300, -220), b + Vector2(283, -248), b + Vector2(276, -248), b + Vector2(294, -220)]), CHARCOAL_LIGHT)
	_rect(Rect2(b + Vector2(270, -262), Vector2(92, 4)), COPPER.lightened(0.3))
	# Farol: lente
	_ink_circle(b + Vector2(376, -203), 10.0, WARM_LIGHT, 2.5)
	_circle(b + Vector2(373, -206), 4.0, Color(1, 1, 1, 0.8))
	# Cilindro: tampas e brilho
	for cx in [304.0, 366.0]:
		_rect(Rect2(b + Vector2(cx, -92), Vector2(6, 42)), INK)
	_rect(Rect2(b + Vector2(314, -86), Vector2(46, 6)), BRONZE.lightened(0.25))
	# Estribo: friso de ouro
	_rect(Rect2(b + Vector2(100, -104), Vector2(282, 3)), BRASS)
	# Chassi: rebites
	for rx in range(8, 380, 22):
		_circle(b + Vector2(rx, -60), 2.2, CHARCOAL_LIGHT)

	# Cabine: brilho, sombra, janela, filetes de ouro e placa do número
	_rect(Rect2(b + Vector2(4, -214), Vector2(10, 144)), WINE_LIGHT)
	_rect(Rect2(b + Vector2(96, -214), Vector2(14, 144)), WINE_DARK)
	_line(b + Vector2(114, -216), b + Vector2(114, -66), INK, 3.0)
	_rect(Rect2(b + Vector2(-12, -236), Vector2(136, 5)), CHARCOAL_LIGHT)
	var win := Rect2(b + Vector2(20, -200), Vector2(70, 66))
	_ink_rrect(win, 10.0, CREAM, 3.0)
	_ink_rrect(win.grow(-7), 6.0, Color(0.26, 0.14, 0.10), 2.0)
	_rect(Rect2(b + Vector2(14, -122), Vector2(88, 48)), WINE_DARK, false, 3.0)
	_rect(Rect2(b + Vector2(18, -118), Vector2(80, 40)), BRASS, false, 2.0)
	var plate := Rect2(b + Vector2(30, -112), Vector2(56, 28))
	_ink_rrect(plate, 8.0, BRASS, 2.5)
	_ci.draw_string(_font, plate.position + Vector2(0, 22), "1857", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 18, WINE_DARK)

	var snow: float = _cur["snow"]
	if snow > 0.02:  # neve acumulada no teto da cabine e no alto da caldeira
		var white := Color(0.95, 0.98, 1.0, snow)
		_ink_rrect(Rect2(b + Vector2(-18, -250), Vector2(148, 14)), 7.0, white, 2.5, Color(0.45, 0.55, 0.70, snow))
		_rect(Rect2(b + Vector2(112, -190), Vector2(40, 7)), white)
		_rect(Rect2(b + Vector2(180, -190), Vector2(24, 6)), white)
		_rect(Rect2(b + Vector2(268, -272), Vector2(96, 7)), white)


## Partes vivas da locomotiva: luz da cabine, maquinista, rodas e bielas.
func _draw_loco_fx() -> void:
	var o := Vector2(LOCO_X, GROUND_Y)           # origem: base da cabine, no trilho
	var b := o + Vector2(0, _bob())              # partes presas ao corpo balançam junto
	var flicker := 0.85 + 0.15 * sin(_time * 11.0) * sin(_time * 3.7)
	# luz da fornalha dentro da cabine (mais forte com a caldeira atiçada)
	var inner := Rect2(b + Vector2(27, -193), Vector2(56, 52))
	_rect(inner, Color(1.0, 0.62, 0.25, (0.22 + 0.5 * _stoke) * flicker))
	_draw_engineer(b)
	if _stoke > 0.02:  # brilho em volta da janela
		_circle(b + Vector2(55, -167), 46.0 + 20.0 * _stoke, Color(1.0, 0.5, 0.15, 0.16 * _stoke))

	# Rodas (sem balanço: ficam no trilho)
	for w in _loco_wheels():
		_draw_wheel_spokes(w[0], w[1], _wheel_angle * w[2], w[1] > 30.0)

	# Bielas: barra de acoplamento entre as manivelas e biela até o pistão
	var drivers: Array[Vector2] = [o + Vector2(145, -DRIVER_R), o + Vector2(245, -DRIVER_R)]
	var crank := Vector2(cos(_wheel_angle), sin(_wheel_angle)) * CRANK_R
	var p1: Vector2 = drivers[0] + crank
	var p2: Vector2 = drivers[1] + crank
	var crosshead := b + Vector2(286 + crank.x * 0.9, -71)
	_line(crosshead, b + Vector2(306, -71), INK, 9.0)
	_line(crosshead, b + Vector2(306, -71), METAL, 5.0)
	_line(p2, crosshead, INK, 13.0)
	_line(p2, crosshead, CHARCOAL_LIGHT, 8.0)
	_line(p1 - Vector2(14, 0), p2 + Vector2(14, 0), INK, 14.0)
	_line(p1 - Vector2(14, 0), p2 + Vector2(14, 0), BRASS, 8.0)
	_line(p1 - Vector2(10, 2), p2 + Vector2(10, -2), BRASS.lightened(0.3), 2.0)
	for c in drivers:
		_ink_circle(c + crank, 5.5, METAL, 2.5)
	_ink_rect(Rect2(crosshead - Vector2(10, 8), Vector2(20, 16)), BRONZE, 2.5)


## O maquinista (personagem original): boné, bigodão e nariz grande, debruçado
## na janela. Muda de expressão conforme o que acontece com o trem.
func _draw_engineer(b: Vector2) -> void:
	var worried := _train_state == TrainMovement.State.BRAKING or _in_maintenance
	var at_station := _train_state == TrainMovement.State.AT_STATION
	var happy := not worried and (_stoke > 0.45 or at_station or not _celebration.is_empty())
	var hop := absf(sin(_time * 9.0)) * 3.0 if happy else 0.0
	var shiver := sin(_time * 40.0) * 1.2 if worried else 0.0
	var h := b + Vector2(56 + shiver, -160 - hop)    # centro da cabeça

	# ombros e braço apoiado na janela
	_ink_rrect(Rect2(h + Vector2(-26, 14), Vector2(54, 24)), 10.0, OVERALL, 3.0)
	_rect(Rect2(h + Vector2(-6, 14), Vector2(14, 10)), WINE_LIGHT)   # lenço
	if at_station and not worried:
		# acenando para a plataforma
		var wave := sin(_time * 10.0) * 0.5
		var hand := h + Vector2(44, -26) + Vector2(cos(-1.1 + wave), sin(-1.1 + wave)) * 10.0
		_line(h + Vector2(20, 18), hand, INK, 13.0)
		_line(h + Vector2(20, 18), hand, OVERALL, 8.0)
		_ink_circle(hand, 8.0, SKIN, 3.0)
	else:
		_ink_rrect(Rect2(h + Vector2(8, 22), Vector2(36, 13)), 6.0, OVERALL, 3.0)
		_ink_circle(h + Vector2(46, 28), 7.5, SKIN, 3.0)

	# cabeça
	_ink_circle(h, 19.0, SKIN, 3.5)
	_circle(h + Vector2(-13, 7), 5.0, SKIN.darkened(0.08))            # orelha
	_circle(h + Vector2(9, 6), 5.0, Color(1.0, 0.55, 0.5, 0.45))     # bochecha
	# bigode e nariz
	_ink_circle(h + Vector2(11, 10), 7.0, Color(0.42, 0.28, 0.20), 2.5)
	_ink_circle(h + Vector2(22, 9), 6.5, Color(0.42, 0.28, 0.20), 2.5)
	_ink_circle(h + Vector2(18, 1), 7.0, SKIN.darkened(0.05), 3.0)
	_circle(h + Vector2(16, -2), 2.2, Color(1, 1, 1, 0.6))
	# boca
	if worried:
		_ink_circle(h + Vector2(16, 19), 3.5, Color(0.3, 0.08, 0.08), 2.0)
	elif happy:
		_arc(h + Vector2(15, 14), 7.0, 0.3, PI - 0.3, 8, INK, 3.0)
	# olhos (piscam de vez em quando)
	var blink := fmod(_time + 0.7, 3.7) < 0.12
	for e in [Vector2(2, -6), Vector2(13, -7)]:
		var ec: Vector2 = h + e
		if blink:
			_line(ec + Vector2(-4, 0), ec + Vector2(4, 0), INK, 2.5)
		elif happy:
			_arc(ec + Vector2(0, 2), 4.0, PI + 0.3, TAU - 0.3, 6, INK, 2.5)
		else:
			_ink_circle(ec, 4.2, Color.WHITE, 2.0)
			_circle(ec + Vector2(1.5, 0.5 if not worried else -0.5), 2.0 if not worried else 1.4, INK)
	if worried:  # sobrancelhas aflitas e gota de suor
		_line(h + Vector2(-2, -14), h + Vector2(5, -12), INK, 2.5)
		_line(h + Vector2(10, -12), h + Vector2(17, -14), INK, 2.5)
		var drop := h + Vector2(-16, -14 + fmod(_time * 20.0, 10.0))
		_ink_poly(PackedVector2Array([drop + Vector2(0, -7), drop + Vector2(4, 1), drop + Vector2(-4, 1)]), Color(0.7, 0.88, 1.0), 1.5)
		_circle(drop + Vector2(0, 1), 4.0, Color(0.7, 0.88, 1.0))
	# boné de maquinista com distintivo
	var cap := PackedVector2Array([h + Vector2(-19, -10), h + Vector2(-16, -26), h + Vector2(14, -27), h + Vector2(18, -10)])
	_ink_poly(cap, OVERALL.darkened(0.25), 3.0)
	_ink_poly(PackedVector2Array([h + Vector2(14, -12), h + Vector2(34, -8), h + Vector2(16, -6)]), CHARCOAL, 2.5)
	_rect(Rect2(h + Vector2(-17, -16), Vector2(33, 4)), WINE_LIGHT)
	_ink_circle(h + Vector2(0, -20), 3.5, BRASS, 1.5)


## Corpo do tender (fixo). O nó da camada aplica o balanço; as rodas são vivas.
func _draw_tender_body(o: Vector2) -> void:
	var b := o
	var coal := PackedVector2Array([b + Vector2(10, -182)])
	for i in 10:
		coal.append(b + Vector2(10 + i * 22.6, -194 - (9 if i % 2 == 0 else 3) - (8 if i in [3, 4, 5, 6] else 0)))
	coal.append(b + Vector2(216, -182))
	_ink_group([
		["r", Rect2(b + Vector2(-8, -72), Vector2(242, 24)), CHARCOAL],          # chassi
		["p", coal, CHARCOAL],                                                     # monte de carvão
		["q", Rect2(b + Vector2(0, -180), Vector2(226, 112)), 12.0, WOOD],
		["r", Rect2(b + Vector2(-6, -188), Vector2(238, 14)), WINE],              # borda de cima
		["r", Rect2(b + Vector2(226, -64), Vector2(24, 9)), CHARCOAL_LIGHT],      # engate
	])
	# tábuas de madeira
	for i in 5:
		var y := -164.0 + i * 20.0
		_line(b + Vector2(14, y), b + Vector2(212, y), WOOD_DARK, 2.5)
		_rect(Rect2(b + Vector2(14, y + 3), Vector2(198, 3)), WOOD.lightened(0.1))
	# cantoneiras vinho e rebites
	for cx in [0.0, 208.0]:
		_rect(Rect2(b + Vector2(cx, -174), Vector2(18, 106)), WINE)
		_line(b + Vector2(cx + (18.0 if cx == 0.0 else 0.0), -174), b + Vector2(cx + (18.0 if cx == 0.0 else 0.0), -70), INK, 2.5)
		for ry in range(-164, -74, 18):
			_circle(b + Vector2(cx + 9, ry), 2.4, BRASS_DARK)
	_rect(Rect2(b + Vector2(-6, -188), Vector2(238, 4)), WINE_LIGHT)
	_rect(Rect2(b + Vector2(18, -86), Vector2(190, 14)), WOOD_DARK)   # sombra de baixo
	# brasão de ouro com engrenagem
	var crest := b + Vector2(113, -126)
	_ink_circle(crest, 28.0, WINE_DARK, 3.0)
	_arc(crest, 24.0, 0, TAU, 32, BRASS, 3.0)
	_ink_gear(crest, 17, 12, 9, 0.2, BRASS, 2.0)
	_ink_circle(crest, 5.0, WINE_DARK, 2.0)
	# brilho nos pedaços de carvão
	for i in 7:
		_circle(b + Vector2(26 + i * 28, -198 - (i % 3) * 4), 3.0, CHARCOAL_LIGHT.lightened(0.2))
	# chassi: rebites
	for rx in range(4, 230, 22):
		_circle(b + Vector2(rx, -60), 2.2, CHARCOAL_LIGHT)
	var snow: float = _cur["snow"]
	if snow > 0.02:  # neve sobre o carvão
		for i in 6:
			_ink_circle(b + Vector2(24 + i * 36, -204 - (i % 2) * 6), 8.0, Color(0.95, 0.98, 1.0, 0.9 * snow), 2.0, Color(0.45, 0.55, 0.70, snow))


## Aro da roda (fixo): pneu de aço e disco vinho.
func _draw_wheel_rim(c: Vector2, r: float) -> void:
	_ink_circle(c, r, CHARCOAL, 3.5)
	_circle(c, r - 6.0, WINE)
	_arc(c, r - 6.0, 0, TAU, 36, INK, 2.5)
	_arc(c, r - 2.5, PI * 1.1, PI * 1.6, 10, METAL, 2.5)   # brilho do aço


## Raios, contrapeso e cubo da roda (giram: camada viva).
func _draw_wheel_spokes(c: Vector2, r: float, angle: float, counterweight: bool) -> void:
	var spokes := 10 if r > 30 else 8
	var spoke_col := WINE_DARK
	if counterweight:
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(c + Vector2(cos(angle + PI + 0.9 - i * 0.3), sin(angle + PI + 0.9 - i * 0.3)) * (r - 8.0))
		for i in 7:
			pts.append(c + Vector2(cos(angle + PI - 0.9 + i * 0.3), sin(angle + PI - 0.9 + i * 0.3)) * (r * 0.42))
		_poly(pts, WINE_DARK)
	for i in spokes:
		var a := angle + i * TAU / spokes
		_line(c + Vector2(cos(a), sin(a)) * r * 0.2, c + Vector2(cos(a), sin(a)) * (r - 7.0), spoke_col, 4.0)
	_ink_circle(c, r * 0.24, BRASS, 2.5)
	_circle(c, r * 0.09, CHARCOAL)


## Pontos de uma engrenagem (polígono com dentes).
func _gear(c: Vector2, r_out: float, r_in: float, teeth: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := teeth * 4
	for i in steps:
		var a := rot + i * TAU / steps
		var r := r_out if (i % 4) in [1, 2] else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Engrenagem girando sobre a cabine enquanto o trem está em manutenção.
func _draw_maintenance_icon() -> void:
	if not _in_maintenance:
		return
	var c := Vector2(LOCO_X + 60.0, GROUND_Y - 320.0)
	if _train_state == TrainMovement.State.BRAKING:
		# Alerta piscando enquanto o trem freia por causa da falha.
		if fmod(_time, 0.5) < 0.32:
			var pop := 1.0 + 0.12 * sin(_time * 30.0)
			var tri := PackedVector2Array([c + Vector2(0, -44) * pop, c + Vector2(42, 30) * pop, c + Vector2(-42, 30) * pop])
			_ink_poly(tri, Color(0.98, 0.78, 0.22), 5.0)
			_ci.draw_string(_font, c + Vector2(-30, 24), "!", HORIZONTAL_ALIGNMENT_CENTER, 60, 52, INK)
		return
	var pulse := 0.6 + 0.4 * sin(_time * 6.0)
	_circle(c, 52.0, Color(1.0, 0.6, 0.2, 0.18 * pulse))
	_ink_gear(c, 34, 25, 10, _time * 2.5, BRASS, 3.5)
	_ink_circle(c, 11.0, BRASS_DARK, 3.0)
	_ink_gear(c + Vector2(38, 20), 19, 13, 8, -_time * 4.0, COPPER, 3.0)
	_ink_circle(c + Vector2(38, 20), 6.0, BRASS_DARK, 2.0)
