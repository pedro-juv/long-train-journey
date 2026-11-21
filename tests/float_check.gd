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
	# o caso do bug: menu aberto -> trem flutuante pelo menu
	var menu = _main.get_node("OptionsMenu")
	var board: Control = menu.get_node("%Board")
	menu.open()
	await get_tree().create_timer(1.6, true).timeout
	var board_home := board.position
	# sem tamanho salvo: começa no tamanho padrão
	var cfg_path := ProjectSettings.globalize_path("user://settings.cfg")
	var cfg_backup := ProjectSettings.globalize_path("user://settings_backup_float.cfg")
	var had_cfg := FileAccess.file_exists(cfg_path)
	if had_cfg:
		DirAccess.copy_absolute(cfg_path, cfg_backup)
		var cfg := ConfigFile.new()
		cfg.load(cfg_path)
		if cfg.has_section("float"):
			cfg.erase_section("float")
		cfg.save(cfg_path)
	menu.get_node("Root/Board/Margin/VBox/FloatButton").pressed.emit()
	await _frames(90)
	print("janela: ", win.size, " em ", win.position, "  tela útil: ", DisplayServer.screen_get_usable_rect(win.current_screen))
	_check(win.borderless and win.always_on_top and win.transparent and win.transparent_bg, "sem borda, sempre no topo, transparente")
	_check(win.size == FloatMode.WINDOW_SIZE, "tamanho da janelinha %s" % win.size)
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	_check(usable.encloses(Rect2i(win.position, win.size)), "janelinha dentro da área útil (canto inferior direito)")
	# (se o save estiver parado numa estação, espera a partida: 5 s)
	for i in 30:
		if float(g.state.train.distance_m) > dist:
			break
		await get_tree().create_timer(0.25).timeout
	_check(float(g.state.train.distance_m) > dist, "trem andando")
	var img := get_viewport().get_texture().get_image()
	var px := img.get_pixel(int(img.get_width() * 0.3), 30)
	_check(px.a < 0.01, "céu transparente (alfa %.2f)" % px.a)
	_check(img.get_pixel(int(img.get_width() * 0.8), int(img.get_height() * 0.6)).a > 0.9, "trem opaco")
	_check(win.mouse_passthrough_polygon.size() == 6, "área de clique só no trem, na barra e na alça")
	_shot(out, "flutuante.png")
	# redimensionar: o trem acompanha a altura
	var zoom_before: float = _main.get_node("TrainView").camera_zoom
	win.size = Vector2i(380, 180)
	win.position += Vector2i(140, 70)
	await _frames(30)
	_check(_main.get_node("TrainView").camera_zoom < zoom_before - 0.05, "janela menor: trem menor (zoom %.2f -> %.2f)" % [zoom_before, _main.get_node("TrainView").camera_zoom])
	_shot(out, "pequena.png")
	win.size = Vector2i(900, 420)
	win.position -= Vector2i(520, 240)
	await _frames(30)
	_check(_main.get_node("TrainView").camera_zoom > zoom_before + 0.1, "janela maior: trem maior (zoom %.2f)" % _main.get_node("TrainView").camera_zoom)
	_shot(out, "grande.png")
	win.size = FloatMode.WINDOW_SIZE
	win.position = DisplayServer.screen_get_usable_rect(win.current_screen).end - FloatMode.WINDOW_SIZE - Vector2i(12, 12)
	await _frames(20)
	fm.toggle_shop()
	await _frames(40)
	_check(win.size.y == FloatMode.WINDOW_SIZE.y + FloatMode.SHOP_HEIGHT, "janela cresce para a loja (%s em %s)" % [win.size, win.position])
	_shot(out, "loja.png")
	fm.toggle_shop()
	await _frames(10)
	fm.exit()
	await _frames(40)
	_check(not win.borderless and not win.always_on_top and not win.transparent_bg, "janela normal restaurada")
	_check(win.size == normal_size and win.position == normal_pos, "mesmo tamanho e lugar de antes (%s em %s)" % [win.size, win.position])
	menu.open()
	await get_tree().create_timer(1.6, true).timeout
	_check(board.position.distance_to(board_home) < 1.0, "menu abre no lugar certo depois do modo flutuante (%s, esperado %s)" % [board.position, board_home])
	_shot(out, "menu_depois.png")
	menu.close(true)
	await _frames(5)
	_shot(out, "normal.png")
	remove_child(_main)
	_main.free()
	if had_save:
		DirAccess.copy_absolute(backup, save_path)
		DirAccess.remove_absolute(backup)
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if had_cfg:
		DirAccess.copy_absolute(cfg_backup, cfg_path)
		DirAccess.remove_absolute(cfg_backup)
	print("== %d falha(s) ==" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
