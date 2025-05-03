using Godot;
using System;

public partial class GlobalCS : Node
{
    int x;
    int y;
    int state_amt = 2;
    int colour_amt = 2;
    int sq_chunksize = 50;

    public override void _Ready()
    {
        GD.Print("CS Global loaded");
    }
}
