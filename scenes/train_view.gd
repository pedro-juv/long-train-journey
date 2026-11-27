class_name TrainView
extends Node2D
## TrainView — cenário e locomotiva, desenhados por código ("desenho sombrio").
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
const ISLAND_TILE := 2300.0
## Topo do tubo de vidro do fundo do mar.
const TUBE_TOP := GROUND_Y - 430.0
## Segundos da fusão entre dois temas (formato das árvores, clima).
const THEME_BLEND_SECONDS := 5.0

## Rolagem visual = scroll_per_sqrt_speed * raiz(velocidade) px/s do mundo — estético.
@export var scroll_per_sqrt_speed: float = 115.0
## Velocidade (m/s) a partir da qual os efeitos estão no máximo — estético.
@export var full_effect_speed: float = 40.0

# Paleta (ferrovia antiga, cartoon)
# Paleta "desenho sombrio": ferro azulado, madeira gasta e latão sem brilho.
# A cor vem das luzes (fornalha, farol, janelas, lampiões).
const INK := Color(0.04, 0.05, 0.07)
const INK_W := 2.6
const WINE := Color(0.20, 0.25, 0.30)        # ferro azulado (corpo do trem)
const WINE_DARK := Color(0.11, 0.14, 0.18)
const WINE_LIGHT := Color(0.33, 0.40, 0.45)
const WOOD := Color(0.30, 0.24, 0.20)
const WOOD_DARK := Color(0.19, 0.15, 0.13)
const CHARCOAL := Color(0.09, 0.10, 0.12)
const CHARCOAL_LIGHT := Color(0.20, 0.22, 0.25)
const METAL := Color(0.52, 0.56, 0.60)
const BRASS := Color(0.74, 0.60, 0.36)       # latão gasto
const BRASS_DARK := Color(0.46, 0.37, 0.22)
const COPPER := Color(0.55, 0.40, 0.30)
const BRONZE := Color(0.45, 0.38, 0.30)
const CREAM := Color(0.86, 0.84, 0.76)
const WARM_LIGHT := Color(1.0, 0.78, 0.42)
const STONE := Color(0.30, 0.31, 0.34)
## Luzinhas que sobem na chegada à estação.
const MOTES := [Color(1.0, 0.78, 0.42), Color(1.0, 0.90, 0.70), Color(0.70, 0.95, 0.92)]
## A escuridão que vem consumindo tudo atrás do trem.
const DARK := Color(0.015, 0.015, 0.03)
const DARK_RIM := Color(0.10, 0.08, 0.16)

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
var _far_points: PackedVector2Array
var _hill_points: PackedVector2Array
var _buildings: Array[Dictionary] = []
var _tufts: Array[Vector2] = []
## Carros, ônibus e caminhões abandonados (perto do trilho, mesma camada de
## profundidade das árvores).
var _wrecks: Array[Dictionary] = []
## Ilhas flutuantes (Céu de Latão), rachaduras de lava (Mar de Cinzas) e
## nuvens sob a ponte (posições fixas; o tema decide se aparecem).
var _islands: Array[Dictionary] = []
var _cracks: Array[PackedVector2Array] = []
var _cloud_puffs: Array[Vector3] = []

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

## Modo trem flutuante (janela pequena e transparente no desktop): só o trem,
## o trilho e alguns elementos que mostram a região (árvores, postes, clima,
## plataforma). O resto do cenário some para o desktop aparecer por trás.
var floating: bool = false
## Camadas escondidas no modo flutuante (céu, fundo, campo inteiro, escuridão).
const FLOAT_HIDDEN := ["SkyGradient", "SkyFx", "Sun", "Clouds", "Mountains", "MistFar", "Hills", "City",
	"CityFx", "MistNear", "GroundFx", "Dots", "Tufts", "Darkness", "Islands", "TunnelBack", "WaterBack", "TubeBack"]
## Zoom e enquadramento do modo flutuante.
const FLOAT_ZOOM := 0.5
## Ponto do mundo que fica na borda direita da janela (frente do trem + folga).
const FLOAT_RIGHT_X := LOCO_X + 470.0
## Distância (px) do trilho até o pé da janela (espaço do indicador de carvão).
const FLOAT_GROUND_MARGIN := 46.0
var _normal_zoom: float = 0.58
## Deslocamento do mundo (unidades do mundo) que a câmera mostra no canto superior esquerdo.
var _view_origin := Vector2.ZERO

## Escuridão na borda esquerda: avanço aleatório (_dark_surge), avanço enquanto
## o trem está parado (_dark_creep) e o escurecimento ao sair da estação.
var _dark_surge: float = 0.0
var _dark_surge_target: float = 0.0
var _dark_timer: float = 4.0
var _dark_creep: float = 0.0
var _dark_depart: float = 0.0

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


## Velocidade usada na rolagem: igual à real até VISUAL_SOFT m/s; acima
## disso cresce bem menos, para o cenário não virar um borrão nas regiões finais.
const VISUAL_SOFT := 250.0
func _visual_speed(mps: float) -> float:
	mps = maxf(mps, 0.0)
	return mps if mps <= VISUAL_SOFT else VISUAL_SOFT * pow(mps / VISUAL_SOFT, 0.3)


func _on_speed_changed(speed_mps: float, _target: float, stoke: float) -> void:
	_speed_mps = speed_mps
	_stoke = stoke
	_speed_ratio = clampf(speed_mps / full_effect_speed, 0.0, 1.0)


func _on_game_loaded() -> void:
	var game := get_node_or_null(game_path)
	if game and game.state:
		# Ao carregar, o tema entra direto, sem transição.
		_theme_id = _region_now(game.state)
		_prev_theme_id = _theme_id
		_blend = 1.0
		_cur = SeasonThemes.continuous_of(_theme_id)
		_static_dirty = true
		theme_changed.emit(_theme_id)


## Região em que o trem está agora (muda ao sair da estação).
func _region_now(st: GameState) -> String:
	return SeasonThemes.id_for_route(st.route, st.is_at_station())


## Confere a região e, se mudou, começa a transição (cores, céu, música).
func _refresh_region() -> void:
	var game := get_node_or_null(game_path)
	if not game or not game.state:
		return
	var new_theme := _region_now(game.state)
	if new_theme != _theme_id:
		_prev_theme_id = _theme_id
		_theme_id = new_theme
		_blend = 0.0
		theme_changed.emit(_theme_id)


func _on_station_reached(_index: int, station_name: String) -> void:
	_refresh_region()   # passando direto: a região nova começa já
	if _approach_sign.is_empty() or _approach_sign["name"] != station_name:
		_station_signs.append({"x": _size.x + 40.0, "name": station_name})
	# luzinhas subindo da plataforma (alívio de chegar)
	for i in 60:
		_celebration.append({
			"pos": Vector2(LOCO_X + _rng.randf_range(-320, 420), GROUND_Y - _rng.randf_range(20, 160)),
			"vel": Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-120, -40)),
			"rot": _rng.randf_range(0, TAU), "spin": _rng.randf_range(1.5, 4.0),
			"life": _rng.randf_range(2.2, 3.6), "size": _rng.randf_range(2.5, 6.0),
			"color": _rng.randi_range(0, MOTES.size() - 1),
		})


func _on_train_state_changed(st: int) -> void:
	var previous := _train_state
	_train_state = st
	# saindo da estação: a escuridão alcança o trem por um instante
	if previous == TrainMovement.State.AT_STATION and st != TrainMovement.State.AT_STATION:
		_dark_depart = 1.0
		_refresh_region()   # a escurecida da partida cobre a troca de região
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
	var scroll := scroll_per_sqrt_speed * sqrt(_visual_speed(_speed_mps))
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

	_update_darkness(delta)
	_update_particles(delta, scroll)
	_update_layers(delta)


## A escuridão respira na borda; de vez em quando avança um pouco (aleatório),
## chega mais perto quando o trem para e escurece a tela ao sair da estação.
func _update_darkness(delta: float) -> void:
	_dark_timer -= delta
	if _dark_timer <= 0.0:
		if _dark_surge_target > 0.0:
			_dark_surge_target = 0.0
			_dark_timer = _rng.randf_range(6.0, 16.0)
		else:
			_dark_surge_target = _rng.randf_range(0.35, 1.0)
			_dark_timer = _rng.randf_range(1.8, 4.0)
	_dark_surge = move_toward(_dark_surge, _dark_surge_target, delta * 0.6)
	var stopped := 1.0 if _speed_mps < 1.0 else 0.0
	_dark_creep = move_toward(_dark_creep, stopped, delta * (0.12 if stopped > 0.0 else 0.35))
	_dark_depart = maxf(0.0, _dark_depart - delta / 6.0)


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
		c["pos"] += (c["vel"] + Vector2(sin(c["rot"]) * 30.0, 0.0)) * delta
		c["vel"].y -= 12.0 * delta
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
	# cordilheira distante (mais alta, recortada, some na névoa)
	var far := PackedVector2Array()
	var fp := [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU]
	x = 0.0
	while x <= MOUNTAIN_TILE:
		var u := x / MOUNTAIN_TILE * TAU
		var h: float = 190.0 + 90.0 * sin(u * 3.0 + fp[0]) + 46.0 * absf(sin(u * 8.0 + fp[1])) + 18.0 * sin(u * 23.0 + fp[2])
		far.append(Vector2(x, GROUND_Y - 120.0 - h))
		x += 16.0
	_far_points = far
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
			"spire": _rng.randf() < 0.25, "ruin": _rng.randf(), "seed": _rng.randf_range(0, TAU),
			"exist": _rng.randf(), "tall_k": _rng.randf_range(0.8, 2.3), "vine": _rng.randf(),
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
	x = 80.0
	while x < TREE_TILE - 200.0:
		_wrecks.append({"x": x, "kind": _rng.randi_range(0, 2), "flip": _rng.randf() < 0.5, "tilt": _rng.randf_range(-0.08, 0.08),
			"rand": _rng.randf(), "y": _rng.randf_range(-4.0, 6.0), "seed": _rng.randf_range(0, TAU)})
		x += _rng.randf_range(320.0, 620.0)
	x = 60.0
	while x < ISLAND_TILE - 200.0:
		_islands.append({"x": x, "y": _rng.randf_range(GROUND_Y - 560.0, GROUND_Y - 250.0), "w": _rng.randf_range(150.0, 300.0),
			"kind": _rng.randi_range(0, 3), "seed": _rng.randf_range(0, TAU), "far": _rng.randf() < 0.4})
		x += _rng.randf_range(280.0, 540.0)
	for i in 12:
		var pts := PackedVector2Array()
		var cx := _rng.randf_range(0, FRONT_TILE)
		var cy := _rng.randf_range(0.0, 0.9)
		for j in 6:
			pts.append(Vector2(cx, cy))
			cx += _rng.randf_range(30.0, 75.0)
			cy = clampf(cy + _rng.randf_range(-0.08, 0.08), 0.0, 1.0)
		_cracks.append(pts)
	for i in 40:
		_cloud_puffs.append(Vector3(_rng.randf_range(0, FRONT_TILE), _rng.randf_range(0.0, 1.0), _rng.randf_range(40.0, 90.0)))
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
# metade esquerda da textura: círculo nítido; metade direita: brilho suave
var UV_FULL := HudSkin.UV_FULL
var UV_FILL := HudSkin.UV_FILL
var UV_GLOW := HudSkin.UV_GLOW


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


