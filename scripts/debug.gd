extends Node2D

func _ready():
	var case = 2
		
	match case:
		0:
			var array = PackedByteArray()
			array.resize(2000*2000)
			for i in (2000*2000):
				pass
		1:
			var dict = {}
			for i in (40*40):
				var array = PackedByteArray()
				dict[i] = array.resize(50*50)
		2:
			$MultiMeshInstance2D.multimesh.instance_count = 2000*2000

func _physics_process(delta):
	print(Engine.get_frames_per_second())
