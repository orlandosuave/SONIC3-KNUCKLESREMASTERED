extends VBoxContainer

var width_choice: OptionButton
var margin_choice: SpinBox
var status: Label

func _ready() -> void:
	custom_minimum_size.x = 520
	add_theme_constant_override("separation", 8)
	var heading := Label.new()
	heading.text = "HUD and menu placement"
	heading.add_theme_font_size_override("font_size", 18)
	add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var width_label := Label.new()
	width_label.text = "Safe width"
	row.add_child(width_label)
	width_choice = OptionButton.new()
	width_choice.add_item("Centered 16:9")
	width_choice.add_item("Centered 21:9")
	width_choice.add_item("Full window")
	row.add_child(width_choice)
	var margin_label := Label.new()
	margin_label.text = "Edge margin"
	row.add_child(margin_label)
	margin_choice = SpinBox.new()
	margin_choice.min_value = 8
	margin_choice.max_value = 64
	margin_choice.step = 8
	row.add_child(margin_choice)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Changes apply immediately and are saved. Gameplay framing stays the same."
	add_child(status)
	var reset := Button.new()
	reset.text = "Restore default placement"
	reset.pressed.connect(func(): _apply(0, 16))
	add_child(reset)
	var preferences := get_node("/root/UiPreferences")
	preferences.changed.connect(_sync)
	_sync()
	width_choice.item_selected.connect(func(index: int): _apply(index, int(margin_choice.value)))
	margin_choice.value_changed.connect(func(value: float): _apply(width_choice.selected, int(value)))

func _sync() -> void:
	var preferences := get_node("/root/UiPreferences")
	width_choice.select(preferences.width_mode)
	margin_choice.set_value_no_signal(preferences.margin)

func _apply(mode: int, edge_margin: int) -> void:
	var error: Error = get_node("/root/UiPreferences").apply_settings(mode, edge_margin)
	status.text = "Placement saved." if error == OK else "Placement applied, but could not save settings."
