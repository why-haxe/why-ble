package ble;

using tink.CoreApi;

interface Service {
	var uuid(default, null):Uuid;
	function discoverCharacteristics():Promise<Array<Characteristic>>;
}