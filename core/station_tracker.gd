class_name StationTracker
extends RefCounted
## StationTracker — a rota de estações (lista contínua).
##
## Cada estação tem um trecho (metros desde a anterior). A distância total do
## trem decide quantas foram alcançadas; nada disso depende de animação.

## Lista de { "name": String, "length": float }.
var stations: Array[Dictionary] = []

## Quantas estações já foram alcançadas (0 = nenhuma).
var reached_count: int = 0

## Distância total acumulada até cada estação.
var _targets: Array[float] = []


func _init(station_data: Array[Dictionary]) -> void:
	stations = station_data
	var total := 0.0
	for s in stations:
		total += float(s["length"])
		_targets.append(total)


func station_count() -> int:
	return stations.size()


func is_complete() -> bool:
	return reached_count >= stations.size()


func is_reached(index: int) -> bool:
	return index < reached_count


## Distância total (m) em que fica a estação `index`.
func target_distance(index: int) -> float:
	return _targets[index]


## Nome da próxima estação ("" se a rota acabou).
func next_station_name() -> String:
	if is_complete():
		return ""
	return stations[reached_count]["name"]


func station_name(index: int) -> String:
	return stations[index]["name"]


## Início do trecho atual (distância da última estação alcançada).
func segment_start() -> float:
	return 0.0 if reached_count == 0 else _targets[reached_count - 1]


## Progresso de 0 a 1 dentro do trecho atual.
func progress(distance_m: float) -> float:
	if is_complete():
		return 1.0
	var start := segment_start()
	var length := _targets[reached_count] - start
	return clampf((distance_m - start) / length, 0.0, 1.0)


## Atualiza com a distância atual. Retorna os índices das estações alcançadas
## AGORA (pode ser mais de uma, por exemplo depois do progresso offline).
func update(distance_m: float) -> Array[int]:
	var newly: Array[int] = []
	while reached_count < _targets.size() and distance_m >= _targets[reached_count]:
		newly.append(reached_count)
		reached_count += 1
	return newly