## Brilho suave de luz (halo). Mesma textura: entra no mesmo lote.
func _glow(c: Vector2, r: float, col: Color) -> void:
	_ci.draw_primitive(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)]),
		PackedColorArray([col, col, col, col]), UV_GLOW, _dot)


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
	_add_layer("MistFar", _layer_mist.bind(0), false)  # névoa entre os planos
	_add_layer("Hills", _layer_hills, false)
	_add_layer("City", _layer_city, false)
	_add_layer("Islands", _layer_islands, false)
	_add_layer("CityFx", _layer_city_fx, true, 3)     # fumacinha distante: lenta
	_add_layer("MistNear", _layer_mist.bind(1), false)
	_add_layer("TunnelBack", _layer_tunnel_back, false)
	_add_layer("WaterBack", _layer_water_back, false)
	_add_layer("Trees", _layer_trees, false)
	_add_layer("Wrecks", _layer_wrecks, false)
	_add_layer("TubeBack", _layer_tube_back, false)
	_add_layer("Ground", _layer_ground, false)
	_add_layer("GroundFx", _layer_ground_fx, true)
	_add_layer("Dots", _layer_dots, false)
	_add_layer("GroundDeco", _layer_ground_deco, false)
	_add_layer("Bridge", _layer_bridge, false)
	_add_layer("Track", _layer_track, false)
	_add_layer("Rail", _layer_rail, false)
	_add_layer("Signs", _draw_station_signs, true)
	_add_layer("Poles", _layer_poles, false)
	_add_layer("Pillars", _layer_pillars, false)
	_add_layer("Tube", _layer_tube, false)
	_add_layer("SmokeBack", _draw_smoke.bind(true), true)
	_add_layer("TenderBody", _layer_tender_body, false)
	_add_layer("TenderRims", _layer_tender_rims, false)
	_add_layer("TenderWheels", _layer_tender_wheels, true)
	_add_layer("Beam", _layer_beam, true)
	_add_layer("LocoBody", _layer_loco_body, false)
	_add_layer("LocoRims", _layer_loco_rims, false)
	_add_layer("LocoFx", _layer_loco_fx, true)
	_add_layer("WaterFront", _layer_water_front, true, 2)
	_add_layer("Front", _layer_front, true)
	_add_layer("Tufts", _layer_tufts, false)
	_add_layer("Darkness", _layer_darkness, true, 2)  # move devagar: a cada 2 quadros
	_add_layer("Overlay", _layer_overlay, true)


## Uma vez por quadro: câmera, posição das camadas fixas e redesenho do necessário.
func _update_layers(delta: float = 0.0) -> void:
	scale = Vector2.ONE * camera_zoom
	var view := get_viewport_rect().size
	if floating:
		# trem à direita, trilho perto do pé da janela
		_view_origin = Vector2(FLOAT_RIGHT_X - view.x / camera_zoom, GROUND_Y - (view.y - FLOAT_GROUND_MARGIN) / camera_zoom)
	else:
		_view_origin = Vector2.ZERO
	var size := view / camera_zoom + _view_origin
	if size != _size:
		_size = size
		_static_dirty = true
	# Tranco da câmera (decai rápido). Só move o nó: nada é redesenhado.
	_shake = maxf(0.0, _shake - delta * 2.2)
	position = -_view_origin * camera_zoom
	if _shake > 0.0:
		position += Vector2(sin(_time * 53.0), cos(_time * 41.0)) * 7.0 * _shake * _shake
	_layers["Clouds"].position.x = -_off_cloud
	_layers["Mountains"].position.x = -_off_mountain
	_layers["Hills"].position.x = -_off_hill
	_layers["City"].position.x = -_off_city
	_layers["CityFx"].position.x = -_off_city
	_layers["Trees"].position.x = -_off_tree
	_layers["Wrecks"].position.x = -_off_tree
	_layers["Islands"].position.x = -fmod(_off_hill, ISLAND_TILE)
	_layers["TunnelBack"].position.x = -_off_tree
	_layers["GroundDeco"].position.x = -_off_dots
	_layers["Bridge"].position.x = -_off_track
	_layers["Pillars"].position.x = -_off_poles
	_layers["Tube"].position.x = -_off_poles
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
			if layer.visible:
				layer.queue_redraw()
	_frame += 1
	for layer in _live_layers:
		if layer.visible and _frame % layer.every == 0:
			layer.queue_redraw()


## Liga/desliga o modo trem flutuante: só troca enquadramento e camadas
## visíveis. A simulação, as partículas e o tema continuam os mesmos.
func set_floating(on: bool) -> void:
	if on == floating:
		return
	floating = on
	if on:
		_normal_zoom = camera_zoom
		camera_zoom = FLOAT_ZOOM
	else:
		camera_zoom = _normal_zoom
	for layer_name in FLOAT_HIDDEN:
		_layers[layer_name].visible = not on
	_static_dirty = true
	_update_layers()


## Zoom do modo flutuante (o trem acompanha o tamanho da janelinha).
func set_float_zoom(z: float) -> void:
	if not floating:
		return
	camera_zoom = clampf(z, 0.2, 1.4)
	_static_dirty = true


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


## Sol (dia) ou lua (noite) pintados, com halo suave.
func _layer_sun() -> void:
	var sun: Color = _cur["sun"]
	var r: float = float(_cur["sun_r"]) * 1.45
	var moon: float = _cur["moon"]
	var p := _sun_pos()
	_glow(p, r * 7.5, Color(sun, 0.20 * (1.0 - 0.3 * moon)))
	_glow(p, r * 2.8, Color(sun, 0.35))
	_circle(p, r, sun)
	_circle(p + Vector2(r * 0.16, r * 0.18), r * 0.80, Color(sun.darkened(0.07), 0.6))  # face pintada
	if moon > 0.02:  # crateras da lua
		var crater := Color(sun.darkened(0.22), 0.65 * moon)
		_circle(p + Vector2(-r * 0.30, -r * 0.05), r * 0.20, crater)
		_circle(p + Vector2(r * 0.28, r * 0.32), r * 0.14, crater)
		_circle(p + Vector2(r * 0.35, -r * 0.35), r * 0.10, crater)


## Nuvens pintadas, sem contorno (a cor do tema é misturada com o céu).
func _layer_clouds() -> void:
	var cc: Color = _cur["cloud"]
	var col := (_cur["sky_mid"] as Color).lerp(Color(cc, 1.0), cc.a)
	var shade := col.lerp(_cur["sky_top"], 0.3)
	var parts := [[0, 0, 34], [40, 8, 27], [-38, 10, 25], [14, -18, 26], [72, 16, 19], [-68, 17, 17]]
	_tiled(CLOUD_TILE, func(ox: float):
		for c in _clouds:
			var sc: float = c["scale"]
			var base := Vector2(ox + float(c["x"]), c["y"])
			_glow(base, 120.0 * sc, Color(col, 0.16))
			for part in parts:
				_circle(base + Vector2(part[0], part[1]) * sc, part[2] * sc, shade)
			for part in parts:  # topo iluminado
				_circle(base + Vector2(part[0], part[1] - 6.0) * sc, part[2] * 0.82 * sc, col)
	)


func _layer_mountains() -> void:
	var col: Color = _cur["mountain"]
	var caps: float = _cur["caps"]
	var far := col.lerp(_cur["sky_horizon"], 0.45)
	var rim := col.lightened(0.10)
	_tiled(MOUNTAIN_TILE, func(ox: float):
		var back := PackedVector2Array()
		for p in _far_points:
			back.append(Vector2(p.x + ox, p.y))
		back.append(Vector2(ox + MOUNTAIN_TILE, GROUND_Y))
		back.append(Vector2(ox, GROUND_Y))
		_poly(back, far)
		var poly := PackedVector2Array()
		for p in _mountain_points:
			poly.append(Vector2(p.x + ox, p.y))
		var ridge := poly.duplicate()
		poly.append(Vector2(ox + MOUNTAIN_TILE, GROUND_Y))
		poly.append(Vector2(ox, GROUND_Y))
		_poly(poly, col)
		_polyline(ridge, rim, 3.0)   # luz fria na crista
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
						_poly(cap, Color(col.lerp(Color(0.85, 0.92, 0.95), 0.7), 0.85 * caps))
	)


## Faixa de névoa entre os planos (0: atrás das colinas; 1: atrás das árvores).
## Dá a profundidade de desenho: o que está longe some na neblina.
func _layer_mist(which: int) -> void:
	var fog: Color = _cur["fog"]
	if fog.a <= 0.01:
		return
	var w := _size.x + 40.0
	var y_mid := GROUND_Y - (150.0 if which == 0 else 36.0)
	var h := 150.0 if which == 0 else 120.0
	var solid := Color(fog, fog.a * (1.0 if which == 0 else 0.85))
	var clear := Color(fog, 0.0)
	_grad(PackedVector2Array([Vector2(-20, y_mid - h), Vector2(w, y_mid - h), Vector2(w, y_mid), Vector2(-20, y_mid)]),
		PackedColorArray([clear, clear, solid, solid]))
	_grad(PackedVector2Array([Vector2(-20, y_mid), Vector2(w, y_mid), Vector2(w, y_mid + h * 0.5), Vector2(-20, y_mid + h * 0.5)]),
		PackedColorArray([solid, solid, clear, clear]))


