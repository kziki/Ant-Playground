extends Node

var x = 500
var y = 500
var t:int = 100
var state_amt:int = 2
var colour_amt:int = 2

var pppp
var ipppp
var int_scaling
var camera_rect

var sq_chunksize = 50

var edit_main
var world

var randomizing:bool = false

func calc_pppp():
	if get_viewport().size.x > get_viewport().size.y:
		pppp = get_viewport().size.y / 1080.0
	else:
		pppp = get_viewport().size.x / 1080.0
	ipppp = 1.0 / pppp
	int_scaling = get_integer_scaling(pppp)
	print (int_scaling)

func get_integer_scaling(p) -> float: 
	var found = false
	var x: float = 1.0
	var lower = x / 2
	var higher = x * 2
	var s_range = [(x + lower) / 2, (x + higher) / 2]
	if (p > 1):
		while !(found):
			if (p > s_range[1]):
				x = x * 2
				lower = x / 2
				higher = x * 2
				s_range = [(x + lower) / 2, (x + higher) / 2]
			else:
				found = true
	else:
		while !(found):
			if (p < s_range[0]):
				x = x / 2
				lower = x / 2
				higher = x * 2
				s_range = [(x + lower) / 2, (x + higher) / 2]
			else:
				found = true
	return x
