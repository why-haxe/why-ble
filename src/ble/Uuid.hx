package ble;

import tink.Chunk;

using StringTools;

@:forward
abstract Uuid(Chunk) to Chunk {
	
	static var ZERO_PAD = Chunk.ofHex('0000');
	static var BASE_UUID = Chunk.ofHex('00001000800000805F9B34FB');
	
	inline function new(chunk)
		this = chunk;
	
	@:from
	public static function ofString(v:String):Uuid {
		v = v.replace('-', '');
		return switch v.length >> 1 {
			case 2 | 4 | 16: new Uuid(Chunk.ofHex(v));
			case _: throw 'Invalid UUID. Should be a 2/4/16-byte hex.';
		}
	}
	
	@:op(A == B)
	public function equals(that:Uuid):Bool {
		return this.length == that.length ? compare(this, that) : compare(full(), that.full());
	}
	
	public function full():Uuid {
		return new Uuid(switch this.length {
			case 2: ZERO_PAD & this & BASE_UUID;
			case 4: this & BASE_UUID;
			case 16: this;
			case _: throw 'unreachable';
		});
	}	
	
	function compare(u1:Chunk, u2:Chunk) {
		if(u1.length == u2.length) {
			var i1 = u1.iterator();
			var i2 = u2.iterator();
			while(i1.hasNext() && i2.hasNext())
				if(i1.next() != i2.next()) return false;
			return true;
		} else {
			return false;
		}
	}
}