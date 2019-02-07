package why.ble;

import tink.Chunk;
using tink.CoreApi;

interface Descriptor {
	var uuid(default, null):Uuid;
	
	function read():Promise<Chunk>;
	function write(data:Chunk):Promise<Noise>;
	
}