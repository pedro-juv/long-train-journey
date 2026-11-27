class_name PatchNotes
extends CanvasLayer
## Notas da versão: abrem sozinhas na primeira vez que o jogo abre numa versão
## nova e podem ser vistas de novo pelo menu de opções (ESC).
## A última versão vista fica em user://settings.cfg ("patch_notes"/"last_seen").

const SETTINGS_PATH := "user://settings.cfg"

@export var float_path: NodePath = NodePath("../FloatMode")

var is_open: bool = false

var _root: Control
var _board: PanelContainer
var _text: RichTextLabel
var _close_button: Button
var _subtitle: Label


static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


static func last_seen_version() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return str(cfg.get_value("patch_notes", "last_seen", ""))


## Abre sozinha? Só quando a versão atual tem notas e ainda não foi vista.
static func should_show_on_start() -> bool:
	var v := current_version()
	return v != "" and PatchNotesData.has_version(v) and last_seen_version() != v


static func mark_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # mantém as outras seções (áudio, atalho, janela)
	cfg.set_value("patch_notes", "last_seen", current_version())
	cfg.save(SETTINGS_PATH)


func _ready() -> void:
	layer = 30   # acima do menu de opções (20)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	_show_on_start.call_deferred()


func _show_on_start() -> void:
	if should_show_on_start():
		open()


func open() -> void:
	var float_mode := get_node_or_null(float_path)
	if float_mode and float_mode.active:
		return   # na janelinha não cabe; fica para a próxima vez
	_subtitle.text = "Versão atual: %s" % current_version()
	_text.text = PatchNotesData.to_bbcode(current_version())
	_text.scroll_to_line(0)
	_root.visible = true
	is_open = true
	mark_seen()


func close() -> void:
	_root.visible = false
	is_open = false


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var key := event as InputEventKey
	var closes := event.is_action_pressed("toggle_options") or (key != null and key.pressed and not key.echo and key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER])
	if closes:
		close()
	if closes or key != null:
		get_viewport().set_input_as_handled()   # com as notas abertas o teclado não age no jogo


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_board = PanelContainer.new()
	_board.name = "Board"
	_board.custom_minimum_size = Vector2(700, 560)
	var paper := HudSkin.ticket_style()
	paper.set_content_margin_all(22)
	_board.add_theme_stylebox_override("panel", paper)
	center.add_child(_board)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_board.add_child(vbox)
	var title := Label.new()
	title.text = "NOTAS DA VERSÃO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", HudSkin.WINE)
	vbox.add_child(title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 14)
	_subtitle.add_theme_color_override("font_color", HudSkin.INK)
	vbox.add_child(_subtitle)

	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 16)
	_text.add_theme_font_size_override("bold_font_size", 16)
	_text.add_theme_font_size_override("italics_font_size", 16)
	_text.add_theme_color_override("default_color", HudSkin.INK)
	_text.add_theme_constant_override("line_separation", 3)
	vbox.add_child(_text)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "FECHAR"
	_close_button.custom_minimum_size = Vector2(220, 46)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.add_theme_font_size_override("font_size", 20)
	_close_button.add_theme_stylebox_override("normal", HudSkin.button_style(HudSkin.WINE_LIGHT))
	_close_button.add_theme_stylebox_override("hover", HudSkin.button_style(HudSkin.WINE_LIGHT.lightened(0.12)))
	_close_button.add_theme_stylebox_override("pressed", HudSkin.button_style(HudSkin.WINE, true))
	_close_button.pressed.connect(close)
	vbox.add_child(_close_button)
