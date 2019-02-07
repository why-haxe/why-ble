package ble;

using tink.CoreApi;


@:forward
abstract Service(ServiceObject) from ServiceObject to ServiceObject {}

interface ServiceObject {
	var uuid(default, null):Uuid;
	function discoverCharacteristics():Promise<Array<Characteristic>>;
}