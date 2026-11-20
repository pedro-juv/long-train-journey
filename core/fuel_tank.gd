class_name FuelTank
extends RefCounted
## FuelTank — o reservatório de combustível do trem.
##
## É o tanque da locomotiva: capacidade limitada, abastecido automaticamente
## a partir do estoque (CoalStock) pelo GameController. O trem consome daqui.

var current: float = 0.0
var capacity: float = 0.0


func _init(start_coal: float, start_capacity: float) -> void:
	capacity = start_capacity
	current = clampf(start_coal, 0.0, capacity)


## Adiciona carvão respeitando a capacidade. Retorna quanto NÃO coube.
func add(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var space := capacity - current
	var accepted := minf(amount, space)
	current += accepted
	return amount - accepted


## Espaço livre no reservatório.
func free_space() -> float:
	return capacity - current


## Tenta consumir. Só consome se houver o suficiente; retorna se conseguiu.
func try_consume(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current < amount:
		return false
	current -= amount
	return true


func can_afford(amount: float) -> bool:
	return current >= amount


func is_full() -> bool:
	return current >= capacity


func set_capacity(new_capacity: float) -> void:
	capacity = maxf(0.0, new_capacity)
	current = minf(current, capacity)
