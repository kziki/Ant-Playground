extends MultiMeshInstance2D

# might replace with method that uses godot renderingserver to avoid high multimesh memory usage if possible
# most of the memory usage comes from the float32 buffer array in each multimesh

func _ready():
	pass


func init_multimesh(colour = Color.BLACK): 
	multimesh.instance_count = g.sq_chunksize * g.sq_chunksize
	multimesh.visible_instance_count = 0
	for r in g.sq_chunksize:
		for c in g.sq_chunksize:
			var pos = Vector2i(c,r)
			multimesh.visible_instance_count += 1
			multimesh.set_instance_transform_2d(multimesh.visible_instance_count-1,Transform2D(0.0,pos*16+Vector2i(8,8)))
			multimesh.set_instance_color(multimesh.visible_instance_count-1,colour)
