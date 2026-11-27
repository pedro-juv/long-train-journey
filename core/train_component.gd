class_name TrainComponent
extends RefCounted
## TrainComponent — uma peça do trem (rodas, caldeira, pistões...).
##
## Criado a partir dos dados do Balance. Guarda integridade (0..1), nível de
## reforço, material atual e para qual material a manutenção automática foi
## comprada. Não decide nada sobre carvão nem paradas: isso é do GameState.

enum Wear { DISTANCE, TIME }

var id: String
var display_name: String
var wear_kind: Wear
var base_life: float
var unlock_station: int
var reinforce_base_cost: float
var materials: Array = []

var integrity: float = 1.0
var level: int = 0
var material_index: int = 0
## id do material para o qual a manutenção automática foi comprada ("" = nenhum).
var auto_material: String = ""
## Quantas vezes a manutenção automática consertou esta peça (só informativo).
var auto_repairs: int = 0
## Quantas vezes a peça quebrou (só informativo).
var failures: int = 0

## Desgaste extra (regra da região) ou menor (melhorias); 1 = normal.
var wear_multiplier: float = 1.0

var _life_multiplier: float
var _cost_growth: float


func _init(data: Dictionary, life_multiplier: float, cost_growth: float) -> void:
	id = data["id"]
	display_name = data["name"]
	wear_kind = Wear.DISTANCE if data["wear"] == "distance" else Wear.TIME
	base_life = float(data["life"])
	unlock_station = int(data["unlock_station"])
	reinforce_base_cost = float(data["reinforce_cost"])
	materials = data["materials"]
	_life_multiplier = life_multiplier
	_cost_growth = cost_growth


## Vida atual (metros ou segundos), já com o reforço.
func life() -> float:
	return base_life * pow(_life_multiplier, level) * float(material().get("life_mult", 1.0))


## Quanto de integridade se perde ao andar `meters` em `seconds` de movimento.
func wear_amount(meters: float, seconds: float) -> float:
	return (meters if wear_kind == Wear.DISTANCE else seconds) / life() * wear_multiplier


## Integridade perdida por segundo andando a `speed_mps` (para o offline).
func wear_rate(speed_mps: float) -> float:
	return (speed_mps if wear_kind == Wear.DISTANCE else 1.0) / life() * wear_multiplier


func reinforce_cost() -> float:
	return roundf(reinforce_base_cost * pow(_cost_growth, level))


func material() -> Dictionary:
	return materials[material_index]


## Troca para o material de id `material_id` (se existir nesta peça).
func set_material(material_id: String) -> void:
	for i in materials.size():
		if materials[i]["id"] == material_id:
			material_index = i


func material_name() -> String:
	return material()["name"]


## A manutenção automática vale só para o material em que foi comprada.
## Trocar de material (fases futuras) exige comprar de novo.
func has_auto() -> bool:
	return auto_material != "" and auto_material == material()["id"]


func auto_cost() -> float:
	return float(material()["auto_cost"])
