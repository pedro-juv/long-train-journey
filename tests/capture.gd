extends Node
## Captura telas do jogo em alguns temas (comparação visual).
## Rodar: godot --path . res://tests/capture.tscn -- <pasta_de_saida>

## [tema, última estação alcançada]: a região é a do trecho até a próxima estação.
const THEMES := [["inicio", -1], ["tomada", 0], ["deserto", 1], ["ruinas", 2], ["inverno", 3],
	["tunel", 4], ["alagada", 5], ["fossa", 6], ["ceu", 7], ["cinzas", 8]]

var _main: Node


func _ready() -> void:
	var out := "user://capturas"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.delete_save()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	var game := _main.get_node("Game")
	var view := _main.get_node("TrainView")
	for t in THEMES:
		var station: int = t[1]
		if station >= 0:
			game.state.train.distance_m = game.state.route.target_distance(station) + 10.0
			game.state.route.update(game.state.train.distance_m)
		game.state.station_stop_left = 0.0
		game.state.train.current_speed = game.state.cruise_speed()
		view._on_game_loaded()   # entra direto no tema, sem transição
		for i in 90:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.path_join("%s.png" % t[0]))
		print("capturado: ", t[0])
	# trem flutuante nas regiões novas (fundo preto = desktop)
	for t in [["tunel", 4], ["alagada", 5], ["fossa", 6], ["ceu", 7], ["cinzas", 8]]:
		game.state.route.reached_count = 0
		game.state.train.distance_m = game.state.route.target_distance(t[1]) + 10.0
		game.state.route.update(game.state.train.distance_m)
		view._on_game_loaded()
		view.set_floating(true)
		_main.get_node("HUD").visible = false
		for i in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out.path_join("flutuante_%s.png" % t[0]))
		print("capturado: flutuante_", t[0])
		view.set_floating(false)
		_main.get_node("HUD").visible = true
	# parada na estação: plataforma, placa e lampiões
	view._station_signs.append({"x": view._platform_stop_x(), "name": "Cidade Tomada"})
	view._on_train_state_changed(TrainMovement.State.AT_STATION)
	view._on_speed_changed(0.0, 0.0, 0.0)
	game.set_process(false)
	game.state.train.state = TrainMovement.State.AT_STATION   # placa com o botão Partir
	game.state.waiting_departure = true
	_main.get_node("HUD")._refresh_state_label()
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("estacao.png"))
	print("capturado: estacao")
	# saindo da estação: a escuridão alcança a tela por um instante
	view._dark_depart = 0.75
	view._dark_surge = 0.6
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("partida.png"))
	print("capturado: partida")
	game.state.waiting_departure = false
	game.set_process(true)
	# menu de opções aberto (jogo pausado)
	_main.get_node("OptionsMenu").open()
	for i in 60:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("menu.png"))
	print("capturado: menu")
	_main.get_node("OptionsMenu").close()
	SaveManager.delete_save()
	get_tree().quit()
