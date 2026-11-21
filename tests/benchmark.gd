extends Node
## Benchmark de desempenho (com janela e renderização).
## Rodar: godot --path . res://tests/benchmark.tscn
## Mede, por quadro: tempo total, _draw do cenário, _process do cenário,
## _process da HUD e chamadas de desenho da GPU. Sem V-Sync.

const FRAMES := 600
const WARMUP := 60

var _main: Node
var _view: Node
var _hud: Node
var _frame := 0
var _t_start := 0
var _cpu_process := 0.0
var _draw_calls := 0.0
var _primitives := 0.0


func _swap_script(node: Node, script_path: String) -> void:
	var saved := {}
	for prop in node.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["usage"] & PROPERTY_USAGE_STORAGE:
			saved[prop["name"]] = node.get(prop["name"])
	node.set_script(load(script_path))
	for k in saved:
		node.set(k, saved[k])


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	SaveManager.delete_save()
	_main = load("res://scenes/main.tscn").instantiate()
	_view = _main.get_node("TrainView")
	_hud = _main.get_node("HUD")
	_swap_script(_view, "res://tests/bench_view.gd")
	_swap_script(_hud, "res://tests/bench_hud.gd")
	add_child(_main)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == WARMUP:
		_t_start = Time.get_ticks_usec()
		_view.profile_layers = true
		_view.layer_usec.clear()
		_view.bench_process_usec = 0
		_hud.bench_process_usec = 0
	elif _frame > WARMUP:
		_cpu_process += Performance.get_monitor(Performance.TIME_PROCESS)
		_draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if _frame == WARMUP + FRAMES:
		var total_ms := (Time.get_ticks_usec() - _t_start) / 1000.0
		var n := float(FRAMES)
		print("== Benchmark (%d quadros, sem V-Sync) ==" % FRAMES)
		print("  FPS médio:                 %.0f" % (n / (total_ms / 1000.0)))
		print("  tempo por quadro:          %.2f ms" % (total_ms / n))
		var draw_total := 0
		for k in _view.layer_usec:
			draw_total += _view.layer_usec[k]
		print("  desenho do cenário:        %.3f ms" % (draw_total / 1000.0 / n))
		print("  _process do cenário:       %.3f ms" % (_view.bench_process_usec / 1000.0 / n))
		print("  _process da HUD:           %.3f ms" % (_hud.bench_process_usec / 1000.0 / n))
		print("  scripts (TIME_PROCESS):    %.2f ms" % (_cpu_process / n * 1000.0))
		print("  chamadas de desenho GPU:   %.0f por quadro" % (_draw_calls / n))
		print("  primitivas:                %.0f por quadro" % (_primitives / n))
		var parts: Array = _view.layer_usec.keys()
		parts.sort_custom(func(a, b): return _view.layer_usec[a] > _view.layer_usec[b])
		print("  -- desenho por camada (média por quadro) --")
		for k in parts.slice(0, 10):
			print("    %-14s %.3f ms" % [k, _view.layer_usec[k] / 1000.0 / n])
		SaveManager.delete_save()
		get_tree().quit()
