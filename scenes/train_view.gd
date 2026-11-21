extends Node2D
## TrainView — cenário e locomotiva steampunk, desenhados por código.
##
## Só apresentação: lê a velocidade e os eventos do EventBus e anima.
## Nenhuma regra de jogo vive aqui; tudo pode ser trocado por arte definitiva.
##
## Camadas (do fundo para a frente): céu em degradê, estrelas, sol/lua, nuvens,
## montanhas, cidade industrial, árvores, postes com fios, trilhos, locomotiva
## com tender, fumaça/faíscas, clima (pétalas, folhas, neve) e mato em primeiro plano.
##
## Cada região da rota tem um tema (scenes/season_themes.gd): amanhecer,
## manhã de primavera, meio-dia de verão, fim de tarde de outono, noite de inverno.
##
## Desempenho (v0.2.0): cada camada é um nó filho. As camadas FIXAS (céu,
## montanhas, cidade, árvores, campo, trilho, postes, mato, carroceria do trem)
## são desenhadas UMA vez e só deslizam/balançam mudando a posição do nó; elas
## só se redesenham quando o tema muda ou a janela muda de tamanho. Só as
## camadas VIVAS (rodas, bielas, fumaça, faíscas, clima, brilhos) redesenham
## a cada quadro.


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
## Usado pelo AudioDirector para trocar a variação da música.
signal theme_changed(theme_id: String)

@export var game_path: NodePath

const GROUND_Y := 470.0          # topo do trilho
const LOCO_X := 560.0            # origem da locomotiva (cabine): trem centralizado entre os painéis
const DRIVER_R := 30.0           # raio das rodas motrizes
const CRANK_R := 13.0            # raio da manivela (bielas)
const SMOKE_MAX := 60
const MOUNTAIN_TILE := 1280.0
const CITY_TILE := 1700.0
const POLE_SPACING := 260.0

## Rolagem visual = scroll_per_sqrt_speed * raiz(velocidade) px/s — estético.
@export var scroll_per_sqrt_speed: float = 80.0
## Velocidade (m/s) a partir da qual os efeitos estão no máximo — estético.
@export var full_effect_speed: float = 40.0

# Paleta steampunk
const BRASS := Color(0.85, 0.64, 0.27)
const BRASS_DARK := Color(0.55, 0.38, 0.14)
const COPPER := Color(0.74, 0.40, 0.20)
const IRON := Color(0.11, 0.10, 0.11)
const IRON_LIGHT := Color(0.24, 0.22, 0.23)
const BODY := Color(0.13, 0.33, 0.33)
const BODY_DARK := Color(0.08, 0.21, 0.22)
const WARM_LIGHT := Color(1.0, 0.78, 0.38)

const TREE_TILE := 1500.0
const WEATHER_COUNT := 90
## Segundos da fusão entre dois temas (formato das árvores, clima).
const THEME_BLEND_SECONDS := 5.0

var _speed_mps: float = 0.0
var _speed_ratio: float = 0.0
var _time: float = 0.0
var _wheel_angle: float = 0.0
var _last_chuff_quarter: int = 0

var _off_mountain: float = 0.0
var _off_city: float = 0.0
var _off_near: float = 0.0
var _off_front: float = 0.0

var _off_tree: float = 0.0
var _off_cloud: float = 0.0
var _off_weather: float = 0.0

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

var _rng := RandomNumberGenerator.new()
var _font: Font

## Canvas onde as funções de desenho escrevem (a camada sendo desenhada).
var _ci: CanvasItem = self
## Tamanho da tela usado pelas camadas.
var _size := Vector2(1280, 720)
## Camadas fixas precisam ser redesenhadas (tema mudou, janela mudou).
var _static_dirty: bool = true
var _static_layers: Array[Layer] = []
var _live_layers: Array[Layer] = []
var _layers: Dictionary = {}
## Medição de tempo por camada (usado pelo benchmark).
var profile_layers: bool = false
var layer_usec: Dictionary = {}
var _frame: int = 0

const TRACK_TILE := 1320.0   # múltiplo de 44 (dormentes)
const CLOUD_TILE := 1600.0
const FRONT_TILE := 1400.0


func _ready() -> void:
	_rng.seed = 1857
	_font = ThemeDB.fallback_font
	_build_mountains()
	_build_city()
	for i in 14:
		_tufts.append(Vector2(_rng.randf_range(0, 1400), _rng.randf_range(0.0, 1.0)))
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
		_station_signs.append({"x": get_viewport_rect().size.x + 40.0, "name": station_name})
	for i in 70:
		_celebration.append({
			"pos": Vector2(LOCO_X + 200.0, GROUND_Y - 190.0),
			"vel": Vector2(_rng.randf_range(-260, 260), _rng.randf_range(-420, -120)),
			"rot": _rng.randf_range(0, TAU), "spin": _rng.randf_range(-8, 8),
			"life": _rng.randf_range(1.6, 2.6), "size": _rng.randf_range(4, 9),
			"gear": _rng.randf() < 0.4,
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
	_approach_sign = {"x": get_viewport_rect().size.x + 40.0, "name": st.route.next_station_name(), "start_x": get_viewport_rect().size.x + 40.0}
	_approach_start_m = st.route.target_distance(st.route.reached_count) - st.train.distance_m
	_station_signs.append(_approach_sign)


## Peça quebrou: nuvem de vapor e faíscas em volta da locomotiva.
func _on_component_failed(id: String, _name: String) -> void:
	_in_maintenance = true
	_failed_id = id
	for i in 26:
		_smoke.append({
			"pos": Vector2(LOCO_X + _rng.randf_range(60, 320), GROUND_Y - _rng.randf_range(30, 130)),
			"vel": Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-90, -20)),
			"r": _rng.randf_range(6, 14), "life": 1.0, "decay": _rng.randf_range(0.5, 0.9), "shade": 1.0, "steam": true,
		})
	for i in 12:
		_sparks.append({"pos": Vector2(LOCO_X + _rng.randf_range(60, 240), GROUND_Y - 30.0),
			"vel": Vector2(_rng.randf_range(-160, 160), _rng.randf_range(-260, -100)), "life": _rng.randf_range(0.4, 0.9)})


func _refresh_worn() -> void:
	_worn.clear()
	var game := get_node_or_null(game_path)
	if not game or not game.state:
		return
	var st: GameState = game.state
	for c in st.maintenance.active_components(st.route):
		if c.integrity < st.config.component_warning_threshold and not c.has_auto():
			_worn[c.id] = true


## Sinais de peças gastas enquanto o trem anda.
func _emit_wear_effects(delta: float) -> void:
	if _speed_mps <= 0.05:
		return
	if (_worn.has("rodas") or _worn.has("freios")) and _rng.randf() < delta * 14.0:
		var wx: float = [80.0, 150.0, 220.0][_rng.randi() % 3]
		_sparks.append({"pos": Vector2(LOCO_X + wx, GROUND_Y - 2.0),
			"vel": Vector2(_rng.randf_range(-200, -60), _rng.randf_range(-120, -30)), "life": _rng.randf_range(0.2, 0.45)})
	if _worn.has("caldeira") and _rng.randf() < delta * 6.0:
		_smoke.append({"pos": Vector2(LOCO_X + _rng.randf_range(110, 230), GROUND_Y - 120.0 + _bob()),
			"vel": Vector2(_rng.randf_range(-15, 15), _rng.randf_range(-70, -40)), "r": 3.0, "life": 0.7, "decay": 1.3,
			"shade": 1.0, "steam": true})
	if _worn.has("engates") and _rng.randf() < delta * 8.0:
		_sparks.append({"pos": Vector2(LOCO_X - 8.0, GROUND_Y - 37.0),
			"vel": Vector2(_rng.randf_range(-80, 40), _rng.randf_range(-90, -20)), "life": 0.3})


