class_name Upgrades
extends RefCounted
## Upgrades — registro das melhorias de compra única.
##
## Cada melhoria vem dos dados do Balance (id, name, cost, effect, target,
## value, requires). Este arquivo só guarda o estado (comprada ou não) e
## responde perguntas; quem decide se a condição "requires" foi cumprida e
## quem aplica o efeito é o GameState.

## id -> dados do Balance + "purchased": bool. Mantém a ordem de declaração.
var _entries: Dictionary = {}
var _order: Array[String] = []


func _init(upgrade_data: Array[Dictionary]) -> void:
	for data in upgrade_data:
		var entry := data.duplicate(true)
		entry["purchased"] = false
		_entries[entry["id"]] = entry
		_order.append(entry["id"])


func has(id: String) -> bool:
	return _entries.has(id)


func ids() -> Array[String]:
	return _order


func get_entry(id: String) -> Dictionary:
	return _entries.get(id, {})


func cost(id: String) -> float:
	return float(_entries[id]["cost"])


func is_purchased(id: String) -> bool:
	return bool(_entries[id]["purchased"])


func mark_purchased(id: String) -> void:
	_entries[id]["purchased"] = true


## Lista de ids compradas (para salvar).
func purchased_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _order:
		if _entries[id]["purchased"]:
			result.append(id)
	return result
