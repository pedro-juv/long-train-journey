class_name Hotkeys
extends RefCounted
## Hotkeys — atalho de teclado para "Atiçar a caldeira".
##
## A ação "stoke" é criada em tempo de execução com a tecla escolhida pelo
## jogador (padrão: Espaço) e fica salva em user://settings.cfg, seção
## "controls". Usa a tecla física (independe do layout do teclado).
## Tecla 0 (KEY_NONE) = sem atalho; o clique no botão continua valendo sempre.

const STOKE_ACTION := "stoke"
const DEFAULT_STOKE_KEY := KEY_SPACE
const SETTINGS_PATH := "user://settings.cfg"

## Teclas que não podem virar atalho (ESC abre o menu).
const RESERVED := [KEY_ESCAPE]

static var stoke_key: Key = DEFAULT_STOKE_KEY
static var _loaded := false


## Lê a tecla salva e monta a ação (seguro chamar várias vezes).
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		stoke_key = int(cfg.get_value("controls", "stoke_key", DEFAULT_STOKE_KEY)) as Key
	_apply()


## Troca a tecla (KEY_NONE remove o atalho) e salva.
static func set_stoke_key(key: Key) -> void:
	ensure_loaded()
	if key in RESERVED:
		return
	stoke_key = key
	_apply()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # mantém as outras seções (áudio, janela flutuante)
	cfg.set_value("controls", "stoke_key", int(key))
	cfg.save(SETTINGS_PATH)


## Nome da tecla para mostrar ("Espaço", "F", "Enter"...); "" sem atalho.
static func stoke_key_name() -> String:
	ensure_loaded()
	if stoke_key == KEY_NONE:
		return ""
	match stoke_key:
		KEY_SPACE: return "Espaço"
		KEY_ENTER: return "Enter"
		KEY_KP_ENTER: return "Enter (numérico)"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_TAB: return "Tab"
	var shown := DisplayServer.keyboard_get_keycode_from_physical(stoke_key)
	return OS.get_keycode_string(shown if shown != KEY_NONE else stoke_key)


## O evento é um aperto (sem repetição de tecla segurada) do atalho?
static func is_stoke_event(event: InputEvent) -> bool:
	ensure_loaded()
	if stoke_key == KEY_NONE or not (event is InputEventKey):
		return false
	return event.is_action_pressed(STOKE_ACTION, false, true) and not event.is_echo()


static func _apply() -> void:
	if not InputMap.has_action(STOKE_ACTION):
		InputMap.add_action(STOKE_ACTION)
	InputMap.action_erase_events(STOKE_ACTION)
	if stoke_key != KEY_NONE:
		var ev := InputEventKey.new()
		ev.physical_keycode = stoke_key
		InputMap.action_add_event(STOKE_ACTION, ev)