## Colinas entre as montanhas e a cidade: dão profundidade ao mundo maior.
func _layer_hills() -> void:
	var dunes: float = _cur["dunes"]
	var col := (_cur["mountain"] as Color).lerp(_cur["ground_top"], 0.4).darkened(0.25)
	col = col.lerp((_cur["ground_top"] as Color).darkened(0.06), dunes)   # areia
	var rim := col.lightened(0.12 + 0.08 * dunes)
	_tiled(HILL_TILE, func(ox: float):
		var poly := PackedVector2Array()
		for p in _hill_points:
			poly.append(Vector2(p.x + ox, p.y))
		var ridge := poly.duplicate()
		poly.append(Vector2(ox + HILL_TILE, GROUND_Y))
		poly.append(Vector2(ox, GROUND_Y))
		_poly(poly, col)
		_polyline(ridge, rim, 3.0)
	)


func _layer_city() -> void:
	var col: Color = _cur["city"]
	var rim := col.lightened(0.10)
	var lit_a: float = _cur["window"]
	var ruin: float = _cur["ruin"]
	var vines: float = _cur["vines"]
	var tall: float = _cur["tall"]
	var density: float = _cur["city_density"]
	var snow: float = _cur["snow"]
	var eaves: float = _cur["eaves"]
	var deco: float = _cur["deco"]
	var green := Color(0.22, 0.34, 0.18).lerp(col, 0.25)
	var roof_col := Color(0.36, 0.20, 0.16).lerp(col, 0.35)
	_tiled(CITY_TILE, func(ox: float):
		for b in _buildings:
			var x: float = ox + b["x"]
			if x > _size.x + CITY_TILE or x + b["w"] < -CITY_TILE:
				continue
			if float(b["exist"]) > density:
				continue   # deserto: quase nada de pé
			var w: float = b["w"]
			# arranha-céus nas ruínas grandes (até ~3x mais altos)
			var h: float = b["h"] * (1.0 + tall * float(b["tall_k"])) * (1.0 - 0.55 * eaves)
			var top: float = GROUND_Y - 30.0 - h
			var sd: float = b["seed"]
			# ruínas: topo quebrado (fração do tema da região)
			var ruined: bool = float(b["ruin"]) < ruin
			if ruined:
				top += h * 0.3
				_rect(Rect2(x, top, w, GROUND_Y - top), col)
				var tw := w / 4.0
				for k in 4:  # topo serrilhado
					var th := (0.12 + 0.18 * absf(sin(sd + k * 1.9))) * h
					var x0 := x + k * tw
					_quad(PackedVector2Array([Vector2(x0, top + 1), Vector2(x0 + tw * 0.3, top - th), Vector2(x0 + tw * 0.75, top - th * 0.55), Vector2(x0 + tw, top + 1)]), col)
			else:
				_rect(Rect2(x, top, w, h + 30.0), col)
				if eaves > 0.02:  # telhado curvo de beiral, pontas viradas para cima
					var ov := 18.0
					var rh := 22.0 + w * 0.12
					_poly(PackedVector2Array([Vector2(x - ov - 10, top - 10), Vector2(x - ov + 4, top + 2), Vector2(x + w + ov - 4, top + 2),
						Vector2(x + w + ov + 10, top - 10), Vector2(x + w * 0.8, top - rh), Vector2(x + w * 0.2, top - rh)]), Color(roof_col, eaves))
					_line(Vector2(x - ov + 4, top + 2), Vector2(x + w + ov - 4, top + 2), Color(roof_col.darkened(0.4), eaves), 3.0)
				if deco > 0.02:  # coroa escalonada e antena
					_rect(Rect2(x + w * 0.12, top - 34, w * 0.76, 35), Color(col, deco))
					_rect(Rect2(x + w * 0.28, top - 66, w * 0.44, 33), Color(col, deco))
					_line(Vector2(x + w * 0.5, top - 66), Vector2(x + w * 0.5, top - 130), Color(col, deco), 4.0)
					_glow(Vector2(x + w * 0.5, top - 130), 16.0, Color(1.0, 0.45, 0.45, 0.6 * deco))
					var py := top + 30.0
					var row := 0
					while py < GROUND_Y - 50.0:   # janelas redondas (escotilhas)
						for cx in [0.3, 0.7]:
							var lit := (row + int(cx * 10.0) + int(b["x"])) % 4 != 0
							var pc := Vector2(x + w * cx, py)
							if lit:
								if row % 3 == 0:
									_glow(pc, 26.0, Color(WARM_LIGHT, 0.25 * deco))
								_circle(pc, 6.0, Color(col.lerp(WARM_LIGHT, 0.85), deco))
							else:
								_circle(pc, 6.0, Color(col.darkened(0.45), deco))
						py += 44.0
						row += 1
				if b["roof"] and eaves < 0.5 and deco < 0.5:  # telhado pontudo
					_poly(PackedVector2Array([Vector2(x - 6, top + 1), Vector2(x + w * 0.5, top - 52.0), Vector2(x + w + 6, top + 1)]), col)
				if b["spire"] and eaves < 0.5 and deco < 0.5:  # torre fina
					var sx := x + w * 0.5
					_rect(Rect2(sx - 9, top - 60, 18, 61), col)
					_poly(PackedVector2Array([Vector2(sx - 12, top - 59), Vector2(sx, top - 150.0), Vector2(sx + 12, top - 59)]), col)
				if b["chimney"] and eaves < 0.5 and deco < 0.5:
					var cx: float = x + w * b["cx"]
					_rect(Rect2(cx - 8, top - b["ch"], 16, b["ch"] + 1), col)
				if snow > 0.02:  # neve no telhado
					_rect(Rect2(x - 3, top - 4, w + 6, 6), Color(0.80, 0.88, 0.92, 0.8 * snow))
			_rect(Rect2(x, top, 3, GROUND_Y - top), rim)   # luz fria na quina
			# andares vazios dos arranha-céus (buracos escuros em grade)
			if tall > 0.05 and h > 260.0 and deco < 0.5:
				var hole := Color(col.darkened(0.4), tall)
				var fy := top + 40.0
				while fy < GROUND_Y - 60.0:
					for cx in [0.22, 0.5, 0.78]:
						if absf(sin(sd * 3.0 + fy * 0.07 + cx * 9.0)) > 0.25:
							_rect(Rect2(x + w * cx - 6.0, fy, 12.0, 16.0), hole)
					fy += 36.0
			# mato e trepadeiras descendo do topo
			if vines > 0.02 and float(b["vine"]) < 0.85:
				var g := Color(green, vines)
				_rect(Rect2(x - 2, top - 3, w + 4, 7), g)
				for k in 3:
					var vx := x + w * (0.18 + 0.32 * k) + sin(sd + k) * 6.0
					var vl := (0.25 + 0.5 * absf(sin(sd * 2.0 + k * 1.3))) * (GROUND_Y - top) * vines
					_line(Vector2(vx, top), Vector2(vx + sin(sd + k * 2.0) * 8.0, top + vl), g, 5.0)
					for j in int(vl / 26.0):
						_circle(Vector2(vx + sin(sd + j) * 7.0, top + 12.0 + j * 26.0), 6.0, g)
				_circle(Vector2(x + w * 0.3, top - 4), 12.0 * vines, g)
				_circle(Vector2(x + w * 0.72, top - 2), 9.0 * vines, g)
			# janelas em arco; as acesas brilham na névoa
			for wi in (0 if deco > 0.5 else b["windows"]):
				var wr := Rect2(x + 12 + wi * 30, top + 22, 10, 16)
				if wr.end.x > x + w - 6:
					break
				var on: bool = lit_a > 0.02 and (int(b["x"]) + wi) % 3 != 0 and not (ruined and wi % 2 == 1)
				var wc := col.lerp(WARM_LIGHT, lit_a) if on else col.darkened(0.35)
				if on:
					_glow(wr.get_center(), 30.0, Color(WARM_LIGHT, 0.28 * lit_a))
				_rect(wr, wc)
				_poly(PackedVector2Array([wr.position, Vector2(wr.get_center().x, wr.position.y - 6), Vector2(wr.end.x, wr.position.y)]), wc)
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
				var col: Color = (colors[int(t["color"]) % colors.size()] as Color).lerp(_cur["city"], 0.15 + 0.35 * float(_cur["gloom"]))
				if theme["tree_shape"] == "pine":
					_draw_pine(foot, sc, col, alpha, float(_cur["snow"]))
				elif theme["tree_shape"] == "dead":
					_draw_dead_tree(foot, sc, col, alpha, float(t["rand"]))
				elif theme["tree_shape"] == "kelp":
					_draw_kelp(foot, sc, col, alpha, float(t["rand"]))
				else:
					_draw_round_tree(foot, sc, col, alpha, theme["blossom"])
		)


## Algas do fundo do mar: três fitas onduladas com folhinhas.
func _draw_kelp(foot: Vector2, sc: float, col: Color, alpha: float, rnd: float) -> void:
	var c := Color(col, alpha)
	for st in 3:
		var base := foot + Vector2((st - 1) * 10.0 * sc, 0)
		var prev := base
		var hgt := (95.0 + 45.0 * sin(rnd * 7.0 + st)) * sc
		for j in range(1, 9):
			var t := j / 8.0
			var pt := base + Vector2(sin(t * 5.0 + rnd * 9.0 + st) * 12.0 * sc, -hgt * t)
			_line(prev, pt, c, lerpf(7.0, 3.0, t) * sc)
			if j % 2 == 0:
				_circle(pt + Vector2(6.0 * sc, 0), 5.0 * sc, c)
			prev = pt


