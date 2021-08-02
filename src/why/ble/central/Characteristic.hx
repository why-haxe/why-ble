package why.ble.central;

import tink.Chunk;

using tink.CoreApi;

interface Characteristic {
	final uuid:String;
	final value:Signal<Chunk>;
	function write(chunk:Chunk, ?options:{?withoutResponse:Bool, ?offset:Int}):Promise<Noise>;
	function read(?options:{?offset:Int}):Promise<Chunk>;
}
