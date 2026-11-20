class_name GameState
extends RefCounted
## GameState — toda a economia e a viagem do jogo, sem interface.
##
## Recebe a configuração (o Balance) no construtor, então funciona tanto no
## jogo quanto nos testes automatizados. Não emite sinais: devolve o que
## aconteceu e o GameController repassa para a interface pelo EventBus.

const SAVE_VERSION := 4

var config  # o Balance (ou um objeto com os mesmos campos)

var stock: CoalStock
var tank: FuelTank
var producers: Array[CoalProducer] = []
var upgrades: Upgrades
var train: TrainMovement
var route: StationTracker
var maintenance: Maintenance

## Multiplicadores derivados das melhorias compradas.
var global_multiplier: float = 1.0
var click_multiplier: float = 1.0

var _producer_by_id: Dictionary = {}


func _init(p_config) -> void:
	config = p_config
	stock = CoalStock.new(config.initial_stock)
	tank = FuelTank.new(config.tank_capacity, config.tank_capacity)  # começa cheio
	for data in config.producers:
		var p := CoalProducer.new(data, config.producer_cost_growth, config.milestone_levels, config.milestone_multiplier)
		producers.append(p)
		_producer_by_id[p.id] = p
	upgrades = Upgrades.new(config.upgrades)
	train = TrainMovement.new(config.train_base_speed, config.train_speed_factor, config.train_speed_exponent, config.coal_per_meter)
	route = StationTracker.new(config.stations)
	maintenance = Maintenance.new(config.components, config.reinforce_life_multiplier, config.reinforce_cost_growth,
		config.maintenance_seconds, config.repair_seconds_of_production, config.auto_repair_threshold)
	_recalculate_multipliers()
	train.target_speed = train.speed_for_production(total_production())


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func producer(id: String) -> CoalProducer:
	return _producer_by_id.get(id)


## Produção total (carvão/s) com todos os multiplicadores.
func total_production() -> float:
	var total := 0.0
	for p in producers:
		total += p.output_per_second()
	return total * global_multiplier


## Produção de um produtor com o multiplicador global (para a loja).
func producer_production(id: String) -> float:
	return producer(id).output_per_second() * global_multiplier


func click_value() -> float:
	return config.coal_per_click * click_multiplier


func is_producer_unlocked(id: String) -> bool:
	var p := producer(id)
	return p.unlock_station < 0 or route.is_reached(p.unlock_station)


func can_buy_producer(id: String) -> bool:
	return is_producer_unlocked(id) and stock.can_afford(producer(id).next_level_cost())


## Produção total se o produtor `id` subir um nível (para a loja).
func production_after_level_up(id: String) -> float:
	var p := producer(id)
	return total_production() + (p.output_at_level(p.level + 1) - p.output_per_second()) * global_multiplier


## A condição "requires" da melhoria foi cumprida? (aparece na loja)
func is_upgrade_available(id: String) -> bool:
	var entry := upgrades.get_entry(id)
	if entry.is_empty() or entry["purchased"]:
		return false
	var req: Dictionary = entry.get("requires", {})
	if req.has("producer") and not producer(req["producer"]).is_owned():
		return false
	if req.has("upgrade") and not upgrades.is_purchased(req["upgrade"]):
		return false
	if req.has("station") and not route.is_reached(int(req["station"])):
		return false
	return true


func can_buy_upgrade(id: String) -> bool:
	return is_upgrade_available(id) and stock.can_afford(upgrades.cost(id))


## Ids das melhorias que aparecem na loja agora, na ordem do Balance.
func available_upgrade_ids() -> Array[String]:
	var result: Array[String] = []
	for id in upgrades.ids():
		if is_upgrade_available(id):
			result.append(id)
	return result


func component(id: String) -> TrainComponent:
	return maintenance.component(id)


func is_component_active(id: String) -> bool:
	return maintenance.is_active(component(id), route)


## A aba "Trem" aparece quando a primeira peça é liberada.
func has_active_components() -> bool:
	return not maintenance.active_components(route).is_empty()


func repair_cost(id: String) -> float:
	return maintenance.repair_cost(component(id), total_production())


func can_repair(id: String) -> bool:
	var c := component(id)
	return is_component_active(id) and c.integrity < 1.0 and stock.can_afford(repair_cost(id))


func can_reinforce(id: String) -> bool:
	return is_component_active(id) and stock.can_afford(component(id).reinforce_cost())


func is_auto_maintenance_unlocked() -> bool:
	return route.is_reached(config.auto_maintenance_unlock_station)


