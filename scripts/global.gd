extends Node

var field_x:int = 500
var field_y:int = 500
var state_amt:PackedByteArray = []
var colour_amt:int = 2
var randomizing:bool = false
var pppp:float #pixels per project pixel
var ipppp:float #inverse pppp
var int_scaling:float #pppp scaling rouded to nearest power of 2 or 0.5/0.25/0.125 etc
var sq_chunksize:int = 50
var selected_ant:int = 0

# instances
var rule_edit
var world


func _ready():
	state_amt.resize(50)


func calc_pppp():
	if get_viewport().size.x > get_viewport().size.y:
		pppp = get_viewport().size.y / 1080.0
	else:
		pppp = get_viewport().size.x / 1080.0
	ipppp = 1.0 / pppp
	int_scaling = get_integer_scaling(pppp)


func get_integer_scaling(p) -> float: 
	var x: float = 1.0
	var lower = x / 2
	var higher = x * 2
	var s_range = [(x + lower) / 2, (x + higher) / 2]
	if (p > 1):
		while true:
			if (p > s_range[1]):
				x = x * 2
				lower = x / 2
				higher = x * 2
				s_range = [(x + lower) / 2, (x + higher) / 2]
			else:
				break
	else:
		while true:
			if (p < s_range[0]):
				x = x / 2
				lower = x / 2
				higher = x * 2
				s_range = [(x + lower) / 2, (x + higher) / 2]
			else:
				break
	return x
