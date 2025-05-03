using Godot;
using System;
using CommunityToolkit.HighPerformance;

public partial class CSharpField : Node
{
	int field_width;
	int field_height;

	Array ants;

	int[,] colours = { { } };

	private uint _a = 0;
	private ulong _b;
	public override void _Ready(){
		//var _c = Time.GetTicksUsec();
		_b = Time.GetTicksUsec();
		
		for (var i=0; i < 1000000; i++){
			_a = GD.Randi();
			//GD.Print(GD.Randi());
			}
		
		GD.Print(Time.GetTicksUsec() - _b);
	}
}
