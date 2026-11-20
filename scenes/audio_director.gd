extends Node
## AudioDirector — música e efeitos sonoros.
##
## Escuta o EventBus e as baforadas do TrainView; não conhece regras de jogo.
## As preferências (música e efeitos ligados/desligados) ficam em
## user://settings.cfg, separadas do save da partida.
##
## Todos os sons são originais, sintetizados pelos scripts em tools/audio/.

@export var train_view_path: NodePath

const SETTINGS_PATH := "user://settings.cfg"

## Volumes (dB). A música fica abaixo dos efeitos para não cansar.
const MUSIC_DB := -9.0
const SILENT_DB := -60.0
## Segundos da passagem de uma variação da música para a outra.
const MUSIC_FADE_SECONDS := 2.5

## Uma variação da trilha por tema de região (scenes/season_themes.gd).
const MUSIC_BY_THEME := {
	"inicio": "res://assets/audio/musica_steampunk.ogg",
	"primavera": "res://assets/audio/musica_primavera.ogg",
	"verao": "res://assets/audio/musica_verao.ogg",
	"outono": "res://assets/audio/musica_outono.ogg",
	"inverno": "res://assets/audio/musica_inverno.ogg",
}
const CHUFF_DB_MIN := -26.0
const CHUFF_DB_MAX := -14.0

var music_enabled: bool = true
var sfx_enabled: bool = true

var _music: AudioStreamPlayer        # variação tocando agora
var _music_old: AudioStreamPlayer    # variação anterior, sumindo
var _music_theme: String = ""
var _music_tween: Tween
var _chuff_players: Array[AudioStreamPlayer] = []
var _chuff_index: int = 0
var _sfx: Dictionary = {}   # nome -> AudioStreamPlayer


func _ready() -> void:
	_load_settings()
	_music = _make_player("", MUSIC_DB)
	_music_old = _make_player("", SILENT_DB)
	_set_music_theme("inicio", false)
	for i in 4:  # baforadas podem se sobrepor em velocidade alta
		_chuff_players.append(_make_player("res://assets/audio/chuff.wav", CHUFF_DB_MIN))
	_sfx["click"] = _make_player("res://assets/audio/click.wav", -10.0)
	_sfx["buy"] = _make_player("res://assets/audio/buy.wav", -9.0)
	_sfx["whistle"] = _make_player("res://assets/audio/whistle.wav", -8.0)
	_sfx["fanfare"] = _make_player("res://assets/audio/fanfare.wav", -9.0)
	_sfx["failure"] = _make_player("res://assets/audio/failure.wav", -7.0)
	_sfx["repair"] = _make_player("res://assets/audio/repair.wav", -9.0)
	_sfx["auto_repair"] = _make_player("res://assets/audio/repair.wav", -20.0)  # discreto

	EventBus.coal_clicked.connect(func(): _play("click", randf_range(0.9, 1.1)))
	EventBus.producer_bought.connect(_on_producer_bought)
	EventBus.upgrade_purchased.connect(func(_id): _play("buy", 0.9))
	EventBus.station_reached.connect(_on_station_reached)
	EventBus.component_failed.connect(func(_id, _n): _play("failure", randf_range(0.95, 1.05)))
	EventBus.component_repaired.connect(func(_id, automatic): _play("auto_repair" if automatic else "repair", randf_range(0.95, 1.08)))
	EventBus.component_reinforced.connect(func(_id, _lvl): _play("buy", 0.85))
	var train_view := get_node_or_null(train_view_path)
	if train_view:
		train_view.chuffed.connect(_on_chuff)
		train_view.theme_changed.connect(_on_theme_changed)
	_apply_music()


## Para todos os sons ao sair, para o Godot fechar sem sons pendurados.
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	_apply_music()
	_save_settings()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	_save_settings()


# ---------------------------------------------------------------------------

## Troca a variação da música quando a região muda (com passagem suave).
func _on_theme_changed(theme_id: String) -> void:
	_set_music_theme(theme_id, true)


func _set_music_theme(theme_id: String, fade: bool) -> void:
	if not MUSIC_BY_THEME.has(theme_id) or theme_id == _music_theme:
		return
	var path: String = MUSIC_BY_THEME[theme_id]
	if not ResourceLoader.exists(path):
		push_warning("AudioDirector: música não encontrada: %s" % path)
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var was_playing := _music.playing
	_music_theme = theme_id
	if _music_tween:
		_music_tween.kill()
	if fade and was_playing and music_enabled:
		# a que estava tocando passa para o player "antigo" e some aos poucos
		var position := _music.get_playback_position()
		_music_old.stream = _music.stream
		_music_old.volume_db = MUSIC_DB
		_music_old.play(position)
		_music.stream = stream
		_music.volume_db = SILENT_DB
		_music.play()
		_music_tween = create_tween().set_parallel(true)
		_music_tween.tween_property(_music, "volume_db", MUSIC_DB, MUSIC_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_music_tween.tween_property(_music_old, "volume_db", SILENT_DB, MUSIC_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_music_tween.chain().tween_callback(_music_old.stop)
	else:
		_music_old.stop()
		_music.stream = stream
		_music.volume_db = MUSIC_DB
		_apply_music()


func current_music_theme() -> String:
	return _music_theme


func _on_producer_bought(_id: String, _level: int, milestone: bool) -> void:
	_play("buy", randf_range(0.97, 1.05))
	if milestone:
		_play("fanfare", 1.0)


func _on_station_reached(_index: int, _station_name: String) -> void:
	_play("whistle", 1.0)
	_play("fanfare", 1.0)


func _on_chuff(intensity: float) -> void:
	if not sfx_enabled:
		return
	var p := _chuff_players[_chuff_index]
	_chuff_index = (_chuff_index + 1) % _chuff_players.size()
	p.volume_db = lerpf(CHUFF_DB_MIN, CHUFF_DB_MAX, intensity)
	p.pitch_scale = randf_range(0.92, 1.08) * lerpf(0.9, 1.15, intensity)
	p.play()


func _play(sound: String, pitch: float) -> void:
	if not sfx_enabled or not _sfx.has(sound):
		return
	var p: AudioStreamPlayer = _sfx[sound]
	p.pitch_scale = pitch
	p.play()


func _apply_music() -> void:
	if music_enabled and not _music.playing:
		_music.play()
	elif not music_enabled:
		_music.stop()
		_music_old.stop()


func _make_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if path == "":
		pass  # o stream é definido depois (música)
	elif ResourceLoader.exists(path):
		p.stream = load(path)
	else:
		push_warning("AudioDirector: som não encontrado: %s" % path)
	p.volume_db = volume_db
	add_child(p)
	return p


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_enabled = bool(cfg.get_value("audio", "music", true))
		sfx_enabled = bool(cfg.get_value("audio", "sfx", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_enabled)
	cfg.set_value("audio", "sfx", sfx_enabled)
	cfg.save(SETTINGS_PATH)