## Ilhas flutuantes do Céu de Latão: rocha que afina para baixo e, em cima,
## cúpulas, torres de relógio, casarões com hélice e coretos com balão.
func _layer_islands() -> void:
	var v: float = _cur["void"]
	if v <= 0.02:
		return
	var rock := (_cur["mountain"] as Color).lerp(Color(0.42, 0.36, 0.32), 0.75)
	var grass := Color(0.50, 0.60, 0.38)
	var bld: Color = _cur["city"]
	var fog: Color = _cur["fog"]
	_tiled(ISLAND_TILE, func(ox: float):
		for isl in _islands:
			var far: bool = isl["far"]
			var sc := 0.55 if far else 1.0
			var x: float = ox + isl["x"]
			var w: float = float(isl["w"]) * sc
			var y: float = float(isl["y"]) - (90.0 if far else 0.0)
			var sd: float = isl["seed"]
			var mix := 0.5 if far else 0.0   # as distantes somem na névoa
			var rc := Color(rock.lerp(fog, mix), v)
			var bc := Color(bld.lerp(fog, mix), v)
			_poly(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w * 0.82, y + 40.0 * sc),
				Vector2(x + w * 0.6, y + (95.0 + 30.0 * sin(sd)) * sc), Vector2(x + w * 0.45, y + 135.0 * sc),
				Vector2(x + w * 0.3, y + 72.0 * sc), Vector2(x + w * 0.12, y + 36.0 * sc)]), rc)
			_rect(Rect2(x - 4, y - 8.0 * sc, w + 8, 12.0 * sc), Color(grass.lerp(fog, mix), v))
			var cx := x + w * 0.5
			match int(isl["kind"]):
				0:  # cúpula com mastro
					_rect(Rect2(cx - w * 0.28, y - 60.0 * sc, w * 0.56, 54.0 * sc), bc)
					_circle(Vector2(cx, y - 60.0 * sc), w * 0.28, bc)
					_rect(Rect2(cx - 2, y - 60.0 * sc - w * 0.28 - 40.0 * sc, 4, 40.0 * sc), Color(BRASS.lerp(fog, mix), v))
				1:  # torre do relógio
					_rect(Rect2(cx - 22.0 * sc, y - 170.0 * sc, 44.0 * sc, 164.0 * sc), bc)
					_poly(PackedVector2Array([Vector2(cx - 28.0 * sc, y - 168.0 * sc), Vector2(cx, y - 222.0 * sc), Vector2(cx + 28.0 * sc, y - 168.0 * sc)]), bc)
					_circle(Vector2(cx, y - 140.0 * sc), 14.0 * sc, Color(CREAM.lerp(fog, mix), v))
					_line(Vector2(cx, y - 140.0 * sc), Vector2(cx + 6.0 * sc, y - 148.0 * sc), Color(INK, v), 2.0)
				2:  # casarão com hélice
					_rect(Rect2(x + w * 0.15, y - 70.0 * sc, w * 0.6, 64.0 * sc), bc)
					_poly(PackedVector2Array([Vector2(x + w * 0.1, y - 68.0 * sc), Vector2(x + w * 0.45, y - 112.0 * sc), Vector2(x + w * 0.8, y - 68.0 * sc)]), bc)
					var hp := Vector2(x + w * 0.88, y + 24.0 * sc)
					_rect(Rect2(hp.x - 3, hp.y - 30.0 * sc, 6, 30.0 * sc), Color(BRASS_DARK.lerp(fog, mix), v))
					for k in 3:
						var a := sd + k * TAU / 3.0
						_line(hp, hp + Vector2(cos(a), sin(a) * 0.35) * 28.0 * sc, Color(BRASS.lerp(fog, mix), v), 5.0 * sc)
				_:  # coreto com balão amarrado
					_rect(Rect2(cx - w * 0.25, y - 52.0 * sc, w * 0.5, 7.0 * sc), bc)
					for k in 4:
						_rect(Rect2(cx - w * 0.23 + k * w * 0.15, y - 46.0 * sc, 4, 40.0 * sc), bc)
					var bp := Vector2(cx + w * 0.1, y - 195.0 * sc)
					_line(bp + Vector2(-18, 30) * sc, Vector2(cx - 12, y - 52.0 * sc), Color(INK, 0.6 * v), 1.5)
					_line(bp + Vector2(18, 30) * sc, Vector2(cx + 22, y - 52.0 * sc), Color(INK, 0.6 * v), 1.5)
					_circle(bp, 38.0 * sc, Color(Color(0.74, 0.36, 0.28).lerp(fog, mix), v))
					_circle(bp + Vector2(-10, -12) * sc, 12.0 * sc, Color(1, 1, 1, 0.18 * v))
	)


## Galerias de Pedra: parede de blocos com arcos e lampiões, teto que some no
## escuro. Cobre o céu e o fundo inteiros.
func _layer_tunnel_back() -> void:
	var t: float = _cur["tunnel"]
	if t <= 0.02:
		return
	var stone: Color = _cur["city"]
	var joint := Color(stone.darkened(0.45), 0.8 * t)
	var niche := Color(stone.darkened(0.62), t)
	var arch := Color(stone.lightened(0.08), t)
	var top := -40.0
	var bottom := GROUND_Y - 6.0
	_tiled(TREE_TILE, func(ox: float):
		_rect(Rect2(ox - 2, top, TREE_TILE + 4, bottom - top), Color(stone, t))
		var row := 0
		var y := bottom - 44.0
		while y > top:   # fiadas de pedra
			_line(Vector2(ox, y), Vector2(ox + TREE_TILE, y), joint, 3.0)
			var jx := ox + (0.0 if row % 2 == 0 else 45.0)
			while jx < ox + TREE_TILE:
				_line(Vector2(jx, y), Vector2(jx, y + 44.0), joint, 2.5)
				jx += 90.0
			y -= 44.0
			row += 1
		var ax := ox + 110.0
		while ax < ox + TREE_TILE - 100.0:   # nichos em arco e um lampião entre eles
			var aw := 150.0
			var arc_top := bottom - 290.0
			_rect(Rect2(ax, arc_top, aw, bottom - arc_top), niche)
			_circle(Vector2(ax + aw * 0.5, arc_top), aw * 0.5, niche)
			_arc(Vector2(ax + aw * 0.5, arc_top), aw * 0.5 + 8.0, PI, TAU, 12, arch, 13.0)
			var lp := Vector2(ax + aw + 105.0, bottom - 250.0)
			_glow(lp, 230.0, Color(WARM_LIGHT, 0.20 * t))
			_glow(lp, 60.0, Color(WARM_LIGHT, 0.5 * t))
			_rect(Rect2(lp.x - 3, lp.y + 10, 6, 26), Color(INK, t))
			_ink_rect(Rect2(lp - Vector2(8, 12), Vector2(16, 22)), Color(WARM_LIGHT, t), 2.0, Color(INK, t))
			ax += 360.0
	)
	# abóbada: o teto se perde no escuro
	var w := _size.x + TREE_TILE + 40.0
	_grad(PackedVector2Array([Vector2(-20, top), Vector2(w, top), Vector2(w, top + 340.0), Vector2(-20, top + 340.0)]),
		PackedColorArray([Color(DARK, 0.94 * t), Color(DARK, 0.94 * t), Color(DARK, 0.0), Color(DARK, 0.0)]))


## Vila Alagada: espelho d'água cobrindo a parte de baixo das casas.
func _layer_water_back() -> void:
	var wv: float = _cur["water"]
	if wv <= 0.02:
		return
	var water: Color = _cur["ground_top"]
	var sky: Color = _cur["sky_horizon"]
	var y0 := GROUND_Y - 78.0
	var w := _size.x + 40.0
	var top_c := Color(water.lerp(sky, 0.35), 0.95 * wv)
	_grad(PackedVector2Array([Vector2(-20, y0), Vector2(w, y0), Vector2(w, GROUND_Y), Vector2(-20, GROUND_Y)]),
		PackedColorArray([top_c, top_c, Color(water, wv), Color(water, wv)]))
	_line(Vector2(-20, y0), Vector2(w, y0), Color(sky.lightened(0.2), 0.8 * wv), 2.5)
	for i in 26:   # brilhos do reflexo
		var rx := fmod(i * 137.0, w)
		var ry := y0 + 8.0 + fmod(i * 23.0, 64.0)
		_line(Vector2(rx, ry), Vector2(rx + 40.0 + fmod(i * 17.0, 50.0), ry), Color(sky.lightened(0.3), 0.35 * wv), 2.0)


## Fossa de Latão: vidro do tubo por trás do trem (tom, reflexos e a borda de cima).
func _layer_tube_back() -> void:
	var d: float = _cur["deep"]
	if d <= 0.02:
		return
	var w := _size.x + 40.0
	var glass: Color = (_cur["sky_horizon"] as Color).lightened(0.25)
	_rect(Rect2(-20, TUBE_TOP, w + 20, GROUND_Y - TUBE_TOP), Color(glass, 0.14 * d))
	for i in 9:
		var gx := fmod(i * 233.0, w) + 100.0
		_quad(PackedVector2Array([Vector2(gx, TUBE_TOP + 10), Vector2(gx + 50, TUBE_TOP + 10), Vector2(gx - 90, GROUND_Y - 20), Vector2(gx - 140, GROUND_Y - 20)]), Color(1, 1, 1, 0.05 * d))
	_rect(Rect2(-20, TUBE_TOP - 14, w + 20, 16), Color(BRASS_DARK.darkened(0.3), d))
	_rect(Rect2(-20, TUBE_TOP - 14, w + 20, 4), Color(BRASS, 0.7 * d))


