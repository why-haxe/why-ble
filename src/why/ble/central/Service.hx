package why.ble.central;

using tink.CoreApi;

interface Service {
	final uuid:String;
	function getCharacteristics():Promise<Array<Characteristic>>;
}