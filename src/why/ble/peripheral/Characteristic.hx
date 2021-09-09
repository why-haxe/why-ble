package why.ble.peripheral;

import tink.Chunk;

using tink.CoreApi;

interface Characteristic {
	final uuid:String;
	final properties:Array<CharacteristicProperty>;
	final value:Signal<Chunk>;
	// final descriptors:Array<Descriptor>;
	function write(chunk:Chunk, ?options:{?withoutResponse:Bool, ?offset:Int}):Promise<Noise>;
	function read(?options:{?offset:Int}):Promise<Chunk>;
}