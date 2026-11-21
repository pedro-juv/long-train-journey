extends "res://scenes/train_view.gd"
## Só para o benchmark: mede o _process do cenário. O tempo de desenho de cada
## camada vem de profile_layers / layer_usec (na própria TrainView).

var bench_process_usec: int = 0


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	super._process(delta)
	bench_process_usec += Time.get_ticks_usec() - t0
