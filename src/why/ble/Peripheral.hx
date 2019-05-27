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
	
	public function findService(filter:Service->Bool):Promise<Service> {
		return this.discoverServices()
			.next(function(services) {
				return switch services.find(filter) {
					case null: new Error(NotFound, 'Service not found');
					case v: v;
				}
			});
	}
	
	public function findCharacteristic(filter:Characteristic->Bool):Promise<Characteristic> {
		return discoverCharacteristics()
			.next(function(chars) {
				return switch chars.find(filter) {
					case null: new Error(NotFound, 'Characteristic not found');
					case v: v;
				}
			});
	}
}

class PeripheralBase implements PeripheralObject {
	public var id(default, null):String;
	public var mac(default, null):String;
	public var connectable(default, null):Observable<Bool>;
	public var rssi(default, null):Observable<Int>;
	public var advertisement(default, null):Observable<Advertisement>;
	public var connected(default, null):Observable<Bool>;
	
	var connection:Promise<CallbackLink>;
	var requests = 0;
	public function connect():Promise<CallbackLink> {
		if(requests++ == 0) connection = getConnection();
		return connection.next(function(cnx):CallbackLink return function() if(--requests == 0) cnx.dissolve());
	}
	public function discoverServices():Promise<Array<Service>> throw 'abstract';
	function getConnection():Promise<CallbackLink> throw 'abstract';
}

interface PeripheralObject {
	var id(default, null):String;
	var mac(default, null):String;
	var connectable(default, null):Observable<Bool>;
	var rssi(default, null):Observable<Int>;
	var advertisement(default, null):Observable<Advertisement>;
	var connected(default, null):Observable<Bool>;
	
	function connect():Promise<CallbackLink>;
	function discoverServices():Promise<Array<Service>>;
}