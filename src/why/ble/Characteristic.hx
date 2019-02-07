package why.ble;

import tink.Chunk;
using tink.CoreApi;

@:forward
abstract Characteristic(CharacteristicObject) from CharacteristicObject to CharacteristicObject {}

interface CharacteristicObject {
	var uuid(default, null):Uuid;
	var properties(default, null):Iterable<Property>; // TODO: use ReadOnlyArray
	
	function read():Promise<Chunk>;
	function write(data:Chunk, withoutResponse:Bool):Promise<Noise>;
	
	function subscribe(handler:Callback<Outcome<Chunk, Error>>):CallbackLink;
	
	// TODO
	// function discoverDescriptors():Promise<Array<Descriptor>>;
}

enum Property {
	Broadcast;
	Read;
	WriteWithoutResponse;
	Write;
	Notify;
	Indicate;
	AuthenticatedSignedWrites;
	ExtendedProperties;
	Unknown(v:String);
}