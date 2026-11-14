extends Node

signal changed
const SETTINGS_PATH := "user://display_settings.cfg"
const WIDTHS := [1280.0, 1680.0, 10000.0]
var width_mode := 0
var margin := 16

func _ready() -> void:
	load_settings()

func load_settings(path: String = SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var saved_mode: Variant = config.get_value("ui", "width_mode", 0)
	var saved_margin: Variant = config.get_value("ui", "margin", 16)
	width_mode = clampi(saved_mode, 0, 2) if saved_mode is int else 0
	margin = clampi(saved_margin, 8, 64) if saved_margin is int else 16
	changed.emit()

func apply_settings(mode: int, edge_margin: int, path: String = SETTINGS_PATH) -> Error:
	width_mode = clampi(mode, 0, 2)
	margin = clampi(edge_margin, 8, 64)
	changed.emit()
	var config := ConfigFile.new()
	config.set_value("ui", "width_mode", width_mode)
	config.set_value("ui", "margin", margin)
	return config.save(path)