## Rachaduras de lava (Mar de Cinzas), nuvens sob a ponte (Céu de Latão) e
## reflexos na água (Vila Alagada), rolando com o chão.
func _layer_ground_deco() -> void:
	var lava: float = _cur["lava"]
	var v: float = _cur["void"]
	var wv: float = _cur["water"]
	if lava <= 0.02 and v <= 0.02 and wv <= 0.02:
		return
	var depth := maxf(40.0, _size.y - GROUND_Y - 60.0)
	_tiled(FRONT_TILE, func(ox: float):
		if v > 0.02:
			for pf in _cloud_puffs:
				var c := Vector2(ox + pf.x, GROUND_Y + 40.0 + pf.y * depth)
				_circle(c + Vector2(0, 8), pf.z, Color(0.80, 0.85, 0.92, 0.8 * v))
				_circle(c, pf.z * 0.9, Color(1, 1, 1, 0.92 * v))
		if lava > 0.02:
			for cr in _cracks:
				var pts := PackedVector2Array()
				for pt in cr:
					pts.append(Vector2(ox + pt.x, GROUND_Y + 50.0 + pt.y * depth))
				_glow(pts[pts.size() / 2], 90.0, Color(1.0, 0.35, 0.08, 0.22 * lava))
				_polyline(pts, Color(1.0, 0.40, 0.10, 0.35 * lava), 11.0)
				_polyline(pts, Color(1.0, 0.72, 0.32, 0.9 * lava), 3.5)
		if wv > 0.02:
			for d in _dots:
				var pd := Vector2(ox + d.x, GROUND_Y + 50.0 + d.y * depth)
				_line(pd, pd + Vector2(30.0 + d.z * 8.0, 0), Color(1, 1, 1, 0.20 * wv), 2.0)
	)


## Céu de Latão: o trilho corre numa ponte de treliça; pilares descem até sumir
## nas nuvens e cabos sobem para as ilhas.
func _layer_bridge() -> void:
	var v: float = _cur["void"]
	if v <= 0.02:
		return
	var iron := Color(0.22, 0.20, 0.20, v)
	var brace := Color(BRASS_DARK.darkened(0.2), v)
	var tiles := int(ceil(_size.x / TRACK_TILE)) + 2
	var deck_top := GROUND_Y + 4.0
	var deck_bot := GROUND_Y + 54.0
	var span := tiles * TRACK_TILE + 40.0
	_rect(Rect2(-20, deck_top, span, deck_bot - deck_top), iron)
	_rect(Rect2(-20, deck_top, span, 4), Color(BRASS_DARK, v))
	_rect(Rect2(-20, deck_bot - 4, span, 4), Color(BRASS_DARK, v))
	var x := 0.0
	while x < tiles * TRACK_TILE:   # treliça em X
		_line(Vector2(x, deck_top + 4), Vector2(x + 65, deck_bot - 4), brace, 4.0)
		_line(Vector2(x + 65, deck_top + 4), Vector2(x, deck_bot - 4), brace, 4.0)
		x += 65.0
	for k in tiles:   # um pilar por bloco; o resto é vão livre
		var px := k * TRACK_TILE + 260.0
		_quad(PackedVector2Array([Vector2(px, deck_bot), Vector2(px + 60, deck_bot), Vector2(px + 95, _size.y + 40), Vector2(px - 35, _size.y + 40)]), iron)
		for j in 6:
			var yy := deck_bot + 30.0 + j * 60.0
			_line(Vector2(px - 6, yy), Vector2(px + 66, yy + 30), brace, 3.0)
		_line(Vector2(px + 30, deck_top), Vector2(px + 430, -40), Color(INK, 0.45 * v), 2.0)
		_line(Vector2(px + 30, deck_top), Vector2(px - 370, -40), Color(INK, 0.45 * v), 2.0)


## Galerias de Pedra: pilares de pedra com lampião (no lugar dos postes).
func _layer_pillars() -> void:
	var t: float = _cur["tunnel"]
	if t <= 0.02:
		return
	var stone := (_cur["city"] as Color).lightened(0.06)
	var x := -POLE_SPACING
	while x < _size.x + POLE_SPACING * 2.0:
		_rect(Rect2(x - 18, -60, 52, GROUND_Y + 60), Color(stone, t))
		_rect(Rect2(x - 18, -60, 6, GROUND_Y + 60), Color(stone.lightened(0.12), t))
		_rect(Rect2(x + 28, -60, 6, GROUND_Y + 60), Color(stone.darkened(0.4), t))
		var y := GROUND_Y - 40.0
		while y > -60.0:
			_line(Vector2(x - 18, y), Vector2(x + 34, y), Color(stone.darkened(0.45), t), 2.0)
			y -= 40.0
		var lp := Vector2(x + 54.0, GROUND_Y - 300.0)
		_glow(lp, 170.0, Color(WARM_LIGHT, 0.30 * t))
		_glow(lp, 44.0, Color(WARM_LIGHT, 0.55 * t))
		_line(Vector2(x + 34, lp.y - 18), lp + Vector2(0, -18), Color(INK, t), 3.0)
		_ink_rect(Rect2(lp - Vector2(7, 12), Vector2(14, 22)), Color(WARM_LIGHT, t), 2.5, Color(INK, t))
		_ink_poly(PackedVector2Array([lp + Vector2(-10, -12), lp + Vector2(0, -20), lp + Vector2(10, -12)]), Color(CHARCOAL, t), 2.0, Color(INK, t))
		x += POLE_SPACING


## Fossa de Latão: costelas de ferro rebitado do tubo, passando atrás do trem.
func _layer_tube() -> void:
	var d: float = _cur["deep"]
	if d <= 0.02:
		return
	var iron := Color(0.16, 0.18, 0.18, d)
	var x := -POLE_SPACING
	while x < _size.x + POLE_SPACING * 2.0:
		_rect(Rect2(x, TUBE_TOP - 14, 26, GROUND_Y - TUBE_TOP + 60), iron)
		_rect(Rect2(x + 3, TUBE_TOP - 14, 5, GROUND_Y - TUBE_TOP + 60), Color(BRASS_DARK, d))
		var y := TUBE_TOP + 10.0
		while y < GROUND_Y + 30.0:
			_circle(Vector2(x + 18, y), 3.0, Color(BRASS, d))
			y += 34.0
		x += POLE_SPACING


## Vila Alagada: água na frente das rodas, superfície ondulando e espuma.
func _layer_water_front() -> void:
	var wv: float = _cur["water"]
	if wv <= 0.02:
		return
	var water: Color = _cur["ground_top"]
	var ys := GROUND_Y - 46.0
	var w := _size.x + 40.0
	var pts := PackedVector2Array()
	var x := -20.0
	while x <= w + 40.0:
		pts.append(Vector2(x, ys + sin(x * 0.02 + _time * 2.4) * 3.0))
		x += 40.0
	var body := pts.duplicate()
	body.append(Vector2(pts[pts.size() - 1].x, _size.y + 20))
	body.append(Vector2(-20, _size.y + 20))
	_poly(body, Color(water, 0.55 * wv))
	_polyline(pts, Color(water.lightened(0.45), 0.85 * wv), 2.5)
	var foam := 0.45 * wv * clampf(_speed_ratio * 2.0, 0.2, 1.0)
	var wheels: Array = []
	for c in _tender_wheels():
		wheels.append(c.x)
	for wl in _loco_wheels():
		wheels.append(wl[0].x)
	for wx in wheels:
		for k in 3:
			var fx: float = wx + sin(_time * 7.0 + k * 2.1 + wx) * 16.0
			_circle(Vector2(fx, ys + 2.0), 6.0 + 3.0 * sin(_time * 9.0 + k), Color(1, 1, 1, foam))


## Árvore seca: tronco torto e galhos sem folha.
func _draw_dead_tree(foot: Vector2, sc: float, col: Color, alpha: float, rnd: float) -> void:
	var c := Color(col, alpha)
	var lean := (rnd - 0.5) * 16.0 * sc
	var top := foot + Vector2(lean, -70.0 * sc)
	_line(foot, foot.lerp(top, 0.55) + Vector2(-lean * 0.3, 0), c, 8.0 * sc)
	_line(foot.lerp(top, 0.55) + Vector2(-lean * 0.3, 0), top, c, 5.5 * sc)
	for k in 4:
		var t := 0.4 + k * 0.17
		var base := foot.lerp(top, t)
		var side := -1.0 if k % 2 == 0 else 1.0
		var tip := base + Vector2(side * (20.0 + 10.0 * sin(rnd * 9.0 + k)) * sc, -(16.0 + 6.0 * k) * sc)
		_line(base, tip, c, (4.0 - k * 0.6) * sc)
		_line(tip, tip + Vector2(side * 9.0 * sc, -10.0 * sc), c, 2.0 * sc)
		_line(base.lerp(tip, 0.6), base.lerp(tip, 0.6) + Vector2(-side * 4.0 * sc, -12.0 * sc), c, 1.8 * sc)


