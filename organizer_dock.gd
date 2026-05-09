@tool
extends Control

const SETTINGS_FILE = "res://addons/project_cleaner_&_organiser/settings.cfg"

var rules = {}
var base_ignore = ["addons", ".godot", ".tmp"] # Системные папки, которые игнорируем всегда

# Ссылки на узлы интерфейса (Проверь, что в сцене .tscn имена совпадают!)
@onready var rules_list = $ScrollContainer/MainVBox/RulesList
@onready var sort_button = $ScrollContainer/MainVBox/SortButton
@onready var add_rule_button = $ScrollContainer/MainVBox/AddRuleButton
@onready var save_button = $ScrollContainer/MainVBox/SaveButton
@onready var show_rules_button = $ScrollContainer/MainVBox/ShowRulesButton
@onready var init_project_button = $ScrollContainer/MainVBox/InitProjectButton
@onready var ignore_list_input = $ScrollContainer/MainVBox/IgnoreListInput

func _ready():
	load_settings()
	refresh_ui()
	
	# Начальное состояние (скрываем настройки)
	rules_list.visible = false
	add_rule_button.visible = false
	show_rules_button.text = "Настроить правила"
	
	# Безопасное подключение всех сигналов
	_connect_signal(show_rules_button, _toggle_rules_visibility)
	_connect_signal(sort_button, _on_sort_pressed)
	_connect_signal(add_rule_button, _add_empty_rule)
	_connect_signal(save_button, save_settings)
	_connect_signal(init_project_button, _on_init_project_pressed)

# Вспомогательная функция для подключения сигналов без дубликатов
func _connect_signal(target_btn: Button, target_func: Callable):
	if target_btn and not target_btn.pressed.is_connected(target_func):
		target_btn.pressed.connect(target_func)

# --- ИНТЕРФЕЙСНЫЕ ФУНКЦИИ ---

func _toggle_rules_visibility():
	var is_now_visible = !rules_list.visible
	rules_list.visible = is_now_visible
	add_rule_button.visible = is_now_visible
	show_rules_button.text = "Закрыть настройки" if is_now_visible else "Настроить правила"

func refresh_ui():
	for child in rules_list.get_children():
		child.queue_free()
	for ext in rules:
		_create_rule_ui(ext, rules[ext])

func _create_rule_ui(ext: String, folder: String):
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var ext_input = LineEdit.new()
	ext_input.text = ext
	ext_input.placeholder_text = "ext"
	ext_input.custom_minimum_size.x = 60
	
	var path_input = LineEdit.new()
	path_input.text = folder
	path_input.placeholder_text = "res://..."
	path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	
	var del_btn = Button.new()
	del_btn.text = " X "
	del_btn.pressed.connect(func(): hbox.queue_free())
	
	hbox.add_child(ext_input)
	hbox.add_child(path_input)
	hbox.add_child(del_btn)
	rules_list.add_child(hbox)

func _add_empty_rule():
	_create_rule_ui("", "res://")

# --- ЛОГИКА НАСТРОЕК ---

func save_settings():
	rules.clear()
	for hbox in rules_list.get_children():
		var ext = hbox.get_child(0).text.strip_edges().to_lower()
		var path = hbox.get_child(1).text.strip_edges()
		if ext != "" and path != "":
			rules[ext] = path
	
	var config = ConfigFile.new()
	for ext in rules:
		config.set_value("rules", ext, rules[ext])
	config.set_value("settings", "ignore_list", ignore_list_input.text)
	config.save(SETTINGS_FILE)
	print("[Project Organizer] Настройки сохранены.")

func load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		rules.clear()
		for ext in config.get_section_keys("rules"):
			rules[ext] = config.get_value("rules", ext)
		ignore_list_input.text = config.get_value("settings", "ignore_list", "addons, .godot")
	else:
		# Набор по умолчанию
		rules = {"png": "res://assets/textures/", "gd": "res://scripts/", "tscn": "res://scenes/"}
		ignore_list_input.text = "addons, .godot"

# --- ОСНОВНАЯ ЛОГИКА ---

func _on_init_project_pressed():
	var folders = ["res://assets/textures", "res://assets/audio", "res://scenes", "res://scripts", "res://prefabs"]
	for p in folders:
		if not DirAccess.dir_exists_absolute(p):
			DirAccess.make_dir_recursive_absolute(p)
	EditorInterface.get_resource_filesystem().scan()
	print("[Project Organizer] Структура папок готова.")

func _on_sort_pressed():
	save_settings()
	print("--- Начало очистки ---")
	organize_files("res://")
	remove_empty_folders("res://")
	EditorInterface.get_resource_filesystem().scan()
	print("--- Конец очистки ---")

func is_ignored(folder_name: String) -> bool:
	var user_ignore = ignore_list_input.text.split(",")
	for item in user_ignore:
		if folder_name == item.strip_edges(): return true
	return folder_name in base_ignore

func organize_files(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path + file_name
			if dir.current_is_dir():
				if not is_ignored(file_name) and not file_name.begins_with("."):
					organize_files(full_path + "/")
			else:
				var ext = file_name.get_extension().to_lower()
				if rules.has(ext):
					_move_file(full_path, rules[ext] + file_name)
			file_name = dir.get_next()

func _move_file(old_path, new_path):
	if old_path == new_path or old_path.contains("/addons/"): return
	var target_folder = new_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(target_folder):
		DirAccess.make_dir_recursive_absolute(target_folder)
	DirAccess.rename_absolute(old_path, new_path)

func remove_empty_folders(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var full_path = path + file_name + "/"
				if not is_ignored(file_name) and not file_name.begins_with("."):
					remove_empty_folders(full_path)
					var sub_dir = DirAccess.open(full_path)
					if sub_dir:
						sub_dir.list_dir_begin()
						if sub_dir.get_next() == "":
							DirAccess.remove_absolute(full_path)
							print("Удалена пустая папка: ", full_path)
			file_name = dir.get_next()