class_name Maintenance
extends RefCounted
## Maintenance — desgaste, falhas e paradas para manutenção.
##
## Regras (Fase 1B):
## - Componentes só desgastam depois de liberados (estação) e só com o trem
##   andando: por metro (distance) ou por segundo em movimento (time).
## - Peça a 0%: o trem para `maintenance_seconds` (com o Kit, menos), a peça
##   volta a 100% e a viagem segue. Sem custo em carvão. Falhas durante uma
##   parada somam o tempo delas à parada.
## - Manutenção automática (comprada por material): ao chegar no limite, a peça
##   é consertada sem parar, pagando o custo normal de reparo. Sem carvão,
##   acontece a falha normal.

var components: Array[TrainComponent] = []
## Segundos que faltam para terminar a parada atual (0 = trem livre).
var stop_left: float = 0.0
## Peça que causou a parada atual (para a interface).
var stop_component_id: String = ""
## Multiplicador do tempo de parada (Kit de ferramentas).
var time_multiplier: float = 1.0

var _by_id: Dictionary = {}
var _base_seconds: float
var _repair_seconds: float
var _auto_threshold: float


func _init(component_data: Array, life_mult: float, cost_growth: float, base_seconds: float, repair_seconds: float, auto_threshold: float) -> void:
	for data in component_data:
		var c := TrainComponent.new(data, life_mult, cost_growth)
		components.append(c)
		_by_id[c.id] = c
	_base_seconds = base_seconds
	_repair_seconds = repair_seconds
	_auto_threshold = auto_threshold


func component(id: String) -> TrainComponent:
	return _by_id.get(id)


func is_active(c: TrainComponent, route: StationTracker) -> bool:
	return route.is_reached(c.unlock_station)


func active_components(route: StationTracker) -> Array[TrainComponent]:
	var result: Array[TrainComponent] = []
	for c in components:
		if is_active(c, route):
			result.append(c)
	return result


func is_stopped() -> bool:
	return stop_left > 0.0


## Duração de uma parada agora (com Kit de ferramentas, se houver).
func stop_seconds() -> float:
	return _base_seconds * time_multiplier


## Custo para levar a peça de volta a 100%.
func repair_cost(c: TrainComponent, production: float) -> float:
	return roundf(_repair_seconds * production * (1.0 - c.integrity))


## Custo de um conserto da manutenção automática (do limite até 100%).
func auto_repair_cost(production: float) -> float:
	return roundf(_repair_seconds * production * (1.0 - _auto_threshold))


func auto_threshold() -> float:
	return _auto_threshold


## Avança a parada. Retorna true no tick em que ela termina.
func tick_stop(delta: float) -> bool:
	if stop_left <= 0.0:
		return false
	stop_left -= delta
	if stop_left <= 0.0:
		stop_left = 0.0
		stop_component_id = ""
		return true
	return false


## Desgasta as peças ativas pelo trecho andado. Paga consertos automáticos
## com `stock`. Retorna { "failed": [ids], "auto": [ids] }.
func wear(meters: float, seconds: float, route: StationTracker, stock: CoalStock, production: float) -> Dictionary:
	var failed: Array[String] = []
	var auto: Array[String] = []
	if meters <= 0.0:
		return {"failed": failed, "auto": auto}
	for c in active_components(route):
		c.integrity -= c.wear_amount(meters, seconds)
		if c.has_auto() and c.integrity <= _auto_threshold and stock.try_spend(repair_cost(c, production)):
			c.integrity = 1.0
			c.auto_repairs += 1
			auto.append(c.id)
		elif c.integrity <= 0.0:
			fail(c)
			failed.append(c.id)
	return {"failed": failed, "auto": auto}


## Quebra a peça: volta a 100% e soma uma parada.
func fail(c: TrainComponent) -> void:
	c.integrity = 1.0
	c.failures += 1
	if stop_left <= 0.0:
		stop_component_id = c.id
	stop_left += stop_seconds()
