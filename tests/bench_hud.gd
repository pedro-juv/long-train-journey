extends "res://scenes/hud.gd"
## Só para o benchmark: mede o tempo do _process da HUD.

var bench_process_usec: int = 0


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	super._process(delta)
	bench_process_usec += Time.get_ticks_usec() - t0