# ---------------------------------------------------------------------------
# Animação
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var scroll := scroll_per_sqrt_speed * sqrt(maxf(_speed_mps, 0.0))
	_off_mountain = fmod(_off_mountain + scroll * 0.05 * delta, MOUNTAIN_TILE)
	_off_city = fmod(_off_city + scroll * 0.22 * delta, CITY_TILE)
	_off_near = fmod(_off_near + scroll * delta, POLE_SPACING * 10.0)
	_off_front = fmod(_off_front + scroll * 1.5 * delta, 1400.0)
	_off_tree = fmod(_off_tree + scroll * 0.45 * delta, TREE_TILE)
	_off_cloud = fmod(_off_cloud + (6.0 + scroll * 0.02) * delta, 1600.0)
	_off_weather = fmod(_off_weather + (20.0 + scroll * 0.5) * delta, 1400.0)
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
	_update_layers()


## Efeitos de frenagem, falha e caldeira atiçada.
func _emit_state_effects(delta: float) -> void:
	var braking := _train_state == TrainMovement.State.BRAKING
	var approaching := _train_state == TrainMovement.State.APPROACHING
	# Faíscas das rodas travando (forte na falha, leve chegando na estação).
	if (braking or approaching) and _speed_mps > 0.3:
		var rate := 40.0 if braking else 10.0
		if _rng.randf() < delta * rate:
			var wx: float = [80.0, 150.0, 220.0][_rng.randi() % 3]
			for i in (3 if braking else 1):
				_sparks.append({"pos": Vector2(LOCO_X + wx + _rng.randf_range(-8, 8), GROUND_Y - 2.0),
					"vel": Vector2(_rng.randf_range(80, 260), _rng.randf_range(-140, -30)), "life": _rng.randf_range(0.25, 0.5)})
	# Vapor escapando da peça quebrada (freando e durante o conserto).
	if _in_maintenance and _rng.randf() < delta * (14.0 if braking else 5.0):
		var at := _failed_part_position()
		_smoke.append({"pos": at + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-8, 8)),
			"vel": Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-110, -40)), "r": _rng.randf_range(5, 10),
			"life": 1.0, "decay": _rng.randf_range(0.7, 1.1), "shade": -0.6 if braking else 1.0, "steam": not braking})
	# Caldeira atiçada: brasas extras saindo da chaminé.
	if _stoke > 0.15 and _speed_mps > 0.3 and _rng.randf() < delta * 12.0 * _stoke:
		var chimney := Vector2(LOCO_X + 245.0, GROUND_Y - 178.0 + _bob())
		_sparks.append({"pos": chimney, "vel": Vector2(_rng.randf_range(-100, 30), _rng.randf_range(-260, -120)), "life": _rng.randf_range(0.4, 0.9)})


## Onde fica (aproximadamente) cada peça na locomotiva.
func _failed_part_position() -> Vector2:
	match _failed_id:
		"rodas", "freios":
			return Vector2(LOCO_X + 150.0, GROUND_Y - 20.0)
		"pistoes":
			return Vector2(LOCO_X + 286.0, GROUND_Y - 38.0)
		"chamine":
			return Vector2(LOCO_X + 245.0, GROUND_Y - 175.0)
		"engates":
			return Vector2(LOCO_X - 8.0, GROUND_Y - 37.0)
		_:
			return Vector2(LOCO_X + 170.0, GROUND_Y - 110.0)  # caldeira


func _emit_puff() -> void:
	if _smoke.size() >= SMOKE_MAX:
		_smoke.pop_front()
	var chimney := Vector2(LOCO_X + 245.0, GROUND_Y - 178.0 + _bob())
	_smoke.append({
		"pos": chimney, "vel": Vector2(_rng.randf_range(-20, 10), _rng.randf_range(-110, -70) * (0.7 + _speed_ratio)),
		"r": _rng.randf_range(7, 11), "life": 1.0, "decay": _rng.randf_range(0.35, 0.55),
		"shade": _rng.randf_range(0.0, 0.25) - (1.2 if _worn.has("chamine") else 0.0), "steam": false,
	})
	# Vapor escapando do cilindro (bem mais com os pistões gastos)
	if _worn.has("pistoes"):
		for i in 3:
			_smoke.append({"pos": Vector2(LOCO_X + 286.0, GROUND_Y - 38.0), "vel": Vector2(_rng.randf_range(20, 90), _rng.randf_range(-50, 0)),
				"r": 6.0, "life": 0.8, "decay": 1.1, "shade": 1.0, "steam": true})
	_smoke.append({
		"pos": Vector2(LOCO_X + 286.0, GROUND_Y - 38.0), "vel": Vector2(_rng.randf_range(30, 60), _rng.randf_range(-25, -5)),
		"r": 4.0, "life": 0.6, "decay": 1.4, "shade": 1.0, "steam": true,
	})
	# Faíscas quando o trem está rápido
	if _speed_ratio > 0.35 and _rng.randf() < _speed_ratio:
		for i in 3:
			_sparks.append({"pos": chimney, "vel": Vector2(_rng.randf_range(-120, 40), _rng.randf_range(-220, -80)), "life": _rng.randf_range(0.4, 0.8)})


func _update_particles(delta: float, scroll: float) -> void:
	var wind := -scroll * 0.55  # a fumaça fica para trás conforme a velocidade
	for p in _smoke:
		var steam: bool = p["steam"]
		p["pos"] += (p["vel"] + Vector2(wind * (0.3 if steam else 1.0), 0.0)) * delta
		p["vel"] *= 0.985
		p["r"] += (14.0 if steam else 22.0) * delta
		p["life"] -= p["decay"] * delta
	_smoke = _smoke.filter(func(p): return p["life"] > 0.0)

	for s in _sparks:
		s["pos"] += (s["vel"] + Vector2(wind * 0.6, 0.0)) * delta
		s["vel"].y += 260.0 * delta
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)

	for c in _celebration:
		c["pos"] += c["vel"] * delta
		c["vel"].y += 330.0 * delta
		c["vel"].x *= 0.99
		c["rot"] += c["spin"] * delta
		c["life"] -= delta
	_celebration = _celebration.filter(func(c): return c["life"] > 0.0)

	var game := get_node_or_null(game_path)
	for station_sign in _station_signs:
		if station_sign == _approach_sign and game and game.state:
			var st: GameState = game.state
			var stop_x := LOCO_X - 20.0
			var remaining := 0.0
			if _train_state == TrainMovement.State.APPROACHING and not st.route.is_complete():
				remaining = st.route.target_distance(st.route.reached_count) - st.train.distance_m
			var f := clampf(remaining / maxf(_approach_start_m, 1.0), 0.0, 1.0)
			# curva suave: a placa desacelera junto com o trem
			station_sign["x"] = stop_x + (float(station_sign["start_x"]) - stop_x) * f * f
			continue
		station_sign["x"] -= scroll * delta
	_station_signs = _station_signs.filter(func(s): return s["x"] > -420.0)


