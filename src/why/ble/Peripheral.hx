package why.ble;

import tink.state.*;

using Lambda;
using tink.CoreApi;

@:forward
abstract Peripheral(PeripheralObject) from PeripheralObject to PeripheralObject {
	public function discoverCharacteristics():Promise<Array<Characteristic>> {
		return this.discoverServices()
			.next(function(services) return Promise.inParallel([for(service in services) service.discoverCharacteristics()]))
			.next(function(list) return list.fold(function(item, all:Array<Characteristic>) return all.concat(item), []));
	}
}

interface PeripheralObject {
	var id(default, null):String;
	var mac(default, null):String;
	var connectable(default, null):Observable<Bool>;
	var rssi(default, null):Observable<Int>;
	var advertisement(default, null):Observable<Advertisement>;
	var connected(default, null):Observable<Bool>;
	
	function connect():Promise<Noise>;
	function disconnect():Promise<Noise>;
	function discoverServices():Promise<Array<Service>>;
}