func is_auto_available(id: String) -> bool:
	return is_component_active(id) and is_auto_maintenance_unlocked() and not component(id).has_auto()


func can_buy_auto(id: String) -> bool:
	return is_auto_available(id) and stock.can_afford(component(id).auto_cost())


# ---------------------------------------------------------------------------
# Ações do jogador
# ---------------------------------------------------------------------------

func click() -> void:
	stock.add(click_value())


func buy_producer(id: String) -> bool:
	if not is_producer_unlocked(id):
		return false
	var p := producer(id)
	if not stock.try_spend(p.next_level_cost()):
		return false
	p.level_up()
	return true


func buy_upgrade(id: String) -> bool:
	if not is_upgrade_available(id):
		return false
	if not stock.try_spend(upgrades.cost(id)):
		return false
	upgrades.mark_purchased(id)
	_recalculate_multipliers()
	return true


## Reparo preventivo: paga e leva a peça a 100%.
func repair_component(id: String) -> bool:
	if not can_repair(id):
		return false
	stock.try_spend(repair_cost(id))
	component(id).integrity = 1.0
	return true


func reinforce_component(id: String) -> bool:
	if not can_reinforce(id):
		return false
	var c := component(id)
	stock.try_spend(c.reinforce_cost())
	c.level += 1
	_recalculate_multipliers()
	return true


## Bônus total de velocidade dos reforços (0.12 = +12%).
func reinforce_speed_bonus() -> float:
	var levels := 0
	for c in maintenance.components:
		levels += c.level
	return levels * float(config.reinforce_speed_bonus)


## Compra a manutenção automática para o material ATUAL da peça.
func buy_auto_maintenance(id: String) -> bool:
	if not can_buy_auto(id):
		return false
	var c := component(id)
	stock.try_spend(c.auto_cost())
	c.auto_material = c.material()["id"]
	return true


# ---------------------------------------------------------------------------
# Simulação
# ---------------------------------------------------------------------------

## Avança `delta` segundos. Retorna:
## { "state_changed": bool, "stations": [índices], "failed": [ids],
##   "auto": [ids], "maintenance_done": bool }
func tick(delta: float) -> Dictionary:
	var production := total_production()
	stock.add(production * delta)  # a produção continua mesmo em manutenção
	tank.add(stock.take_up_to(tank.free_space()))  # abastecimento automático
	var result := {"state_changed": false, "stations": [] as Array[int], "failed": [] as Array[String],
		"auto": [] as Array[String], "maintenance_done": false}

	if maintenance.is_stopped():
		result["state_changed"] = train.hold_for_maintenance(production)
		result["maintenance_done"] = maintenance.tick_stop(delta)
		return result

	var before := train.distance_m
	result["state_changed"] = train.tick(delta, tank, production)
	var meters := train.distance_m - before
	var moving_seconds := delta if meters > 0.0 else 0.0
	var wear := maintenance.wear(meters, moving_seconds, route, stock, production)
	result["failed"] = wear["failed"]
	result["auto"] = wear["auto"]
	if maintenance.is_stopped():
		result["state_changed"] = train.hold_for_maintenance(production) or result["state_changed"]
	result["stations"] = route.update(train.distance_m)
	return result


## Aplica `elapsed_seconds` de progresso offline. Retorna o resumo:
## { "seconds", "stock_delta", "distance", "stations": [índices], "failures",
##   "downtime", "auto_repairs", "auto_cost", "waiting_at_station" }.
func apply_offline(elapsed_seconds: float) -> Dictionary:
	var seconds := OfflineProgress.clamp_elapsed(elapsed_seconds, config.offline_max_seconds)
	var effective: float = seconds * config.offline_efficiency
	var stock_before := stock.amount
	var fuel := stock.amount + tank.current

	# Caminho B: no máximo até a próxima estação.
	var max_distance := INF
	if config.offline_stop_at_next_station and not route.is_complete():
		max_distance = maxf(0.0, route.target_distance(route.reached_count) - train.distance_m)

	var result := OfflineProgress.simulate(effective, total_production(), fuel, train, maintenance, route, max_distance)

	var total_fuel := maxf(0.0, fuel + float(result["coal_delta"]))
	tank.current = minf(tank.capacity, total_fuel)
	stock.amount = total_fuel - tank.current
	var distance := float(result["distance"])
	if is_finite(max_distance) and distance >= max_distance - 0.001:
		distance = max_distance  # chega exatamente na estação
	train.distance_m += distance
	var reached := route.update(train.distance_m)
	return {
		"seconds": seconds,
		"stock_delta": stock.amount - stock_before,
		"distance": distance,
		"stations": reached,
		"failures": result["failures"],
		"downtime": result["downtime"],
		"auto_repairs": result["auto_repairs"],
		"auto_cost": result["auto_cost"],
		"waiting_at_station": result["waiting_at_station"],
	}