## Balanço vertical da locomotiva (aumenta com a velocidade).
func _bob() -> float:
	return sin(_wheel_angle * 2.0) * (0.6 + 1.6 * _speed_ratio)


# ---------------------------------------------------------------------------
# Geração do cenário
# ---------------------------------------------------------------------------

func _build_mountains() -> void:
	var pts := PackedVector2Array()
	var phases := [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU]
	var x := 0.0
	while x <= MOUNTAIN_TILE:
		var u := x / MOUNTAIN_TILE * TAU
		var h: float = 70.0 + 45.0 * sin(u * 2.0 + phases[0]) + 25.0 * sin(u * 5.0 + phases[1]) + 10.0 * sin(u * 11.0 + phases[2])
		pts.append(Vector2(x, GROUND_Y - 60.0 - h))
		x += 16.0
	_mountain_points = pts


func _build_city() -> void:
	var x := 0.0
	while x < CITY_TILE - 60.0:
		var w := _rng.randf_range(50, 120)
		var h := _rng.randf_range(50, 150)
		_buildings.append({
			"x": x, "w": w, "h": h,
			"chimney": _rng.randf() < 0.55, "cx": _rng.randf_range(0.2, 0.8), "ch": _rng.randf_range(30, 70),
			"gear": _rng.randf() < 0.18, "windows": _rng.randi_range(1, 3),
		})
		x += w + _rng.randf_range(10, 70)


## Árvores, nuvens, estrelas, partículas de clima e pontos do campo: posições
## fixas geradas uma vez; o tema decide cor, formato e o que aparece.
func _build_scenery_extras() -> void:
	var x := 0.0
	while x < TREE_TILE - 40.0:
		_trees.append({"x": x, "scale": _rng.randf_range(1.1, 1.9), "color": _rng.randi_range(0, 5),
			"rand": _rng.randf(), "y": _rng.randf_range(-4.0, 6.0)})
		x += _rng.randf_range(80.0, 170.0)
	for i in 7:
		_clouds.append({"x": _rng.randf_range(0, 1600), "y": _rng.randf_range(30, 200), "scale": _rng.randf_range(0.7, 1.5)})
	for i in 70:
		_stars.append(Vector3(_rng.randf_range(0, 1280), _rng.randf_range(0, 330), _rng.randf_range(0, TAU)))
	for i in WEATHER_COUNT:
		_weather.append({"x": _rng.randf_range(0, 1400), "y": _rng.randf_range(0, 720), "speed": _rng.randf_range(0.7, 1.3),
			"phase": _rng.randf_range(0, TAU), "size": _rng.randf_range(0.7, 1.4), "color": _rng.randi_range(0, 5)})
	for i in 110:
		_dots.append(Vector3(_rng.randf_range(0, 1400), _rng.randf_range(0.0, 1.0), _rng.randi_range(0, 5)))


## Pesos da fusão entre o tema anterior e o atual: a primeira metade faz o
## novo aparecer por cima; a segunda faz o antigo sumir.
func _blend_weights() -> Array:
	if _blend >= 1.0 or _prev_theme_id == _theme_id:
		return [[_theme_id, 1.0]]
	return [[_prev_theme_id, clampf((1.0 - _blend) * 2.0, 0.0, 1.0)], [_theme_id, clampf(_blend * 2.0, 0.0, 1.0)]]


# ---------------------------------------------------------------------------
# Desenho
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


## Uma vez por quadro: move as camadas fixas e redesenha só o necessário.
func _update_layers() -> void:
	var size := get_viewport_rect().size
	if size != _size:
		_size = size
		_static_dirty = true
	_layers["Clouds"].position.x = -fmod(_off_cloud, CLOUD_TILE)
	_layers["Mountains"].position.x = -fmod(_off_mountain, MOUNTAIN_TILE)
	_layers["City"].position.x = -fmod(_off_city, CITY_TILE)
	_layers["CityFx"].position.x = _layers["City"].position.x
	_layers["Trees"].position.x = -fmod(_off_tree, TREE_TILE)
	_layers["Dots"].position.x = -fmod(_off_front * 0.8, FRONT_TILE)
	_layers["Track"].position.x = -fmod(_off_near, TRACK_TILE)
	_layers["Poles"].position.x = -fmod(_off_near, POLE_SPACING)
	_layers["Tufts"].position.x = -fmod(_off_front, FRONT_TILE)
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


# --- Camadas fixas (desenhadas com deslocamento zero; o nó é que se move) ---

func _layer_sky_gradient() -> void:
	_draw_sky_gradient(_size)


func _layer_sun() -> void:
	_draw_sun(_size)


func _layer_clouds() -> void:
	var saved := _off_cloud
	_off_cloud = 0.0
	_draw_clouds()
	_ci.draw_set_transform(Vector2(CLOUD_TILE, 0))
	_draw_clouds()
	_ci.draw_set_transform(Vector2.ZERO)
	_off_cloud = saved


func _layer_mountains() -> void:
	var saved := _off_mountain
	_off_mountain = 0.0
	_draw_mountains(Vector2(_size.x + MOUNTAIN_TILE, _size.y))
	_off_mountain = saved


func _layer_city() -> void:
	var saved := _off_city
	_off_city = 0.0
	_draw_city(Vector2(_size.x + CITY_TILE, _size.y))
	_off_city = saved


func _layer_trees() -> void:
	var saved := _off_tree
	_off_tree = 0.0
	_draw_trees(Vector2(_size.x + TREE_TILE, _size.y))
	_off_tree = saved


func _layer_ground() -> void:
	_draw_ground(_size)


func _layer_dots() -> void:
	var saved := _off_front
	_off_front = 0.0
	_draw_dots(Vector2(FRONT_TILE, _size.y))
	_ci.draw_set_transform(Vector2(FRONT_TILE, 0))
	_draw_dots(Vector2(_size.x, _size.y))
	_ci.draw_set_transform(Vector2.ZERO)
	_off_front = saved


func _layer_track() -> void:
	_draw_track_tiles(_size)


func _layer_rail() -> void:
	_draw_rail(_size)


func _layer_poles() -> void:
	var saved := _off_near
	_off_near = 0.0
	_draw_poles(Vector2(_size.x + POLE_SPACING * 2.0, _size.y))
	_off_near = saved


func _layer_tufts() -> void:
	var saved := _off_front
	_off_front = 0.0
	_draw_front_tufts(Vector2(FRONT_TILE, _size.y))
	_ci.draw_set_transform(Vector2(FRONT_TILE, 0))
	_draw_front_tufts(Vector2(_size.x, _size.y))
	_ci.draw_set_transform(Vector2.ZERO)
	_off_front = saved


func _layer_tender_body() -> void:
	_draw_tender_body(Vector2(LOCO_X - 175.0, GROUND_Y))


