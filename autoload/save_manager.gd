extends Node
## SaveManager — salvamento local.
##
## Grava um dicionário em JSON em user://save.json.
## Não conhece as regras do jogo: o GameState monta e lê o dicionário
## (inclusive o número de versão). Cloud Save pertence a etapas futuras.
##
## A gravação é segura: escreve num arquivo temporário e só então substitui o
## save, para que uma queda no meio da gravação não corrompa o progresso.

const SAVE_PATH := "user://save.json"
const TEMP_PATH := "user://save.json.tmp"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(data: Dictionary) -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: não foi possível abrir %s para escrita (%s)" % [TEMP_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_error("SaveManager: falha ao substituir o save (%s)" % err)
		return false
	return true


## Retorna o dicionário salvo, ou um dicionário vazio se não houver save válido.
func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: não foi possível abrir %s para leitura" % SAVE_PATH)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save inválido, ignorando.")
		return {}
	return parsed


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