# ---------------------------------------------------------------------------
# Efeitos das melhorias
# ---------------------------------------------------------------------------

## Recalcula todos os multiplicadores a partir das melhorias compradas.
## (Recalcular do zero evita erro acumulado e simplifica o carregamento.)
func _recalculate_multipliers() -> void:
	global_multiplier = 1.0
	click_multiplier = 1.0
	maintenance.time_multiplier = 1.0
	train.speed_multiplier = 1.0 + reinforce_speed_bonus()
	for p in producers:
		p.upgrade_multiplier = 1.0
	for id in upgrades.purchased_ids():
		var entry := upgrades.get_entry(id)
		var value := float(entry["value"])
		match entry["effect"]:
			"global_mult":
				global_multiplier *= value
			"click_mult":
				click_multiplier *= value
			"maintenance_time_mult":
				maintenance.time_multiplier *= value
			"producer_mult":
				var target := producer(entry["target"])
				if target:
					target.upgrade_multiplier *= value
			_:
				push_warning("GameState: efeito desconhecido '%s' em %s" % [entry["effect"], id])


# ---------------------------------------------------------------------------
# Salvamento
# ---------------------------------------------------------------------------

func to_save(saved_at_unix: float) -> Dictionary:
	var levels := {}
	for p in producers:
		levels[p.id] = p.level
	var comps := {}
	for c in maintenance.components:
		comps[c.id] = {"integrity": c.integrity, "level": c.level, "material": c.material()["id"],
			"auto": c.auto_material, "auto_repairs": c.auto_repairs, "failures": c.failures}
	return {
		"save_version": SAVE_VERSION,
		"saved_at": saved_at_unix,
		"stock": stock.amount,
		"tank": tank.current,
		"producers": levels,
		"upgrades_purchased": upgrades.purchased_ids(),
		"distance_m": train.distance_m,
		"components": comps,
		"maintenance_left": maintenance.stop_left,
		"maintenance_component": maintenance.stop_component_id,
	}


## Carrega um save (v1 a v4). Saves sem componentes começam com tudo a 100%. As estações alcançadas são recalculadas
## pela distância, sem disparar eventos.
func load_save(data: Dictionary) -> void:
	var version := int(data.get("save_version", 1))
	train.distance_m = maxf(0.0, float(data.get("distance_m", 0.0)))
	route.update(train.distance_m)

	if version >= 3:
		var levels: Dictionary = data.get("producers", {})
		for id in levels:
			if producer(id):
				producer(id).level = maxi(0, int(levels[id]))
		for id in data.get("upgrades_purchased", []):
			if upgrades.has(id):
				upgrades.mark_purchased(id)
		stock.amount = maxf(0.0, float(data.get("stock", 0.0)))
		tank.current = clampf(float(data.get("tank", tank.capacity)), 0.0, tank.capacity)
	else:
		# Fase 0: só existia o Foguista.
		producer("foguista").level = maxi(0, int(data.get("producer_level", 0)))
		# v2: "Caldeira reforçada" (+50%) era "station_production"; hoje é "station_0".
		if "station_production" in data.get("upgrades_purchased", []):
			upgrades.mark_purchased("station_0")
		if version == 2:
			stock.amount = maxf(0.0, float(data.get("stock", 0.0)))
			tank.current = clampf(float(data.get("tank", tank.capacity)), 0.0, tank.capacity)
		else:
			stock.amount = maxf(0.0, float(data.get("coal", 0.0)))
			tank.current = tank.capacity

	if version >= 4:
		var saved: Dictionary = data.get("components", {})
		for id in saved:
			var c := component(id)
			if c == null:
				continue
			var d: Dictionary = saved[id]
			c.integrity = clampf(float(d.get("integrity", 1.0)), 0.0, 1.0)
			c.level = maxi(0, int(d.get("level", 0)))
			for i in c.materials.size():
				if c.materials[i]["id"] == d.get("material", ""):
					c.material_index = i
			c.auto_material = str(d.get("auto", ""))
			c.auto_repairs = int(d.get("auto_repairs", 0))
			c.failures = int(d.get("failures", 0))
		maintenance.stop_left = maxf(0.0, float(data.get("maintenance_left", 0.0)))
		maintenance.stop_component_id = str(data.get("maintenance_component", ""))

	_recalculate_multipliers()
	train.target_speed = train.speed_for_production(total_production())