## Carros, ônibus e caminhões largados: lataria enferrujada, sem rodas,
## tomados pelo mato ou cobertos de areia/neve conforme a região.
func _layer_wrecks() -> void:
	var amount: float = _cur["wrecks"]
	if amount <= 0.02:
		return
	var rust := Color(0.40, 0.23, 0.14).lerp(_cur["city"], 0.45)
	var dark := rust.darkened(0.45)
	var vines: float = _cur["vines"]
	var snow: float = _cur["snow"]
	var dunes: float = _cur["dunes"]
	var green := Color(0.22, 0.34, 0.18).lerp(_cur["city"], 0.2)
	var sand := (_cur["ground_top"] as Color)
	_tiled(TREE_TILE, func(ox: float):
		for wr in _wrecks:
			if float(wr["rand"]) > amount:
				continue
			var x: float = ox + wr["x"]
			if x < -260.0 or x > _size.x + TREE_TILE:
				continue
			var kind: int = wr["kind"]
			var length: float = [130.0, 230.0, 170.0][kind]
			var height: float = [34.0, 62.0, 48.0][kind]
			var base := Vector2(x, GROUND_Y - 8.0 + float(wr["y"]))
			var tilt: float = wr["tilt"]
			var up := Vector2(sin(tilt), -cos(tilt))
			var along := Vector2(cos(tilt), sin(tilt))
			var body := PackedVector2Array([base, base + along * length, base + along * length + up * height, base + up * height])
			_ink_poly(body, rust, 2.0, dark)
			match kind:
				0:  # carro: cabine com janelas vazias
					var c0 := base + along * length * 0.25 + up * height
					var c1 := base + along * length * 0.72 + up * height
					var cab := PackedVector2Array([c0, c1, c1 + up * 24.0 - along * 14.0, c0 + up * 24.0 + along * 12.0])
					_ink_poly(cab, rust, 2.0, dark)
					_quad(PackedVector2Array([c0 + along * 14.0 + up * 3.0, c1 - along * 18.0 + up * 3.0, c1 - along * 24.0 + up * 19.0, c0 + along * 18.0 + up * 19.0]), dark)
				1:  # ônibus: fileira de janelas
					for k in 6:
						var wx := base + along * (14.0 + k * 35.0) + up * (height - 34.0)
						_quad(PackedVector2Array([wx, wx + along * 24.0, wx + along * 24.0 + up * 20.0, wx + up * 20.0]), dark)
				2:  # caminhão: cabine alta na frente
					var front := base + along * (length * 0.72)
					var cab2 := PackedVector2Array([front + up * height, front + along * length * 0.28 + up * height,
						front + along * length * 0.28 + up * (height + 30.0), front + along * 6.0 + up * (height + 30.0)])
					_ink_poly(cab2, rust.lightened(0.05), 2.0, dark)
			# rodas faltando: só os buracos escuros
			for wx in [0.18, 0.82]:
				_circle(base + along * length * wx + up * 4.0, 12.0, dark)
			# manchas de ferrugem
			_circle(base + along * length * 0.4 + up * height * 0.5, height * 0.22, Color(0.55, 0.30, 0.16, 0.5))
			if vines > 0.02:  # mato por cima e em volta
				var g := Color(green, vines)
				for k in 5:
					_circle(base + along * length * (0.1 + k * 0.2) + up * (height + 4.0 + 5.0 * sin(float(wr["seed"]) + k)), 9.0 + 4.0 * sin(k * 1.7), g)
				_circle(base + along * length * 0.05 + up * 6.0, 14.0, g)
			if dunes > 0.02:  # areia acumulada de um lado
				_poly(PackedVector2Array([base + along * length * 0.55, base + along * (length + 40.0), base + along * length * 0.9 + up * height * 0.7]), Color(sand, dunes))
			if snow > 0.02:
				_rect(Rect2(base + up * (height + 4.0), Vector2(length * 0.9, 6.0)), Color(0.80, 0.88, 0.92, 0.85 * snow))
	)


func _draw_round_tree(foot: Vector2, sc: float, col: Color, alpha: float, blossom: bool) -> void:
	var ink := Color(col.darkened(0.7), alpha * alpha)
	var c := Color(col, alpha)
	var top := foot + Vector2(0, -66 * sc)
	var blobs := [[Vector2.ZERO, 30.0], [Vector2(-23, 12), 22.0], [Vector2(23, 12), 22.0], [Vector2(0, 16), 22.0]]
	_rect(Rect2(foot.x - 5 * sc, foot.y - 46 * sc, 10 * sc, 46 * sc).grow(1.5), ink)
	for bl in blobs:
		_circle(top + bl[0] * sc, bl[1] * sc + 2.0, ink)
	_rect(Rect2(foot.x - 5 * sc, foot.y - 46 * sc, 10 * sc, 46 * sc), Color(WOOD_DARK, alpha))
	for bl in blobs:
		_circle(top + bl[0] * sc, bl[1] * sc, Color(col.darkened(0.18), alpha))   # sombra
	_circle(top + Vector2(-4, -4) * sc, 26 * sc, c)
	_circle(top + Vector2(-18, 8) * sc, 15 * sc, c)
	_circle(top + Vector2(-10, -12) * sc, 11 * sc, Color(col.lightened(0.10), alpha))  # brilho
	if blossom:
		for i in 7:
			var a := i * 0.9 + foot.x * 0.05
			_circle(top + Vector2(cos(a), sin(a) * 0.8) * (10.0 + (i % 3) * 9.0) * sc, 3.2 * sc, Color(1, 1, 1, 0.55 * alpha))


func _draw_pine(foot: Vector2, sc: float, col: Color, alpha: float, snow: float) -> void:
	var ink := Color(col.darkened(0.7), alpha * alpha)
	var trunk := Rect2(foot.x - 4 * sc, foot.y - 16 * sc, 8 * sc, 16 * sc)
	var tiers: Array[PackedVector2Array] = []
	for i in 3:
		var base_y := foot.y - (12.0 + i * 28.0) * sc
		var half := (30.0 - i * 7.0) * sc
		tiers.append(PackedVector2Array([Vector2(foot.x - half, base_y), Vector2(foot.x + half, base_y), Vector2(foot.x, base_y - 42.0 * sc)]))
	_rect(trunk.grow(1.5), ink)
	for t in tiers:
		_ink_outline(t, 1.8, ink)
	_rect(trunk, Color(WOOD_DARK, alpha))
	for t in tiers:
		_poly(t, Color(col, alpha))
		# lado iluminado
		_poly(PackedVector2Array([t[0], t[2], t[0].lerp(t[1], 0.4)]), Color(col.lightened(0.12), alpha))
		if snow > 0.02:  # neve nos galhos
			var tip := t[2]
			var half := (t[1].x - t[0].x) * 0.5
			_poly(PackedVector2Array([tip, tip + Vector2(-half * 0.45, 19.0 * sc), tip + Vector2(0, 13.0 * sc), tip + Vector2(half * 0.45, 19.0 * sc)]),
				Color(0.80, 0.88, 0.92, 0.85 * alpha * snow))


func _layer_ground() -> void:
	# campo (grama, trigo, folhas ou neve, conforme o tema)
	var g_top: Color = _cur["ground_top"]
	var g_bot: Color = _cur["ground_bottom"]
	var w := _size.x + 40.0
	if floating:
		# modo flutuante: só uma faixa de chão sob o trilho, que some para cima
		_grad(PackedVector2Array([Vector2(-20, GROUND_Y - 34), Vector2(w, GROUND_Y - 34), Vector2(w, GROUND_Y - 6), Vector2(-20, GROUND_Y - 6)]),
			PackedColorArray([Color(g_top, 0.0), Color(g_top, 0.0), g_top, g_top]))
		var ballast_f: Color = _cur["ballast"]
		_rect(Rect2(-20, GROUND_Y - 6, w + 20, 8), g_top)
		_rect(Rect2(-20, GROUND_Y + 2, w + 20, 34), ballast_f.darkened(0.45))
		_rect(Rect2(-20, GROUND_Y + 5, w + 20, 28), ballast_f)
		_void_below(w)
		return
	_grad(PackedVector2Array([Vector2(-20, GROUND_Y - 8), Vector2(w, GROUND_Y - 8), Vector2(w, _size.y + 20), Vector2(-20, _size.y + 20)]),
		PackedColorArray([g_top, g_top, g_bot, g_bot]))
	# faixa de luz no horizonte do campo e linha de tinta
	_rect(Rect2(-20, GROUND_Y - 8, w + 20, 6), g_top.lightened(0.05))
	_line(Vector2(-20, GROUND_Y - 8), Vector2(w, GROUND_Y - 8), g_top.darkened(0.45), 3.0)
	# lastro de brita (faixa) com contorno
	var ballast: Color = _cur["ballast"]
	_rect(Rect2(-20, GROUND_Y + 2, w + 20, 34), ballast.darkened(0.45))
	_rect(Rect2(-20, GROUND_Y + 5, w + 20, 28), ballast)
	_void_below(w)


## Céu de Latão: não há chão, só o céu e o mar de nuvens lá embaixo.
func _void_below(w: float) -> void:
	var v: float = _cur["void"]
	if v <= 0.02:
		return
	var hor: Color = _cur["sky_horizon"]
	var low: Color = _cur["ground_bottom"]
	_grad(PackedVector2Array([Vector2(-20, GROUND_Y - 10), Vector2(w, GROUND_Y - 10), Vector2(w, _size.y + 20), Vector2(-20, _size.y + 20)]),
		PackedColorArray([Color(hor, v), Color(hor, v), Color(low, v), Color(low, v)]))


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
				_circle(p, r + 1.5, Color(INK, 0.35 * a))
				_circle(p, r, Color(col, a))
				_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.25 * a))
		)


## Pedras da brita e dormentes de madeira, em blocos que se repetem.
func _layer_track() -> void:
	var stone: Color = (_cur["ballast"] as Color).lightened(0.2)
	var stone_ink: Color = (_cur["ballast"] as Color).darkened(0.4)
	var tiles := int(ceil(_size.x / TRACK_TILE)) + 1
	for k in (0 if float(_cur["void"]) > 0.5 else tiles):   # na ponte não tem brita
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
	var lamp: float = _cur["lamp"]
	var vines: float = _cur["vines"]
	if float(_cur["tunnel"]) + float(_cur["deep"]) > 0.5:
		return   # túnel e tubo: pilares de pedra / costelas de ferro no lugar dos postes
	while x < _size.x + POLE_SPACING * 2.0:
		_ink_group([["r", Rect2(x, GROUND_Y - 220, 11, 220), pole], ["r", Rect2(x - 24, GROUND_Y - 208, 59, 8), pole]], 2.5, ink)
		_rect(Rect2(x, GROUND_Y - 220, 3, 220), pole.lightened(0.10))
		for dx in [-18.0, 29.0]:
			_ink_circle(Vector2(x + dx, GROUND_Y - 213), 4.0, METAL, 2.0, ink)
		# lampião pendurado no braço do poste
		var lp := Vector2(x + 44.0, GROUND_Y - 176.0)
		_line(Vector2(x + 35, GROUND_Y - 204), Vector2(x + 44, GROUND_Y - 204), ink, 3.0)
		_line(Vector2(x + 44, GROUND_Y - 204), lp + Vector2(0, -14), ink, 2.0)
		if lamp > 0.02:
			_glow(lp, 120.0, Color(WARM_LIGHT, 0.30 * lamp))
			_glow(lp, 40.0, Color(WARM_LIGHT, 0.45 * lamp))
		_ink_rect(Rect2(lp - Vector2(7, 12), Vector2(14, 22)), CHARCOAL.lerp(WARM_LIGHT, lamp), 2.5, ink)
		_ink_poly(PackedVector2Array([lp + Vector2(-10, -12), lp + Vector2(0, -20), lp + Vector2(10, -12)]), CHARCOAL, 2.0, ink)
		if vines > 0.02:  # trepadeira subindo pelo poste
			var g := Color(Color(0.22, 0.34, 0.18), vines)
			for k in 7:
				_circle(Vector2(x + 5 + sin(k * 1.9) * 7.0, GROUND_Y - 12 - k * 22.0), 8.0 - k * 0.5, g)
		tops.append(Vector2(x, GROUND_Y - 213))
		x += POLE_SPACING
	# fios caídos entre os postes
	for i in range(tops.size() - 1):
		for dx in [-18.0, 29.0]:
			var a: Vector2 = tops[i] + Vector2(dx, 0)
			var b: Vector2 = tops[i + 1] + Vector2(dx, 0)
			var pts := PackedVector2Array()
			for sgi in 9:
				var t := sgi / 8.0
				pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * 26.0))
			_polyline(pts, Color(INK, 0.8), 1.6)


