package ble;

import tink.Chunk;
using tink.CoreApi;

interface Characteristic {
	var uuid(default, null):Uuid;
	
	function read():Promise<Chunk>;
	function write(data:Chunk, withoutResponse:Bool):Promise<Noise>;
	
	function subscribe(handler:Callback<Outcome<Chunk, Error>>):CallbackLink;
	
	// TODO
	// function discoverDescriptors():Promise<Array<Descriptor>>;
}