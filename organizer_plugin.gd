@tool
extends EditorPlugin

var dock

func _enter_tree():
	# Загружаем сцену интерфейса
	dock = preload("res://addons/project_cleaner_&_organiser/organizer_dock.tscn").instantiate()
	# Добавляем в правый нижний угол редактора
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree():
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()