func _layer_tufts() -> void:
	if float(_cur["tunnel"]) + float(_cur["deep"]) + float(_cur["void"]) + float(_cur["water"]) > 0.5:
		return   # sem mato no primeiro plano no túnel, na água, no tubo e no céu
	var c: Color = (_cur["tuft"] as Color).darkened(0.45)
	var light := c.lightened(0.08)
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
				_ink_poly(blade, c if k % 2 == 0 else light, 1.4, c.darkened(0.6))
				if snow > 0.02:
					_circle(Vector2(x, y) + dir * length, 4.0, Color(0.78, 0.86, 0.90, snow))
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
	var dp: float = _cur["deep"]
	if dp > 0.02:   # fundo do mar: feixes de luz descendo e uma criatura enorme ao longe
		var shaft := Color(0.6, 0.92, 0.92, 0.09 * dp)
		var clear := Color(0.6, 0.92, 0.92, 0.0)
		for i in 5:
			var sx := _size.x * (0.14 + i * 0.2) + sin(_time * 0.3 + i * 1.7) * 40.0
			_grad(PackedVector2Array([Vector2(sx - 40, -20), Vector2(sx + 40, -20), Vector2(sx - 70, GROUND_Y - 120), Vector2(sx - 210, GROUND_Y - 120)]),
				PackedColorArray([shaft, shaft, clear, clear]))
		var cx := fposmod(_time * 16.0, _size.x + 1600.0) - 800.0
		var cy := GROUND_Y - 560.0 + sin(_time * 0.2) * 30.0
		var cc := Color((_cur["sky_mid"] as Color).darkened(0.4), 0.85 * dp)
		for k in 7:
			_circle(Vector2(cx - k * 46.0, cy + sin(_time * 0.8 - k * 0.5) * 6.0), 62.0 - k * 7.0, cc)
		var tail := Vector2(cx - 330.0, cy + sin(_time * 0.8 - 3.5) * 6.0)
		_poly(PackedVector2Array([tail, tail + Vector2(-70, -46 + sin(_time) * 10.0), tail + Vector2(-50, 4), tail + Vector2(-70, 50 + sin(_time) * 10.0)]), cc)
		_poly(PackedVector2Array([Vector2(cx - 60, cy + 40), Vector2(cx - 120, cy + 110), Vector2(cx - 130, cy + 50)]), cc)
	var lv: float = _cur["lava"]
	if lv > 0.02:   # silhueta colossal parada na névoa, respirando
		var base := Vector2(_size.x * 0.36, GROUND_Y - 110.0)
		var br := sin(_time * 0.4) * 5.0
		var sc2 := Color((_cur["sky_mid"] as Color).darkened(0.6), 0.85 * lv)
		_ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-120, 0), base + Vector2(-80, -380 + br), base + Vector2(-40, -470 + br),
			base + Vector2(50, -480 + br), base + Vector2(90, -390 + br), base + Vector2(130, 0)]), sc2)
		_circle(base + Vector2(8, -505 + br), 46.0, sc2)
		_poly(PackedVector2Array([base + Vector2(-24, -530 + br), base + Vector2(-66, -610 + br), base + Vector2(-8, -546 + br)]), sc2)
		_poly(PackedVector2Array([base + Vector2(40, -530 + br), base + Vector2(82, -610 + br), base + Vector2(24, -546 + br)]), sc2)
		var eye := Color(1.0, 0.42, 0.12, (0.35 + 0.2 * sin(_time * 0.7)) * lv)
		_glow(base + Vector2(-8, -508 + br), 14.0, eye)
		_glow(base + Vector2(24, -508 + br), 14.0, eye)
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
			_poly(PackedVector2Array([p + dir * (r + 10.0) - side, p + dir * length, p + dir * (r + 10.0) + side]), Color(sun, 0.14 * rays))


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
			if float(b["ruin"]) < float(_cur["ruin"]) or float(b["exist"]) > float(_cur["city_density"]) or float(_cur["tall"]) > 0.3 \
					or float(_cur["eaves"]) > 0.3 or float(_cur["deco"]) > 0.3:
				continue   # ruína, prédio ausente ou arranha-céu: sem chaminé nem engrenagem
			if b["chimney"]:
				var cx: float = x + b["w"] * b["cx"]
				for j in 3:
					var t := fmod(_time * 0.4 + j * 0.33 + b["x"] * 0.01, 1.0)
					_circle(Vector2(cx - t * 40.0, top - b["ch"] - 10 - t * 56.0), 7 + t * 14, Color((_cur["fog"] as Color).darkened(0.2), 0.30 * (1.0 - t)))
			if b["gear"]:
				var gc := Vector2(x + b["w"] * 0.5, top - 6)
				_ink_gear(gc, 34, 25, 10, _time * 0.4, col.lightened(0.08), 2.5, ink)
				_ink_circle(gc, 9, (_cur["sky_mid"] as Color).lerp(col, 0.4), 2.0, ink)


func _layer_tender_wheels() -> void:
	for c in _tender_wheels():
		_draw_wheel_spokes(c, 28.0, _wheel_angle * DRIVER_R / 28.0, false)


func _layer_beam() -> void:
	var lamp := Vector2(LOCO_X + 380.0, GROUND_Y - 200.0 + _bob())
	var glow := float(_cur["beam"]) * (1.0 + 0.2 * sin(_time * 7.0))
	if glow > 0.005:
		var on := Color(WARM_LIGHT, minf(1.0, glow * 1.6))
		var off := Color(WARM_LIGHT, 0.0)
		_grad(PackedVector2Array([lamp + Vector2(0, -10), lamp + Vector2(560, -100), lamp + Vector2(560, 150), lamp + Vector2(0, 10)]),
			PackedColorArray([on, off, off, on]))
		_glow(lamp, 90.0, Color(WARM_LIGHT, minf(1.0, glow * 2.0)))


func _layer_loco_fx() -> void:
	_draw_loco_fx()


func _layer_front() -> void:
	_draw_smoke(false)
	_draw_sparks()
	_draw_maintenance_icon()
	_draw_weather()


## A escuridão que consome tudo atrás do trem: massa que respira na borda
## esquerda, tentáculos e pedaços do mundo sendo puxados para dentro dela.
## Avança ao acaso, chega mais perto com o trem parado e, ao sair da estação,
## escurece a tela por alguns segundos. Nunca cobre o trem.
func _layer_darkness() -> void:
	var gloom: float = _cur["gloom"]
	var depart := _dark_depart * _dark_depart * (3.0 - 2.0 * _dark_depart)
	# quase fora da tela; espia pela borda nos avanços aleatórios
	var reach := minf(-30.0 + 90.0 * gloom + 150.0 * _dark_surge + 190.0 * _dark_creep + 170.0 * depart, TENDER_X - 260.0)
	var h := _size.y
	if depart > 0.01:  # a luz do mundo baixa por um instante
		var a := 0.30 * depart
		_grad(PackedVector2Array([Vector2(-20, -20), Vector2(_size.x + 20, -20), Vector2(_size.x + 20, h + 20), Vector2(-20, h + 20)]),
			PackedColorArray([Color(DARK, a), Color(DARK, a * 0.3), Color(DARK, a * 0.3), Color(DARK, a)]))
	# sombra que se espalha à frente da massa
	var fade := reach + 260.0
	_grad(PackedVector2Array([Vector2(-20, -40), Vector2(fade, -40), Vector2(fade, h + 40), Vector2(-20, h + 40)]),
		PackedColorArray([Color(DARK, 0.6), Color(DARK, 0.0), Color(DARK, 0.0), Color(DARK, 0.6)]))
	# massa: bolhas que respiram, com uma borda fria
	var rows := 14
	var step := (h + 80.0) / rows
	var blobs: Array[Vector3] = []
	for i in rows + 1:
		var wob := sin(_time * 0.9 + i * 1.7) * 34.0 + sin(_time * 2.3 + i * 0.6) * 16.0
		blobs.append(Vector3(reach + wob - 60.0, -40.0 + i * step, 70.0 + 22.0 * sin(_time * 1.3 + i * 2.1)))
	for bl in blobs:
		_circle(Vector2(bl.x, bl.y), bl.z + 9.0, Color(DARK_RIM, 0.5))
	_rect(Rect2(-20, -40, reach - 40.0, h + 80.0), DARK)
	for bl in blobs:
		_circle(Vector2(bl.x, bl.y), bl.z, DARK)
	# tentáculos tateando à frente
	var reach_mul := 0.6 + 0.6 * _dark_surge + 0.5 * depart + 0.3 * _dark_creep
	for k in 7:
		var phase := k * 2.39
		var length := (110.0 + 90.0 * sin(_time * 0.5 + phase)) * reach_mul
		var start := Vector2(reach + sin(_time * 0.9 + k) * 20.0, h * (0.08 + k * 0.135))
		var prev := start
		for sgi in range(1, 7):
			var t := sgi / 6.0
			var pt := start + Vector2(length * t, sin(_time * 1.6 + phase + t * 4.0) * 26.0 * t + t * t * 24.0 * sin(phase))
			_line(prev, pt, DARK, lerpf(24.0, 3.0, t))
			if t < 0.8:
				_circle(pt, lerpf(12.0, 1.5, t), DARK)
			prev = pt
	# pedaços do mundo sendo puxados para dentro
	for k in 16:
		var t := fmod(_time * 0.16 + k * 0.137, 1.0)
		var pt := Vector2(reach + 30.0 + (1.0 - t) * 300.0, h * fmod(k * 0.379 + 0.1, 1.0) + sin(_time + k) * 18.0)
		_circle(pt, lerpf(2.0, 5.5, t), Color(DARK, t * 0.85))


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
		_ink_rect(plat, STONE, 3.0)
		for bx in range(0, int(PLATFORM_W), 38):   # tijolos
			_line(Vector2(x + bx, GROUND_Y - 22), Vector2(x + bx, GROUND_Y - 6), INK, 1.5)
		_line(Vector2(x, GROUND_Y - 16), Vector2(x + PLATFORM_W, GROUND_Y - 16), INK, 1.5)
		_ink_rect(Rect2(x - 6, GROUND_Y - 42, PLATFORM_W + 12, 9), STONE.lightened(0.25), 3.0)
		# postes de luz nas pontas
		for lx in [x + 24.0, x + PLATFORM_W - 30.0]:
			_ink_rect(Rect2(lx, GROUND_Y - 190, 8, 150), CHARCOAL, 3.0)
			_glow(Vector2(lx + 4, GROUND_Y - 200), 170, Color(WARM_LIGHT, 0.40))
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
				c = Color(0.82, 0.88, 0.92, a * 0.55)
			else:
				var g: float = lerpf(0.14, 0.46, 1.0 - a) + p["shade"] * 0.12
				c = Color(g, g * 1.03, g * 1.09, a * 0.85)
			var r: float = p["r"]
			var pos: Vector2 = p["pos"]
			if pass_i == 0:
				var ink := Color(INK if not steam else Color(0.45, 0.52, 0.58), a * (0.4 if steam else 0.6))
				_circle(pos, r + 3.0, ink)
				if not steam:
					_circle(pos + Vector2(r * 0.6, r * 0.2), r * 0.7 + 3.0, ink)
			else:
				_circle(pos, r, c)
				if not steam:
					_circle(pos + Vector2(r * 0.6, r * 0.2), r * 0.7, c)
					_circle(pos + Vector2(-r * 0.25, -r * 0.3), r * 0.45, Color(1, 1, 1, a * 0.10))


