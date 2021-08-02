package why.ble.central;

import why.ble.RemoteValue;
import tink.Chunk;

using tink.CoreApi;

interface Peripheral {
	final uuid:String;
	
	final mac:RemoteReadableValue<String>;
	final name:RemoteReadableValue<String>;
	final uuids:RemoteReadableValue<Array<String>>;
	final connected:RemoteReadableValue<Bool>;
	final rssi:RemoteReadableValue<Int>;
	final txPower:RemoteReadableValue<Int>;
	final manufacturerData:RemoteReadableValue<Map<Int, Chunk>>;
	final serviceData:RemoteReadableValue<Map<String, Chunk>>;
	final servicesResolved:RemoteReadableValue<Bool>;
	final advertisingFlags:RemoteReadableValue<Chunk>;
	final advertisingData:RemoteReadableValue<Map<Int, Chunk>>;
	
	// final connected:Promise<Noise>;
	function connect():Promise<Noise>;
	function disconnect():Promise<Noise>;
	function getServices():Promise<Array<Service>>;
}