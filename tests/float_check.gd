extends Node
## Verificação real do modo trem flutuante (precisa de janela, não roda headless).
## Rodar: godot --path . res://tests/float_check.tscn -- <pasta_de_saida>
## Liga o modo, confere a janela e captura a TELA do sistema (o que o Windows
## compõe de verdade, com o desktop atrás) e o quadro do jogo (com alfa).

var _main: Node
var _fails := 0


func _check(cond: bool, msg: String) -> void:
	print("  OK   " if cond else "  FAIL ", msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(out: String, file: String) -> void:
	var win := get_window()
	var screen := DisplayServer.screen_get_image(win.current_screen)
	if screen:
		var origin := DisplayServer.screen_get_position(win.current_screen)
		var r := Rect2i(win.position - origin, win.size).grow(40).intersection(Rect2i(Vector2i.ZERO, screen.get_size()))
		screen.get_region(r).save_png(out.path_join("tela_" + file))
	get_viewport().get_texture().get_image().save_png(out.path_join("quadro_" + file))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://float_check"
	DirAccess.make_dir_recursive_absolute(out)
	# não mexe no save do jogador: backup antes, restaura no fim
	var save_path := ProjectSettings.globalize_path("user://save.json")
	var backup := ProjectSettings.globalize_path("user://save_backup_float.json")
	var had_save := FileAccess.file_exists(save_path)
	if had_save:
		DirAccess.copy_absolute(save_path, backup)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames(30)
	var win := get_window()
	var normal_size := win.size
	var normal_pos := win.position
	var fm: FloatMode = _main.get_node("FloatMode")
	var g = _main.get_node("Game")
	var dist := float(g.state.train.distance_m)
	fm.enter()
	await _frames(90)
	print("janela: ", win.size, " em ", win.position, "  tela útil: ", DisplayServer.screen_get_usable_rect(win.current_screen))
	_check(win.borderless and win.always_on_top and win.transparent and win.transparent_bg, "sem borda, sempre no topo, transparente")
	_check(win.size == FloatMode.WINDOW_SIZE, "tamanho da janelinha %s" % win.size)
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	_check(usable.encloses(Rect2i(win.position, win.size)), "janelinha dentro da área útil (canto inferior direito)")
	_check(float(g.state.train.distance_m) > dist, "trem andando")
	var img := get_viewport().get_texture().get_image()
	_check(img.get_pixel(5, 5).a < 0.01, "canto de cima transparente (alfa %.2f)" % img.get_pixel(5, 5).a)
	_check(img.get_pixel(int(img.get_width() * 0.8), int(img.get_height() * 0.6)).a > 0.9, "trem opaco")
	_check(win.mouse_passthrough_polygon.size() == 4, "área de clique só no trem e na barra")
	_shot(out, "flutuante.png")
	fm.toggle_shop()
	await _frames(40)
	_check(win.size.y == FloatMode.WINDOW_SIZE.y + FloatMode.SHOP_HEIGHT, "janela cresce para a loja")
	_shot(out, "loja.png")
	fm.toggle_shop()
	await _frames(10)
	fm.exit()
	await _frames(40)
	_check(not win.borderless and not win.always_on_top and not win.transparent_bg, "janela normal restaurada")
	_check(win.size == normal_size and win.position == normal_pos, "mesmo tamanho e lugar de antes (%s em %s)" % [win.size, win.position])
	_shot(out, "normal.png")
	remove_child(_main)
	_main.free()
	if had_save:
		DirAccess.copy_absolute(backup, save_path)
		DirAccess.remove_absolute(backup)
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	print("== %d falha(s) ==" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
