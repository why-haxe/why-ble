package why.ble;

import tink.Chunk;
import tink.core.ext.Subscription;
using tink.CoreApi;

@:forward
abstract Characteristic(CharacteristicObject) from CharacteristicObject to CharacteristicObject {}

interface CharacteristicObject {
	var uuid(default, null):Uuid;
	var properties(default, null):Iterable<Property>; // TODO: use ReadOnlyArray
	
	function read():Promise<Chunk>;
	function write(data:Chunk, withoutResponse:Bool):Promise<Noise>;
	
	function subscribe(handler:Callback<Chunk>):Subscription;
	
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