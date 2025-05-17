using Godot;
using System;

public partial class GlobalCS : Node {
	private static GlobalCS _instance;
	public static GlobalCS Instance => _instance;
	
	
	public int FieldX {get; set;} = 512;
	public int FieldY {get; set;} = 512;
	public byte ChunkSize {get; set;} = 64;
	
	
	public override void _EnterTree(){
		if(_instance != null){
			this.QueueFree(); // The Singletone is already loaded, kill this instance
		}
	_instance = this;
	}
	
	public override void _Ready() {
		GD.Print("CS Global loaded");
		ChunkSize = 64;
		GD.Print(ChunkSize);
	}
}