func _layer_loco_body() -> void:
	_draw_loco_body(Vector2(LOCO_X, GROUND_Y))


# --- Camadas vivas (redesenhadas a cada quadro) ---

func _layer_sky_fx() -> void:
	_draw_sky_fx(_size)


func _layer_city_fx() -> void:
	_draw_city_fx(_size)


func _layer_ground_fx() -> void:
	_draw_haze(_size)


func _layer_tender_wheels() -> void:
	var o := Vector2(LOCO_X - 175.0, GROUND_Y)
	for wx in [35.0, 125.0]:
		_draw_wheel_spokes(o + Vector2(wx, -20), 20.0, _wheel_angle * DRIVER_R / 20.0)


func _layer_tender_rims() -> void:
	var o := Vector2(LOCO_X - 175.0, GROUND_Y)
	for wx in [35.0, 125.0]:
		_draw_wheel_rim(o + Vector2(wx, -20), 20.0)


func _layer_loco_rims() -> void:
	for w in _loco_wheels():
		_draw_wheel_rim(w[0], w[1])


## Centro, raio e fator de giro de cada roda da locomotiva.
func _loco_wheels() -> Array:
	var o := Vector2(LOCO_X, GROUND_Y)
	return [[o + Vector2(80, -DRIVER_R), DRIVER_R, 1.0], [o + Vector2(150, -DRIVER_R), DRIVER_R, 1.0],
		[o + Vector2(220, -DRIVER_R), DRIVER_R, 1.0], [o + Vector2(286, -16), 16.0, DRIVER_R / 16.0],
		[o + Vector2(30, -18), 18.0, DRIVER_R / 18.0]]


func _layer_beam() -> void:
	var lamp := Vector2(LOCO_X, GROUND_Y + _bob()) + Vector2(300, -126)
	var glow := float(_cur["beam"]) * (1.0 + 0.25 * sin(_time * 7.0))
	if glow > 0.005:
		_ci.draw_colored_polygon(PackedVector2Array([lamp, lamp + Vector2(280, -40), lamp + Vector2(280, 70)]), Color(WARM_LIGHT, glow))


func _layer_loco_fx() -> void:
	_draw_loco_fx()


func _layer_front() -> void:
	_draw_smoke(false)
	_draw_sparks()
	_draw_maintenance_icon()
	_draw_weather(_size)


func _layer_overlay() -> void:
	_draw_speed_lines(_size)
	_draw_celebration()


func _draw_sky_gradient(size: Vector2) -> void:
	var top: Color = _cur["sky_top"]
	var mid: Color = _cur["sky_mid"]
	var hor: Color = _cur["sky_horizon"]
	var mid_y := GROUND_Y * 0.55
	_ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, mid_y), Vector2(0, mid_y)]),
		PackedColorArray([top, top, mid, mid]))
	_ci.draw_polygon(PackedVector2Array([Vector2(0, mid_y), Vector2(size.x, mid_y), Vector2(size.x, GROUND_Y), Vector2(0, GROUND_Y)]),
		PackedColorArray([mid, mid, hor, hor]))


func _sun_pos(size: Vector2) -> Vector2:
	return Vector2(size.x * float(_cur["sun_x"]), GROUND_Y - float(_cur["sun_y"]))


## Estrelas piscando (noite) e raios girando (dia): vivos, mas baratos.
func _draw_sky_fx(size: Vector2) -> void:
	var stars: float = _cur["stars"]
	if stars > 0.02:
		for st in _stars:
			var tw := 0.55 + 0.45 * sin(_time * 1.7 + st.z)
			_ci.draw_circle(Vector2(st.x, st.y), 1.0 + 0.8 * tw, Color(1, 1, 1, stars * tw))
	var rays: float = _cur["rays"]
	if rays > 0.02:
		var sun: Color = _cur["sun"]
		var r: float = _cur["sun_r"]
		var sun_pos := _sun_pos(size)
		for i in 12:
			var ang := i * TAU / 12.0 + _time * 0.08
			var dir := Vector2(cos(ang), sin(ang))
			var length := r * (2.2 + 0.5 * sin(_time * 1.3 + i * 1.9))
			_ci.draw_line(sun_pos + dir * (r + 8.0), sun_pos + dir * length, Color(sun, 0.30 * rays), 4.0)


## Sol (dia) ou lua (noite): a posição acompanha a hora do dia de cada tema.
func _draw_sun(size: Vector2) -> void:
	var sun: Color = _cur["sun"]
	var r: float = _cur["sun_r"]
	var moon: float = _cur["moon"]
	var sun_pos := _sun_pos(size)
	for i in 5:
		_ci.draw_circle(sun_pos, r + 4.0 + i * 22.0, Color(sun, (0.10 - i * 0.018) * (1.0 - 0.4 * moon)))
	_ci.draw_circle(sun_pos, r, Color(sun, 0.95))
	if moon > 0.02:  # crateras e sombra da lua
		_ci.draw_circle(sun_pos + Vector2(-r * 0.30, -r * 0.20), r * 0.20, Color(0.70, 0.74, 0.84, 0.55 * moon))
		_ci.draw_circle(sun_pos + Vector2(r * 0.25, r * 0.30), r * 0.14, Color(0.70, 0.74, 0.84, 0.55 * moon))
		_ci.draw_circle(sun_pos + Vector2(r * 0.35, -r * 0.35), r * 0.10, Color(0.70, 0.74, 0.84, 0.45 * moon))


func _draw_clouds() -> void:
	var cloud: Color = _cur["cloud"]
	for c in _clouds:
		var cx := fmod(float(c["x"]) - _off_cloud, CLOUD_TILE)
		if cx < -200.0:
			cx += CLOUD_TILE
		var sc: float = c["scale"]
		var base := Vector2(cx, c["y"])
		for part in [[0, 0, 34], [38, 6, 28], [-36, 8, 26], [14, -16, 26], [70, 12, 20], [-66, 14, 18]]:
			_ci.draw_circle(base + Vector2(part[0], part[1]) * sc, part[2] * sc, cloud)


func _draw_mountains(size: Vector2) -> void:
	var col: Color = _cur["mountain"]
	var caps: float = _cur["caps"]
	for k in 3:
		var base: float = -_off_mountain + k * MOUNTAIN_TILE
		if base > size.x:
			continue
		var poly := PackedVector2Array()
		for p in _mountain_points:
			poly.append(Vector2(p.x + base, p.y))
		poly.append(Vector2(base + MOUNTAIN_TILE, GROUND_Y))
		poly.append(Vector2(base, GROUND_Y))
		_ci.draw_colored_polygon(poly, col)
		if caps > 0.02:  # neve nos picos
			var snow_line := GROUND_Y - 150.0
			for i in range(_mountain_points.size() - 1):
				var a := _mountain_points[i] + Vector2(base, 0)
				var b := _mountain_points[i + 1] + Vector2(base, 0)
				if a.y < snow_line or b.y < snow_line:
					# fundo da neve nunca acima do próprio ponto (evita polígono invertido/degenerado)
					var a_bot := Vector2(a.x, maxf(a.y, minf(snow_line, a.y + 22.0)))
					var b_bot := Vector2(b.x, maxf(b.y, minf(snow_line, b.y + 22.0)))
					var cap := PackedVector2Array([a, b])
					if b_bot.y - b.y > 0.5:
						cap.append(b_bot)
					if a_bot.y - a.y > 0.5:
						cap.append(a_bot)
					if cap.size() >= 3:
						_ci.draw_colored_polygon(cap, Color(0.90, 0.94, 1.0, 0.85 * caps))


