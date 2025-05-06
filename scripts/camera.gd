extends Camera2D

var camera_tween
var camera_tween_pos

var can_move = true
var default_validzooms = [0.03125,0.0625,0.125,0.25,0.5,1]
var validzooms = [0.5,1,2,4,8,16]
var zoomindex:int = 1
var des_zoom = zoom
var des_pos = position


func _ready():
	zoom = Vector2.ONE * validzooms[zoomindex]


func _input(event):
	if can_move:
		# scroll
		if event is InputEventMouseButton:
			if event.is_pressed() and !get_node("../Canvas/HSplit/Sidebar").get_global_rect().grow(8*g.pppp).has_point(event.position):
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and zoomindex > 0:
					zoomindex -= 1
				if event.button_index == MOUSE_BUTTON_WHEEL_UP and zoomindex < validzooms.size()-1:
					zoomindex += 1
				des_zoom = Vector2.ONE * validzooms[zoomindex]
				zoom_tween(des_zoom,des_pos)
		# pan
		if event is InputEventMouseMotion:
			if event.button_mask == MOUSE_BUTTON_MASK_MIDDLE:
				if !get_node("../Canvas/HSplit/Sidebar").get_global_rect().grow(8*g.pppp).has_point(event.position):
					position -= event.relative / zoom


func get_valid_zooms():
	var x = 0
	validzooms = []
	for i in default_validzooms:
		validzooms.append(default_validzooms[x] * g.intscaling)
		x += 1

func set_zoom_to_index(index):
	zoomindex = index
	des_zoom = Vector2.ONE * validzooms[index]
	zoom_tween(des_zoom,des_pos)

func zoom_tween(to_zoom,_to_pos):
	if camera_tween:
		camera_tween.kill()
	if camera_tween_pos:
		camera_tween_pos.kill()
	camera_tween = get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	
	camera_tween.tween_property(self,"zoom",to_zoom,0.05)
	
	# TODO, zoom to mouse position!! tween the position !!!!!!
