extends Control

func _process(_delta):
	$XY/Colours.position.x = -$ScrollCont.scroll_horizontal
	$XY/Labels.position.y = -$ScrollCont.scroll_vertical
