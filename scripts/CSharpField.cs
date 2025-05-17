using Godot;
using System;
using System.Threading;
using CommunityToolkit.HighPerformance;
using System.Collections.Generic;

public partial class CSharpField : Node
{
	public ulong turns = 0;
	private Thread thread;
	private static System.Threading.Mutex mutex = new System.Threading.Mutex();
	public bool wrapAround = true;
	public Node2D chunkParent;
	
	public Dictionary<byte,(Vector2I, int rotation, byte state)> ants = new Dictionary<byte,(Vector2I, int rotation, byte state)>();
	public Dictionary<byte, byte[,,]> antRules = new Dictionary<byte, byte[,,]>();
	public Dictionary<(int x, int y),Image> images = new Dictionary<(int x, int y),Image>();
	public Dictionary<(int x, int y),Sprite2D> chunks = new Dictionary<(int x, int y),Sprite2D>();
	public Color[] l8Cols = new Color[64];
	public HashSet<(int x, int y)> updateQueue = new HashSet<(int x, int y)>(); 
	
	private ulong _b;
	private uint x = 1000000;
	private int[] y = {0};
	
	public override void _Ready(){
		for (int i = 0; i < 64; i++) {
			byte c = Convert.ToByte(i * 4);
			l8Cols[i] = Color.Color8(c,c,c);
		}
		
		thread = new Thread(AntTicks);
		thread.Name = "AntThicksThread";
		chunkParent = (Node2D) GetNode("../Canvas/HSplit/OnScreen/Sim/SimViewport/Field/Chunks");
		
		ants.Add(0,(new Vector2I(256,256),0,0));
		byte[,,] defaultRules = new byte[2,1,3];
		defaultRules[0,0,0] = 1;
		defaultRules[0,0,1] = 0;
		defaultRules[0,0,2] = 1;
		defaultRules[1,0,0] = 0;
		defaultRules[1,0,1] = 0;
		defaultRules[1,0,2] = 3;
		
		antRules.Add(0,defaultRules);
		
		for (int r = 0; r < 8; r++) {
			for (int c = 0; c < 8; c++) {
				NewChunk((c,r));
			}
		}
	}
	
	public void Start(){
		//thread.Start();
	}
	
	public void AntTicks(){
		int chunkSize = GlobalCS.Instance.ChunkSize;
		float chunkSizeF = GlobalCS.Instance.ChunkSize;
		byte[,,] rules;
		Vector2I chunk;
		(Vector2I, int Rotation, byte State) ant;
		(int posX,int posY) which; //chunk local pos
		ValueTuple<int,int> pos = new ValueTuple<int,int>(0,0);
		
		GD.Print("---");
		for (int i = 0; i < 1; i++) {
			foreach(var a in ants) { 
				ant = a.Value;
				
				chunk = (Vector2I)((Vector2)ant.Item1 / chunkSizeF).Floor();
				
				if (images.ContainsKey(chunk)) {
					if (wrapAround) {
						
					} else {
						
					}
					GD.Print("yup");
				}
				which.Item1 = ant.Item1.Item1 - chunk.Item1 * chunkSize;
				which.Item2 = ant.Item1.Item2 - chunk.Item2 * chunkSize;
				
				rules = antRules[a.Key];
				int gState = images[chunk].GetPixel(which.Item1, which.Item2).R8 >> 2;
				byte aState = ant.Item3;
				
				images[chunk].SetPixel(which.Item1,which.Item2,l8Cols[rules[gState,aState,0]]);
				
				ant.Item3 = rules[gState,aState,1];
				ant.Item2 = (ant.Item2 + rules[gState,aState,2]) & 0x3;
				//ant.Item1 = pos + sq_move[ant[1]];
				
				turns = turns + 1;
				
				//_b = Time.GetTicksUsec();
				//GD.Print(Time.GetTicksUsec() - _b);
			}
		}
		
		GD.Print("---");
		
		//while (IsProcessing()) {
			//steps++;
		//}
		
	}
	
	public void _on_second_timer_timeout(){
		//GD.Print(steps);
	}
	
	public void NewChunk((int x, int y) pos) {
		Sprite2D sprite = new Sprite2D();
		Image img = Image.CreateEmpty(GlobalCS.Instance.ChunkSize,GlobalCS.Instance.ChunkSize,false,Image.Format.L8);
		ImageTexture texture = ImageTexture.CreateFromImage(img);
		
		sprite.Texture = texture;
		sprite.Position = new Vector2(pos.Item1, pos.Item2) * GlobalCS.Instance.ChunkSize;
		
		chunks[pos] = sprite;
		images[pos] = img;
		chunkParent.CallDeferred("add_child",sprite);
	}
}
