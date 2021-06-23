package why.ble;

import tink.Chunk;

using tink.CoreApi;

interface Characteristic {
	final uuid:String;
	final value:Signal<Chunk>;
	function write(chunk:Chunk, withResponse:Bool):Promise<Noise>;
	function read():Promise<Chunk>;
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
	
	ReliableWrite;
	WritableAuxiliaries;
	EncryptRead;
	EncryptWrite;
	EncryptAuthenticatedRead;
	EncryptAuthenticatedWrite;
	SecureRead;
	SecureWrite;
	Authorize;
}