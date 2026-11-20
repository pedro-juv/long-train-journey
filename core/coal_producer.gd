class_name CoalProducer
extends RefCounted
## CoalProducer — um produtor de carvão (Foguista, Carvoaria, Mina...).
##
## Unidade única com níveis (nível 0 = não comprado). Criado a partir dos dados
## do Balance. Produção = nível * produção_por_nível * marcos * equipamento.
## O multiplicador global (estações) é aplicado fora, pelo GameState.

var id: String
var display_name: String
var level: int = 0
var unlock_station: int = -1

## Multiplicador vindo de melhorias deste produtor (equipamentos).
var upgrade_multiplier: float = 1.0

var _output_per_level: float
var _base_cost: float
var _cost_growth: float
var _milestone_levels: Array[int]
var _milestone_multiplier: float


func _init(data: Dictionary, cost_growth: float, milestone_levels: Array[int], milestone_multiplier: float) -> void:
	id = data["id"]
	display_name = data["name"]
	unlock_station = int(data.get("unlock_station", -1))
	_output_per_level = float(data["output_per_level"])
	_base_cost = float(data["base_cost"])
	_cost_growth = cost_growth
	_milestone_levels = milestone_levels
	_milestone_multiplier = milestone_multiplier


func is_owned() -> bool:
	return level > 0


## Produção (carvão/s) no nível atual, sem o multiplicador global.
func output_per_second() -> float:
	return output_at_level(level)


## Produção que teria no nível `lvl` (para mostrar o próximo nível na loja).
func output_at_level(lvl: int) -> float:
	return lvl * _output_per_level * milestone_multiplier_at(lvl) * upgrade_multiplier


## Multiplicador dos marcos atingidos no nível `lvl`.
func milestone_multiplier_at(lvl: int) -> float:
	var mult := 1.0
	for m in _milestone_levels:
		if lvl >= m:
			mult *= _milestone_multiplier
	return mult


## Próximo marco ainda não atingido (-1 se todos foram atingidos).
func next_milestone() -> int:
	for m in _milestone_levels:
		if level < m:
			return m
	return -1


func milestone_value() -> float:
	return _milestone_multiplier


## Custo para ir do nível atual para o próximo.
func next_level_cost() -> float:
	return roundf(_base_cost * pow(_cost_growth, level))


func produce(delta: float) -> float:
	return output_per_second() * delta


func level_up() -> void:
	level += 1
