extends ColorPickerButton

func _on_color_changed(x):
	g.world.update_colours(self.get_index(),x)
