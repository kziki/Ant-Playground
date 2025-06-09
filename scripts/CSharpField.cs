using Godot;
using System;
using System.Threading;
using System.Collections.Generic;

//this csharp code is wip!! for now the software uses the gdscript version found in the world script. will eventually use this which is much faster
//gdscript ~1.6m tps
//csharp should be ~20m tps. havent tested exported executable tps yet

public partial class CSharpField : Node
{
	private Thread thread;
	private static System.Threading.Mutex mutex = new System.Threading.Mutex();
	private ulong _b;
	
	public ulong turns = 0;
	public ulong prevTurns = 0;
	public bool wrapAround = true;
	public Node2D chunkParent;
	public enum sqDir:int{
		UP = 0,
		RIGHT = 1,
		DOWN = 2,
		LEFT = 3
	}
	public (int x, int y)[] sqMove = new (int x, int y)[4];
	
	public int ants = 0;
	public (int x, int y)[] antPositions = new (int x, int y)[0];
	public byte[] antStates = new byte[0];
	public int[] antRotations = new int[0];
	public byte[][,,] antRules = new byte[0][,,];
	
	public Dictionary<(int x, int y),Chunk> chunks = new Dictionary<(int x, int y),Chunk>();
	public HashSet<(int x, int y)> updateQueue = new HashSet<(int x, int y)>();
	
	public class Chunk {
		public Sprite2D Sprite;
		public ImageTexture Texture;
		public Image Image;
		public byte[] ImgData;
	}
	
	public override void _Ready(){
		sqMove[0] = (0,-1);
		sqMove[1] = (1,0);
		sqMove[2] = (0,1);
		sqMove[3] = (-1,0);
		
		thread = new Thread(AntTicks);
		thread.Name = "AntTicksThread";
		chunkParent = (Node2D) GetNode("../Canvas/HSplit/OnScreen/Sim/SimViewport/Field/SimChunks");
		
		AddAnt((256,256),0,0);
		
		byte[,,] defaultRules = new byte[24,24,3];
		defaultRules[0,0,0] = 1;
		defaultRules[0,0,1] = 0;
		defaultRules[0,0,2] = 1;
		defaultRules[1,0,0] = 0;
		defaultRules[1,0,1] = 0;
		defaultRules[1,0,2] = 3;
		
		AddAntRules(0,defaultRules);
		
		for (int r = 0; r < 8; r++) {
			for (int c = 0; c < 8; c++) {
				//NewChunk((c,r));
			}
		}
	}
	
	public void Start(){
		//thread.Start();
		//GD.Print("ant start");
	}
	
	public override void _Process(double delta) {
		mutex.WaitOne();
		foreach(var i in updateQueue) { 
			chunks[i].Image.SetData(64,64,false,Image.Format.L8,chunks[i].ImgData);
			chunks[i].Texture.Update(chunks[i].Image);
			chunks[i].Sprite.Texture = chunks[i].Texture;
		}
		updateQueue.Clear();
		mutex.ReleaseMutex();
	}
	
	public void AntTicks(){
		int chunkSize = GlobalCS.Instance.ChunkSize;
		float chunkSizeF = GlobalCS.Instance.ChunkSize;
		int fieldX = GlobalCS.Instance.FieldX;
		int fieldY = GlobalCS.Instance.FieldY;
		(int x, int y) chunk;
		int which1d; //chunk local pos
		HashSet<(int x, int y)> localQueue = new();
		byte gState; //grid state
		
		for (int i = 0; i < 1000000000; i++) {
			for (int ant = 0; ant <= ants; ant++) { 
				//wrap around or add new chunk if out of bounds
				if (wrapAround) {
					if (antPositions[ant].x >= GlobalCS.Instance.FieldX) { antPositions[ant].x = 0; }
					else if (antPositions[ant].y >= GlobalCS.Instance.FieldY) { antPositions[ant].y = 0; }
					else if (antPositions[ant].x < 0) { antPositions[ant].x = GlobalCS.Instance.FieldX - 1; }
					else if (antPositions[ant].y < 0) { antPositions[ant].y = GlobalCS.Instance.FieldY - 1; }
					chunk = ( antPositions[ant].x >> 6, antPositions[ant].y >> 6 ); //TODO: replcae >> 6 with chunksize division or something fancy that works with non powers of two.
				} else {
					//TODO: new chunk if out of bounds.
					chunk = ( (int)Math.Floor((float)antPositions[ant].x / chunkSizeF) , (int)Math.Floor((float)antPositions[ant].y / chunkSizeF) );
				}
				//get local position to chunk
				which1d = ( antPositions[ant].x - chunk.x * chunkSize) + (antPositions[ant].y - chunk.y * chunkSize) * chunkSize;
				
				//get image data and rules and state of the tile the ant is on
				var chunkdata = chunks[chunk];
				var rules = antRules[ant];
				gState = (byte)(chunkdata.ImgData[which1d]);
				
				// change tile state according to rule and add to local update queue
				chunkdata.ImgData[which1d] = (byte)(rules[ gState, antStates[ant], 0]);
				localQueue.Add(chunk);
				
				//rotate ant, move ant, and set ant state
				antStates[ant] = rules[gState, antStates[ant], 1];
				antRotations[ant] = (antRotations[ant] + rules[gState, antStates[ant], 2]) & 0x3;
				antPositions[ant] = (antPositions[ant].x + sqMove[antRotations[ant]].x, antPositions[ant].y + sqMove[antRotations[ant]].y);
				
				turns++;
				}
			if ((i & 0x3FF) == 0) { //TODO: change frequency of updating depending on tps
				mutex.WaitOne();
				foreach (var c in localQueue) {
					updateQueue.Add(c);
				}
				mutex.ReleaseMutex();
				localQueue.Clear();
			}
		}
	}
	
	public void _on_second_timer_timeout(){
		mutex.WaitOne();
		//GD.Print(turns - prevTurns);
		prevTurns = turns;
		mutex.ReleaseMutex();
	}
	
	public void NewChunk((int x, int y) pos) {
		Sprite2D sprite = new Sprite2D();
		Image img = Image.CreateEmpty(GlobalCS.Instance.ChunkSize,GlobalCS.Instance.ChunkSize,false,Image.Format.L8);
		ImageTexture texture = ImageTexture.CreateFromImage(img);
		var data = img.GetData();
		
		sprite.Texture = texture;
		sprite.Position = new Vector2(pos.x, pos.y) * GlobalCS.Instance.ChunkSize;
		
		chunks[pos] = new Chunk();//(sprite, texture, img, data);
		var chunk = chunks[pos];
		chunk.Sprite = sprite;
		chunk.Texture = texture;
		chunk.Image = img;
		chunk.ImgData = data;
		
		chunkParent.CallDeferred("add_child",sprite);
	}
	
	public void AddAnt((int x, int y) pos, int rotation, byte state) {
		int newLength = antPositions.Length + 1;
		Array.Resize(ref antPositions, newLength);
		Array.Resize(ref antRotations, newLength);
		Array.Resize(ref antStates, newLength);
		
		antPositions[newLength-1] = pos;
		antRotations[newLength-1] = rotation;
		antStates[newLength-1] = state;
		
		Array.Resize(ref antRules, newLength);
	}
	
	public void AddAntRules(int ant, byte[,,] rules) {
		antRules[ant] = rules;
	}
	
	//TODO: rest of the code. probably will have to move anything that has mutex.lock in the gdscript version. everything else should be fine if it stays there
}