func _draw_sparks() -> void:
	for s in _sparks:
		var a: float = clampf(s["life"] * 1.6, 0.0, 1.0)
		_glow(s["pos"], 18.0, Color(1.0, 0.55, 0.15, a * 0.6))
		_circle(s["pos"], 3.4, Color(1.0, 0.78, 0.3, a))


## Clima em primeiro plano: cinzas, esporos, poeira, partículas de luz ou neve.
func _draw_weather() -> void:
	for pair in _blend_weights():
		var theme := SeasonThemes.get_theme(pair[0])
		var kind: String = theme["weather"]
		var alpha: float = pair[1]
		if kind == "none" or alpha <= 0.01:
			continue
		var colors: Array = theme["weather_colors"]
		# queda (px/s): negativo sobe (esporos e partículas de luz)
		var fall: float = {"petals": 50.0, "leaves": 80.0, "ash": 26.0, "spores": -16.0, "motes": -22.0, "dust": 10.0,
			"drips": 420.0, "rain": 560.0, "bubbles": -55.0, "wisps": 4.0}.get(kind, 70.0)
		var count := WEATHER_COUNT if kind in ["snow", "dust", "rain"] else WEATHER_COUNT / 2
		if floating:
			count /= 2   # janela pequena: menos partículas
		for i in count:
			var w: Dictionary = _weather[i]
			var sp: float = w["speed"]
			var ph: float = w["phase"]
			var y := fposmod(float(w["y"]) + _time * fall * sp, _size.y + 30.0) - 15.0
			var sway := sin(_time * (1.2 if kind == "snow" else 2.0) * sp + ph) * (14.0 if kind == "snow" else 30.0)
			var x := float(w["x"]) + sway
			if floating:  # espalha as partículas só no trecho que a janela mostra
				var vis := _size - _view_origin
				y = _view_origin.y + fposmod(float(w["y"]) + _time * fall * sp, vis.y + 30.0) - 15.0
				x = _view_origin.x + fposmod(float(w["x"]), vis.x + 40.0) - 20.0 + sway
			if x > _size.x + 20.0:
				continue
			var col := Color(colors[int(w["color"]) % colors.size()], alpha * 0.95)
			var sz: float = w["size"]
			var pos := Vector2(x, y)
			match kind:
				"snow":
					_circle(pos, 3.2 * sz, col)
				"spores":  # esporos boiando, com brilho fraco
					var p2 := pos + Vector2(sin(_time * 0.7 * sp + ph) * 20.0, 0)
					_glow(p2, 9.0 * sz, Color(col, 0.30 * alpha))
					_circle(p2, 1.5 * sz, Color(col, 0.9 * alpha))
				"motes":  # partículas de luz subindo devagar
					var tw := 0.5 + 0.5 * sin(_time * 2.0 * sp + ph)
					_glow(pos, 14.0 * sz, Color(col, 0.35 * tw * alpha))
					_circle(pos, 1.8 * sz, Color(col, (0.5 + 0.5 * tw) * alpha))
				"dust":  # poeira soprando com o vento
					var dx := fposmod(float(w["x"]) - _time * 420.0 * sp, _size.x + 200.0) - 100.0 + (_view_origin.x if floating else 0.0)
					var dp := Vector2(dx, pos.y)
					_line(dp, dp + Vector2(26.0 * sz, -1.5), Color(col, 0.30 * alpha), 2.0 * sz)
				"drips":  # gotas pingando do teto do túnel
					if i % 2 == 0:
						_line(pos, pos + Vector2(0, 11.0 * sz), Color(col, 0.55 * alpha), 2.0)
				"rain":  # chuva fina inclinada
					_line(pos, pos + Vector2(-6.0, 20.0) * sz, Color(col, 0.40 * alpha), 1.6)
				"bubbles":  # bolhas subindo
					_circle(pos, 4.0 * sz, Color(col, 0.30 * alpha))
					_circle(pos + Vector2(-1.3, -1.3) * sz, 1.4 * sz, Color(1, 1, 1, 0.7 * alpha))
				"wisps":  # fiapos de nuvem passando rápido
					var wx2 := fposmod(float(w["x"]) - _time * 700.0 * sp, _size.x + 600.0) - 300.0 + (_view_origin.x if floating else 0.0)
					for k in 3:
						_glow(Vector2(wx2 + k * 44.0 * sz, pos.y + sin(k * 1.3) * 6.0), 32.0 * sz, Color(col, 0.10 * alpha))
				"ash":
					if int(w["color"]) == 0:   # brasa
						_glow(pos, 12.0 * sz, Color(1.0, 0.5, 0.18, 0.45 * alpha))
						_circle(pos, 1.6 * sz, Color(1.0, 0.75, 0.4, alpha))
					else:   # fuligem
						_circle(pos, 2.2 * sz, Color(col, 0.6 * alpha))
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
	if floating:
		return
	if _speed_ratio < 0.45:
		return
	var a := (_speed_ratio - 0.45) / 0.55 * 0.15
	for i in 12:
		var y := 100.0 + i * 52.0
		var length := 120.0 + (i * 53) % 160
		var x := fmod(_size.x - fmod(_time * 2000.0 + i * 263.0, _size.x + length), _size.x + length)
		_line(Vector2(x, y), Vector2(x + length, y), Color(1, 1, 1, a), 2.5)


func _draw_celebration() -> void:
	for c in _celebration:
		var a: float = clampf(c["life"], 0.0, 1.0) * (0.7 + 0.3 * sin(float(c["rot"]) * 2.0))
		var col: Color = MOTES[int(c["color"])]
		var sz: float = c["size"]
		_glow(c["pos"], sz * 6.0, Color(col, 0.35 * a))
		_circle(c["pos"], sz, Color(col.lightened(0.4), a))


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
	_ink_rrect(win.grow(-7), 6.0, Color(0.16, 0.10, 0.07), 2.0)
	_rect(Rect2(b + Vector2(14, -122), Vector2(88, 48)), WINE_DARK, false, 3.0)
	_rect(Rect2(b + Vector2(18, -118), Vector2(80, 40)), BRASS, false, 2.0)
	var plate := Rect2(b + Vector2(30, -112), Vector2(56, 28))
	_ink_rrect(plate, 8.0, BRASS, 2.5)
	_ci.draw_string(_font, plate.position + Vector2(0, 22), "1857", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 18, WINE_DARK)

	var snow: float = _cur["snow"]
	if snow > 0.02:  # neve acumulada no teto da cabine e no alto da caldeira
		var white := Color(0.80, 0.88, 0.92, snow)
		_ink_rrect(Rect2(b + Vector2(-18, -250), Vector2(148, 14)), 7.0, white, 2.5, Color(0.45, 0.55, 0.70, snow))
		_rect(Rect2(b + Vector2(112, -190), Vector2(40, 7)), white)
		_rect(Rect2(b + Vector2(180, -190), Vector2(24, 6)), white)
		_rect(Rect2(b + Vector2(268, -272), Vector2(96, 7)), white)


## Partes vivas da locomotiva: luz da fornalha na cabine, rodas e bielas.
func _draw_loco_fx() -> void:
	var o := Vector2(LOCO_X, GROUND_Y)           # origem: base da cabine, no trilho
	var b := o + Vector2(0, _bob())              # partes presas ao corpo balançam junto
	var flicker := 0.85 + 0.15 * sin(_time * 11.0) * sin(_time * 3.7)
	# luz da fornalha dentro da cabine (mais forte com a caldeira atiçada)
	var inner := Rect2(b + Vector2(27, -193), Vector2(56, 52))
	_rect(inner, Color(1.0, 0.62, 0.25, (0.40 + 0.5 * _stoke) * flicker))
	_glow(inner.get_center(), 80.0 + 50.0 * _stoke, Color(1.0, 0.58, 0.22, (0.22 + 0.4 * _stoke) * flicker))

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