func _draw_city(size: Vector2) -> void:
	var col: Color = _cur["city"]
	var lit := Color(WARM_LIGHT, float(_cur["window"]))
	var snow: float = _cur["snow"]
	for k in 3:
		var base: float = -_off_city + k * CITY_TILE
		for b in _buildings:
			var x: float = base + b["x"]
			if x > size.x or x + b["w"] < 0:
				continue
			var top: float = GROUND_Y - 30.0 - b["h"]
			_ci.draw_rect(Rect2(x, top, b["w"], b["h"] + 30.0), col)
			if snow > 0.02:  # neve no telhado
				_ci.draw_rect(Rect2(x - 2, top - 3, b["w"] + 4, 5), Color(0.88, 0.92, 1.0, 0.9 * snow))
			# janelas iluminadas
			for wi in b["windows"]:
				_ci.draw_rect(Rect2(x + 10 + wi * 22, top + 16, 9, 12), lit)
			if b["chimney"]:
				var cx: float = x + b["w"] * b["cx"]
				_ci.draw_rect(Rect2(cx - 6, top - b["ch"], 12, b["ch"]), col)


## Fumacinha das chaminés e engrenagens girando da cidade (camada viva).
## Desenhada no espaço da camada da cidade (que se move); só o trecho visível,
## com folga porque ela redesenha a cada poucos quadros.
func _draw_city_fx(size: Vector2) -> void:
	var col: Color = _cur["city"]
	var view_left := fmod(_off_city, CITY_TILE) - 150.0
	var view_right := view_left + size.x + 300.0
	for k in 3:
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
					_ci.draw_circle(Vector2(cx - t * 30.0, top - b["ch"] - 8 - t * 40.0), 5 + t * 10, Color(0.75, 0.72, 0.7, 0.25 * (1.0 - t)))
			if b["gear"]:
				var gc := Vector2(x + b["w"] * 0.5, top - 4)
				_ci.draw_colored_polygon(_gear(gc, 26, 19, 10, _time * 0.4), col)
				_ci.draw_circle(gc, 7, (_cur["sky_mid"] as Color).lerp(col, 0.4))


func _draw_trees(size: Vector2) -> void:
	for pair in _blend_weights():
		var theme := SeasonThemes.get_theme(pair[0])
		var alpha: float = pair[1]
		if alpha <= 0.01:
			continue
		var colors: Array = theme["tree_colors"]
		for k in 3:
			var base: float = -_off_tree + k * TREE_TILE
			for t in _trees:
				if t["rand"] > theme["tree_density"]:
					continue
				var x: float = base + t["x"]
				if x < -80.0 or x > size.x + 80.0:
					continue
				var sc: float = t["scale"]
				var foot := Vector2(x, GROUND_Y - 8.0 + t["y"])
				var col: Color = colors[int(t["color"]) % colors.size()]
				if theme["tree_shape"] == "pine":
					_draw_pine(foot, sc, col, alpha, float(_cur["snow"]))
				else:
					_draw_round_tree(foot, sc, col, alpha, theme["blossom"])


func _draw_round_tree(foot: Vector2, sc: float, col: Color, alpha: float, blossom: bool) -> void:
	var trunk := Color(0.22, 0.15, 0.10, alpha)
	_ci.draw_rect(Rect2(foot.x - 4 * sc, foot.y - 46 * sc, 8 * sc, 46 * sc), trunk)
	var c := Color(col, alpha)
	var top := foot + Vector2(0, -66 * sc)
	_ci.draw_circle(top, 30 * sc, c)
	_ci.draw_circle(top + Vector2(-22, 12) * sc, 22 * sc, c)
	_ci.draw_circle(top + Vector2(22, 12) * sc, 22 * sc, c)
	_ci.draw_circle(top + Vector2(-8, -8) * sc, 20 * sc, Color(col.lightened(0.15), alpha))
	if blossom:
		for i in 7:
			var a := i * 0.9 + foot.x * 0.05
			_ci.draw_circle(top + Vector2(cos(a), sin(a) * 0.8) * (10.0 + (i % 3) * 9.0) * sc, 3.0 * sc, Color(1, 1, 1, 0.8 * alpha))


func _draw_pine(foot: Vector2, sc: float, col: Color, alpha: float, snow: float) -> void:
	_ci.draw_rect(Rect2(foot.x - 3 * sc, foot.y - 16 * sc, 6 * sc, 16 * sc), Color(0.16, 0.11, 0.09, alpha))
	for i in 3:
		var base_y := foot.y - (12.0 + i * 28.0) * sc
		var half := (30.0 - i * 7.0) * sc
		var tip := Vector2(foot.x, base_y - 42.0 * sc)
		_ci.draw_colored_polygon(PackedVector2Array([Vector2(foot.x - half, base_y), Vector2(foot.x + half, base_y), tip]), Color(col, alpha))
		if snow > 0.02:  # neve nos galhos
			_ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-half * 0.45, 19.0 * sc), tip + Vector2(0, 13.0 * sc), tip + Vector2(half * 0.45, 19.0 * sc)]),
				Color(0.92, 0.96, 1.0, 0.9 * alpha * snow))


func _draw_ground(size: Vector2) -> void:
	# campo (grama, trigo, folhas ou neve, conforme o tema)
	var g_top: Color = _cur["ground_top"]
	var g_bot: Color = _cur["ground_bottom"]
	_ci.draw_polygon(PackedVector2Array([Vector2(0, GROUND_Y - 6), Vector2(size.x, GROUND_Y - 6), Vector2(size.x, size.y), Vector2(0, size.y)]),
		PackedColorArray([g_top, g_top, g_bot, g_bot]))
	# lastro de brita (faixa)
	_ci.draw_rect(Rect2(0, GROUND_Y + 4, size.x, 26), _cur["ballast"])


## Calor do verão: faixas tremulando perto do horizonte (camada viva).
func _draw_haze(size: Vector2) -> void:
	var haze: float = _cur["haze"]
	if haze > 0.02:
		for i in 5:
			var hy := GROUND_Y - 12.0 - i * 9.0 + sin(_time * 2.2 + i * 1.7) * 2.5
			_ci.draw_line(Vector2(0, hy), Vector2(size.x, hy), Color(1.0, 0.97, 0.85, 0.07 * haze), 5.0)


## Flores, folhas caídas ou brilho no campo.
func _draw_dots(size: Vector2) -> void:
	for pair in _blend_weights():
		var dot_colors: Array = SeasonThemes.get_theme(pair[0])["dots"]
		if dot_colors.is_empty() or pair[1] <= 0.01:
			continue
		for d in _dots:
			var dx := fmod(d.x - _off_front * 0.8, FRONT_TILE)
			if dx < -10.0:
				dx += FRONT_TILE
			if dx > size.x:
				continue
			var dy := GROUND_Y + 40.0 + d.y * (_size.y - GROUND_Y - 50.0)
			var col: Color = dot_colors[int(d.z) % dot_colors.size()]
			_ci.draw_circle(Vector2(dx, dy), 2.5 + d.y * 2.5, Color(col, pair[1]))


