extends ColorPickerButton


func _on_color_changed(color):
	g.world.update_colours(self.get_index(),color)
