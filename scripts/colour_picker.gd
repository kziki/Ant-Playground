extends Control

func _on_color_changed(x):
	g.world.update_colours(self.get_index(),x)

func _ready():
	var picker:ColorPicker = $ColourPicker.get_picker()
	picker.can_add_swatches = false
	picker.presets_visible  = false
	picker.color_modes_visible = false