## Pedras da brita e dormentes, em blocos de TRACK_TILE que se repetem.
func _draw_track_tiles(size: Vector2) -> void:
	var stone: Color = (_cur["ballast"] as Color).lightened(0.18)
	var tiles := int(ceil(size.x / TRACK_TILE)) + 1
	for k in tiles:
		var base := k * TRACK_TILE
		for i in 60:
			_ci.draw_rect(Rect2(base + fmod(i * 47.0, TRACK_TILE), GROUND_Y + 8 + (i % 4) * 5, 4, 3), stone)
	var x := 0.0
	while x < tiles * TRACK_TILE:
		_ci.draw_rect(Rect2(x, GROUND_Y + 1, 30, 9), Color(0.27, 0.18, 0.11))
		x += 44.0


## Trilho com brilho de metal (fixo, por cima dos dormentes).
func _draw_rail(size: Vector2) -> void:
	_ci.draw_rect(Rect2(0, GROUND_Y - 3, size.x, 5), IRON_LIGHT)
	_ci.draw_line(Vector2(0, GROUND_Y - 3), Vector2(size.x, GROUND_Y - 3), Color(0.75, 0.72, 0.68), 1.5)


func _draw_poles(size: Vector2) -> void:
	var x := -fmod(_off_near, POLE_SPACING)
	var tops: Array[Vector2] = []
	while x < size.x + POLE_SPACING:
		_ci.draw_rect(Rect2(x, GROUND_Y - 150, 7, 150), Color(0.20, 0.14, 0.10))
		_ci.draw_rect(Rect2(x - 16, GROUND_Y - 142, 39, 5), Color(0.20, 0.14, 0.10))
		_ci.draw_circle(Vector2(x - 12, GROUND_Y - 145), 3, BRASS_DARK)
		_ci.draw_circle(Vector2(x + 19, GROUND_Y - 145), 3, BRASS_DARK)
		tops.append(Vector2(x, GROUND_Y - 145))
		x += POLE_SPACING
	# fios caídos entre os postes
	for i in range(tops.size() - 1):
		for dx in [-12.0, 19.0]:
			var a: Vector2 = tops[i] + Vector2(dx, 0)
			var b: Vector2 = tops[i + 1] + Vector2(dx, 0)
			var pts := PackedVector2Array()
			for s in 9:
				var t := s / 8.0
				pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * 18.0))
			_ci.draw_polyline(pts, Color(0.12, 0.10, 0.10, 0.8), 1.2)


