extends Node

var max_colours:int = 24
var max_states:int = 24
var field_x:int = 512
var field_y:int = 512
var state_amt:PackedByteArray = []
var colour_amt:int = 2
var randomizing:bool = false
var pppp:float #pixels per project pixel
var ipppp:float #inverse pppp
var int_scaling:float #pppp scaling rouded to nearest power of 2 or 0.5/0.25/0.125 etc
var sq_chunksize:int = 256
var selected_ant:int = 0
var rightmost_chunk:Vector2i
var downmost_chunk:Vector2i
var upmost_chunk:Vector2i
var leftmost_chunk:Vector2i
var user_pallete:Image

# instances
var sidebar:Control
var world:Node2D
var ant_camera:Camera2D


func _ready():
	state_amt.resize(64)
	
	#set colour 0 to black, 1 to white, and the rest are random!
	user_pallete = Image.create_empty(1,64,false,Image.FORMAT_RGB8)
	for i in 62:
		user_pallete.set_pixel(0,i+2,Color(randf(),randf(),randf()))
	user_pallete.set_pixel(0,1,Color.WHITE)

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