func _draw_station_signs() -> void:
	for station_sign in _station_signs:
		var x: float = station_sign["x"]
		# plataforma
		_ci.draw_rect(Rect2(x - 40, GROUND_Y - 24, 380, 22), Color(0.45, 0.38, 0.30))
		_ci.draw_rect(Rect2(x - 40, GROUND_Y - 26, 380, 4), BRASS_DARK)
		# postes de luz
		for lx in [x, x + 300]:
			_ci.draw_rect(Rect2(lx, GROUND_Y - 120, 5, 96), IRON)
			_ci.draw_circle(Vector2(lx + 2, GROUND_Y - 124), 9, Color(WARM_LIGHT, 0.9))
			_ci.draw_circle(Vector2(lx + 2, GROUND_Y - 124), 22, Color(WARM_LIGHT, 0.18))
		# placa com o nome
		var station_name: String = station_sign["name"]
		var w := maxf(150.0, _font.get_string_size(station_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 30.0)
		# postes altos: a placa fica acima da locomotiva para o nome ficar legível
		_ci.draw_rect(Rect2(x + 150 - w / 2, GROUND_Y - 220, 6, 196), IRON)
		_ci.draw_rect(Rect2(x + 150 + w / 2 - 6, GROUND_Y - 220, 6, 196), IRON)
		_ci.draw_rect(Rect2(x + 150 - w / 2 - 4, GROUND_Y - 262, w + 8, 46), BRASS_DARK)
		_ci.draw_rect(Rect2(x + 150 - w / 2, GROUND_Y - 258, w, 38), Color(0.10, 0.20, 0.20))
		_ci.draw_string(_font, Vector2(x + 150 - w / 2, GROUND_Y - 231), station_name, HORIZONTAL_ALIGNMENT_CENTER, w, 22, BRASS)


## behind = true desenha a fumaça antiga (atrás do trem); false, a nova e o vapor.
func _draw_smoke(behind: bool) -> void:
	for p in _smoke:
		var steam: bool = p["steam"]
		var is_old: bool = (not steam) and p["life"] <= 0.6
		if is_old != behind:
			continue
		var a: float = clampf(p["life"], 0.0, 1.0)
		var c: Color
		if steam:
			c = Color(1, 1, 1, a * 0.55)
		else:
			var g: float = lerpf(0.30, 0.82, 1.0 - a) + p["shade"] * 0.2
			c = Color(g, g, g * 0.98, a * 0.75)
		var r: float = p["r"]
		_ci.draw_circle(p["pos"], r, c)
		if not steam:
			_ci.draw_circle(p["pos"] + Vector2(r * 0.6, r * 0.2), r * 0.7, c)
			_ci.draw_circle(p["pos"] + Vector2(-r * 0.5, r * 0.35), r * 0.6, c)


func _draw_sparks() -> void:
	for s in _sparks:
		var a: float = clampf(s["life"] * 1.6, 0.0, 1.0)
		_ci.draw_circle(s["pos"], 2.2, Color(1.0, 0.7, 0.25, a))
		_ci.draw_circle(s["pos"], 5.0, Color(1.0, 0.5, 0.1, a * 0.25))


func _draw_front_tufts(size: Vector2) -> void:
	var c: Color = _cur["tuft"]
	var snow: float = _cur["snow"]
	for t in _tufts:
		var x := fmod(t.x - _off_front, FRONT_TILE)
		if x < -40:
			x += FRONT_TILE
		if x > size.x:
			continue
		var y := _size.y - 20.0 - t.y * 60.0
		for k in 5:
			var ang := -PI / 2 + (k - 2) * 0.32
			var tip := Vector2(x, y) + Vector2(cos(ang), sin(ang)) * (22 + k % 2 * 10)
			_ci.draw_line(Vector2(x, y), tip, c, 3.0)
			if snow > 0.02:
				_ci.draw_circle(tip, 2.5, Color(0.95, 0.97, 1.0, snow))


## Clima em primeiro plano: pétalas (primavera), folhas (outono) ou neve (inverno).
func _draw_weather(size: Vector2) -> void:
	for pair in _blend_weights():
		var theme := SeasonThemes.get_theme(pair[0])
		var kind: String = theme["weather"]
		var alpha: float = pair[1]
		if kind == "none" or alpha <= 0.01:
			continue
		var colors: Array = theme["weather_colors"]
		var fall := 34.0 if kind == "petals" else (55.0 if kind == "leaves" else 48.0)
		var count := WEATHER_COUNT if kind == "snow" else WEATHER_COUNT / 2
		for i in count:
			var w: Dictionary = _weather[i]
			var sp: float = w["speed"]
			var ph: float = w["phase"]
			var y := fmod(float(w["y"]) + _time * fall * sp, size.y + 20.0) - 10.0
			var sway := sin(_time * (1.2 if kind == "snow" else 2.0) * sp + ph) * (10.0 if kind == "snow" else 22.0)
			var x := fmod(float(w["x"]) - _off_weather * sp + sway, 1400.0)
			if x < -10.0:
				x += 1400.0
			if x > size.x:
				continue
			var col := Color(colors[int(w["color"]) % colors.size()], alpha * 0.9)
			var sz: float = w["size"]
			var pos := Vector2(x, y)
			match kind:
				"snow":
					_ci.draw_circle(pos, 2.2 * sz, col)
				"petals":
					var a := _time * 2.5 * sp + ph
					var d := Vector2(cos(a), sin(a)) * 4.0 * sz
					_ci.draw_line(pos - d, pos + d, col, 3.0)
				"leaves":
					var a := _time * 3.0 * sp + ph
					var u := Vector2(cos(a), sin(a)) * 6.0 * sz
					var v := u.orthogonal() * 0.45
					_ci.draw_colored_polygon(PackedVector2Array([pos - u, pos + v, pos + u, pos - v]), col)


func _draw_speed_lines(size: Vector2) -> void:
	if _speed_ratio < 0.45:
		return
	var a := (_speed_ratio - 0.45) / 0.55 * 0.35
	for i in 10:
		var y := 70.0 + i * 37.0
		var length := 80.0 + (i * 53) % 120
		var x := fmod(size.x - fmod(_time * 1400.0 + i * 263.0, size.x + length), size.x + length)
		_ci.draw_line(Vector2(x, y), Vector2(x + length, y), Color(1, 1, 1, a), 1.5)


func _draw_celebration() -> void:
	for c in _celebration:
		var a: float = clampf(c["life"], 0.0, 1.0)
		if c["gear"]:
			_ci.draw_colored_polygon(_gear(c["pos"], c["size"] * 1.3, c["size"], 8, c["rot"]), Color(BRASS, a))
		else:
			_ci.draw_circle(c["pos"], c["size"] * 0.45, Color(1.0, 0.85, 0.35, a))


# ---------------------------------------------------------------------------
# Locomotiva
# ---------------------------------------------------------------------------

## Carroceria da locomotiva (fixa). O nó da camada aplica o balanço.
func _draw_loco_body(o: Vector2) -> void:
	var b := o
	var lamp := b + Vector2(300, -126)

	# Chassi
	_ci.draw_rect(Rect2(b + Vector2(10, -46), Vector2(300, 14)), IRON)
	# Limpa-trilhos
	_ci.draw_colored_polygon(PackedVector2Array([b + Vector2(300, -40), b + Vector2(338, -4), b + Vector2(300, -4)]), IRON_LIGHT)

	# Caldeira
	_ci.draw_rect(Rect2(b + Vector2(70, -118), Vector2(205, 66)), BODY)
	_ci.draw_rect(Rect2(b + Vector2(70, -118), Vector2(205, 12)), BODY.lightened(0.15))   # reflexo
	for bx in [110.0, 165.0, 220.0]:
		_ci.draw_rect(Rect2(b + Vector2(bx, -119), Vector2(7, 68)), BRASS)
	for rx in range(80, 270, 14):
		_ci.draw_circle(b + Vector2(rx, -58), 1.6, BRASS_DARK)
	# Caixa de fumaça (frente)
	_ci.draw_rect(Rect2(b + Vector2(272, -120), Vector2(28, 70)), IRON)
	_ci.draw_circle(b + Vector2(300, -85), 34, IRON)
	_ci.draw_circle(b + Vector2(300, -85), 26, IRON_LIGHT)
	for i in 8:
		var ang := i * TAU / 8.0
		_ci.draw_circle(b + Vector2(300, -85) + Vector2(cos(ang), sin(ang)) * 21, 2, BRASS)
	_ci.draw_circle(b + Vector2(300, -85), 6, BRASS)
	# Farol
	_ci.draw_rect(Rect2(lamp + Vector2(-14, -12), Vector2(20, 22)), BRASS)
	_ci.draw_circle(lamp, 8, WARM_LIGHT)
	_ci.draw_circle(lamp, 14, Color(WARM_LIGHT, 0.35))

	# Chaminé
	_ci.draw_colored_polygon(PackedVector2Array([
		b + Vector2(236, -118), b + Vector2(254, -118), b + Vector2(258, -160),
		b + Vector2(266, -176), b + Vector2(224, -176), b + Vector2(232, -160)]), COPPER)
	_ci.draw_rect(Rect2(b + Vector2(220, -181), Vector2(50, 7)), BRASS)
	# Domos e apito
	_ci.draw_circle(b + Vector2(185, -118), 17, BRASS)
	_ci.draw_rect(Rect2(b + Vector2(168, -119), Vector2(34, 4)), BRASS_DARK)
	_ci.draw_circle(b + Vector2(130, -118), 12, BRASS)
	_ci.draw_rect(Rect2(b + Vector2(182, -148), Vector2(6, 16)), BRASS)
	_ci.draw_circle(b + Vector2(185, -150), 4, BRASS)

	# Cilindro e pistão
	_ci.draw_rect(Rect2(b + Vector2(232, -56), Vector2(56, 30)), BRASS_DARK)
	_ci.draw_rect(Rect2(b + Vector2(236, -52), Vector2(48, 22)), BRASS)
	for cx in [240.0, 280.0]:
		_ci.draw_rect(Rect2(b + Vector2(cx, -56), Vector2(4, 30)), BRASS_DARK)

	# Cabine
	_ci.draw_rect(Rect2(b + Vector2(-6, -168), Vector2(84, 6)), IRON)            # teto
	_ci.draw_rect(Rect2(b + Vector2(0, -162), Vector2(76, 120)), BODY_DARK)
	_ci.draw_rect(Rect2(b + Vector2(0, -162), Vector2(76, 4)), BRASS)
	var snow: float = _cur["snow"]
	if snow > 0.02:  # neve acumulada no teto da cabine e no alto da caldeira
		var white := Color(0.94, 0.97, 1.0, snow)
		_ci.draw_rect(Rect2(b + Vector2(-8, -174), Vector2(88, 7)), white)
		_ci.draw_circle(b + Vector2(-8, -170.5), 3.5, white)
		_ci.draw_circle(b + Vector2(80, -170.5), 3.5, white)
		_ci.draw_rect(Rect2(b + Vector2(72, -122), Vector2(36, 5)), white)
		_ci.draw_rect(Rect2(b + Vector2(140, -122), Vector2(24, 4)), white)
	_ci.draw_rect(Rect2(b + Vector2(14, -146), Vector2(46, 38)), Color(0.12, 0.08, 0.05))  # fornalha
	_ci.draw_rect(Rect2(b + Vector2(14, -146), Vector2(46, 3)), BRASS)
	# Mostrador do manômetro (o ponteiro é vivo)
	var gauge := b + Vector2(38, -78)
	_ci.draw_circle(gauge, 14, BRASS)
	_ci.draw_circle(gauge, 11, Color(0.93, 0.89, 0.78))


## Partes vivas da locomotiva: fornalha, ponteiro, engrenagem, rodas e bielas.
func _draw_loco_fx() -> void:
	var o := Vector2(LOCO_X, GROUND_Y)           # origem: base da cabine, no trilho
	var b := o + Vector2(0, _bob())              # partes presas ao corpo balançam junto
	var flicker := 0.85 + 0.15 * sin(_time * 11.0) * sin(_time * 3.7)
	_ci.draw_rect(Rect2(b + Vector2(16, -143), Vector2(42, 33)), Color(WARM_LIGHT, 0.75 * flicker))  # luz da fornalha
	if _stoke > 0.02:  # caldeira atiçada: fornalha mais viva e brilho em volta
		_ci.draw_rect(Rect2(b + Vector2(16, -143), Vector2(42, 33)), Color(1.0, 0.45, 0.1, 0.6 * _stoke * flicker))
		_ci.draw_circle(b + Vector2(37, -127), 30.0 + 14.0 * _stoke, Color(1.0, 0.5, 0.15, 0.22 * _stoke))
	# Ponteiro do manômetro (sobe com a velocidade)
	var gauge := b + Vector2(38, -78)
	var needle := lerpf(PI * 0.8, PI * 2.2, _speed_ratio) + sin(_time * 9.0) * 0.03
	_ci.draw_line(gauge, gauge + Vector2(cos(needle), sin(needle)) * 9, Color(0.6, 0.1, 0.1), 2.0)
	# Engrenagem decorativa girando com as rodas
	var gear_c := b + Vector2(62, -58)
	_ci.draw_colored_polygon(_gear(gear_c, 13, 9, 9, -_wheel_angle * 1.6), COPPER)
	_ci.draw_circle(gear_c, 4, BRASS_DARK)

	# Rodas (sem balanço: ficam no trilho)
	var drivers: Array[Vector2] = [o + Vector2(80, -DRIVER_R), o + Vector2(150, -DRIVER_R), o + Vector2(220, -DRIVER_R)]
	for w in _loco_wheels():
		_draw_wheel_spokes(w[0], w[1], _wheel_angle * w[2])

	# Bielas: barra de acoplamento entre as manivelas e biela até o pistão
	var crank := Vector2(cos(_wheel_angle), sin(_wheel_angle)) * CRANK_R
	var p1: Vector2 = drivers[0] + crank
	var p3: Vector2 = drivers[2] + crank
	_ci.draw_line(p1, p3, BRASS_DARK, 8.0)
	_ci.draw_line(p1, p3, BRASS, 5.0)
	for c in drivers:
		_ci.draw_circle(c + crank, 4.5, IRON_LIGHT)
	var crosshead := b + Vector2(236 + crank.x * 0.9 - 10, -41)
	_ci.draw_line(drivers[2] + crank, crosshead, IRON_LIGHT, 6.0)
	_ci.draw_line(crosshead, b + Vector2(262, -41), Color(0.75, 0.72, 0.68), 4.0)
	_ci.draw_rect(Rect2(crosshead - Vector2(7, 6), Vector2(14, 12)), BRASS_DARK)


## Corpo do tender (fixo). O nó da camada aplica o balanço; as rodas são vivas.
func _draw_tender_body(o: Vector2) -> void:
	var b := o
	_ci.draw_rect(Rect2(b + Vector2(0, -112), Vector2(160, 70)), BODY_DARK)
	_ci.draw_rect(Rect2(b + Vector2(0, -112), Vector2(160, 8)), BRASS)
	_ci.draw_rect(Rect2(b + Vector2(0, -60), Vector2(160, 5)), BRASS_DARK)
	for rx in range(10, 160, 16):
		_ci.draw_circle(b + Vector2(rx, -96), 1.6, BRASS_DARK)
	# monte de carvão
	var coal := PackedVector2Array([b + Vector2(8, -112)])
	for i in 9:
		coal.append(b + Vector2(8 + i * 18, -122 - (8 if i % 2 == 0 else 3) - (6 if i in [3, 4, 5] else 0)))
	coal.append(b + Vector2(152, -112))
	_ci.draw_colored_polygon(coal, Color(0.07, 0.07, 0.08))
	for i in 6:
		_ci.draw_circle(b + Vector2(20 + i * 22, -122 - (i % 3) * 3), 2, Color(0.35, 0.35, 0.4))
	var snow: float = _cur["snow"]
	if snow > 0.02:  # neve sobre o carvão
		for i in 5:
			_ci.draw_circle(b + Vector2(24 + i * 28, -128 - (i % 2) * 4), 6.0, Color(0.94, 0.97, 1.0, 0.85 * snow))
	_ci.draw_rect(Rect2(b + Vector2(-6, -48), Vector2(172, 10)), IRON)
	# engate
	_ci.draw_rect(Rect2(b + Vector2(160, -40), Vector2(20, 6)), IRON_LIGHT)


## Aro da roda (fixo).
func _draw_wheel_rim(c: Vector2, r: float) -> void:
	_ci.draw_circle(c, r, IRON)
	_ci.draw_circle(c, r - 3.0, IRON_LIGHT)
	_ci.draw_arc(c, r - 1.5, 0, TAU, 32, BRASS_DARK, 1.5)


## Raios e cubo da roda (giram: camada viva).
func _draw_wheel_spokes(c: Vector2, r: float, angle: float) -> void:
	var spokes := 8 if r > 20 else 6
	for i in spokes:
		var a := angle + i * TAU / spokes
		_ci.draw_line(c, c + Vector2(cos(a), sin(a)) * (r - 4.0), IRON, 2.5)
	_ci.draw_circle(c, r * 0.28, BRASS)
	_ci.draw_circle(c, r * 0.12, IRON)


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
	var c := Vector2(LOCO_X + 38.0, GROUND_Y - 215.0)
	if _train_state == TrainMovement.State.BRAKING:
		# Alerta piscando enquanto o trem freia por causa da falha.
		if fmod(_time, 0.5) < 0.32:
			var tri := PackedVector2Array([c + Vector2(0, -30), c + Vector2(28, 20), c + Vector2(-28, 20)])
			_ci.draw_colored_polygon(tri, Color(0.95, 0.25, 0.15))
			_ci.draw_polyline(tri + PackedVector2Array([tri[0]]), BRASS, 3.0)
			_ci.draw_string(_font, c + Vector2(-20, 15), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 30, Color.WHITE)
		return
	var pulse := 0.6 + 0.4 * sin(_time * 6.0)
	_ci.draw_circle(c, 34.0, Color(1.0, 0.6, 0.2, 0.18 * pulse))
	_ci.draw_colored_polygon(_gear(c, 24, 17, 10, _time * 2.5), BRASS)
	_ci.draw_circle(c, 8.0, BRASS_DARK)
	_ci.draw_colored_polygon(_gear(c + Vector2(26, 14), 13, 9, 8, -_time * 4.0), COPPER)
	_ci.draw_circle(c + Vector2(26, 14), 4.0, BRASS_DARK)
