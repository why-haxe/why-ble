package ble.centrals;

import ble.Central;
import tink.state.*;
import tink.Chunk;

import haxe.extern.EitherType;
import js.node.Buffer;
import js.node.events.EventEmitter;

using tink.CoreApi;

class NodeCentral implements Central {
	
	public var status(default, null):Observable<Status>;
	public var peripherals(default, null):ObservableMap<String, Peripheral>;
	public var discovered(default, null):Signal<Peripheral>;
	
	var trigger:SignalTrigger<Peripheral>;
	
	var noble:Noble;
	
	public function new() {
		
		noble = Noble.inst;
		
		var currentStatus = Unknown;
		status = new Observable(
			function() return currentStatus,
			Signal.generate(function(trigger) {
				noble.on('stateChange', function(s:String) {
					var status = switch s {
						case 'resetting': Resetting;
						case 'unsupported': Unsupported;
						case 'unauthorized': Unauthorized;
						case 'poweredOff': Off;
						case 'poweredOn': On;
						case _: Unknown;
					}
					if(currentStatus != status) {
						currentStatus = status;
						trigger(Noise);
					}
				});
			})
		);
		
		peripherals = new ObservableMap(new Map());
		discovered = Signal.generate(function(trigger) {
			noble.on('discover', function discover(native:NoblePeripheral) {
				switch peripherals.get(native.id) {
					case null:
						var peripheral = new NodePeripheral(native);
						peripherals.set(native.id, peripheral);
						trigger((peripheral:Peripheral));
					case (cast _:NodePeripheral) => p:
						p.update(native);
				}
			});
		});
	}
	
	public function startScan():Void {
		noble.startScanning([], true);
	}
	
	public function stopScan():Void {
		noble.stopScanning();
	}
	
	
}

@:allow(ble.centrals)
class NodePeripheral implements Peripheral.PeripheralObject {
	public var id(default, null):String;
	public var mac(default, null):String;
	public var connectable(default, null):Observable<Bool>;
	public var rssi(default, null):Observable<Int>;
	public var advertisement(default, null):Observable<Advertisement>;
	public var connected(default, null):Observable<Bool>;
	
	var connectableState:State<Bool>;
	var rssiState:State<Int>;
	var advertisementState:State<Advertisement>;
	
	var native:NoblePeripheral;
	
	public function new(native) {
		this.native = native;
		id = native.id;
		mac = native.address;
		
		connectable = connectableState = new State(native.connectable);
		rssi = rssiState = new State(native.rssi);
		advertisement = advertisementState = new State(AdvertisementTools.fromNative(native.advertisement));
		
		var connectedState = new State(false);
		connected = connectedState;
		native.on('connect', connectedState.set.bind(true));
		native.on('disconnect', connectedState.set.bind(false));
	}
	
	function update(native) {
		// this.native = native; // noble returns the same peripheral instance
		connectableState.set(native.connectable);
		rssiState.set(native.rssi);
		advertisementState.set(AdvertisementTools.fromNative(native.advertisement));
	}
	
	public function connect():Promise<Noise> {
		return Future.async(function(cb) {
			native.connect(function(err) {
				if(err != null) cb(Failure(Error.ofJsError(err)))
				else cb(Success(Noise));
			});
		});
	}
	
	public function disconnect():Promise<Noise> {
		return Future.async(function(cb) {
			native.disconnect(function(err) {
				if(err != null) cb(Failure(Error.ofJsError(err)))
				else cb(Success(Noise));
			});
		});
	}
	
	public function discoverServices():Promise<Array<Service>> {
		return Future.async(function(cb) {
			native.discoverServices([], function(err, services) {
				if(err != null) cb(Failure(Error.ofJsError(err)))
				else cb(Success([for(s in services) (new NodeService(s):Service)]));
			});
		});
	}
}

class NodeService implements Service {
	
	public var uuid(default, null):Uuid;
	
	var native:NobleService;
	
	public function new(native) {
		this.native = native;
		this.uuid = native.uuid;
	}
	
	public function discoverCharacteristics():Promise<Array<Characteristic>> {
		return Future.async(function(cb) {
			native.discoverCharacteristics([], function(err, characteristics) {
				if(err != null) cb(Failure(Error.ofJsError(err)))
				else cb(Success([for(c in characteristics) (new NodeCharacteristic(c):Characteristic)]));
			});
		}); 
	}
}

class NodeCharacteristic implements Characteristic {
	
	public var uuid(default, null):Uuid;
	
	var native:NobleCharacteristic;
	
	public function new(native) {
		this.native = native;
		this.uuid = native.uuid;
	}
	
	public function read():Promise<Chunk> {
		return Future.async(function(cb) {
			native.read(function(err, data) {
				if(err != null) cb(Failure(Error.ofJsError(err)))
				else cb(Success(chunkify(data)));
			});
		});
	}
	
	public function write(data:Chunk, withoutResponse:Bool):Promise<Noise> {
		return Future.async(function(cb) {
			native.write(data.toBuffer(), withoutResponse, function(err) {
				cb(err != null ? Failure(Error.ofJsError(err)) : Success(Noise));
			});
		});
	}
	
	public function subscribe(handler:Callback<Chunk>):Promise<CallbackLink> {
		return Future.async(function(cb) {
			native.subscribe(function(err) {
				if(err != null) cb(Failure(Error.ofJsError(err)))
				else {
					function callback(data, isNotification) handler.invoke(chunkify(data));
					native.on('data', callback);
					cb(Success(CallbackLink.join(
						(cast native.unsubscribe:Void->Void),
						native.removeListener.bind('data', callback)
					)));
				}
			});
		});
	}
	
	function chunkify(data:EitherType<String, Buffer>) {
		return Std.is(data, String) ? Chunk.ofString(data) : Chunk.ofBuffer(data);
	}
}

private class AdvertisementTools {
	public static function fromNative(native:NobleAdvertisement):Advertisement {
		return {
			localName: native.localName,
			txPowerLevel: native.txPowerLevel,
			serviceUuids: native.serviceUuids,
			serviceSolicitationUuid: native.serviceSolicitationUuid,
			manufacturerData: native.manufacturerData == null ? Chunk.EMPTY : native.manufacturerData,
			serviceData: [for(s in native.serviceData) {uuid: s.uuid, data: s.data}],
		}
	}
}

// Externs for the npm package "noble"

@:jsRequire('noble')
extern class Noble extends EventEmitter<Noble> {
	static var inst(get, never):Noble;
	static inline function get_inst():Noble return js.Lib.require('noble');
	
	function startScanning(?filter:Array<String>, ?allowDuplicates:Bool):Void;
	function stopScanning():Void;
}

extern class NoblePeripheral extends EventEmitter<NoblePeripheral> {
	var id:String;
	var address:String;
	var addressType:String;
	var connectable:Bool;
	var advertisement:NobleAdvertisement;
	var rssi:Int;
	function connect(callback:js.Error->Void):Void;
	function disconnect(callback:js.Error->Void):Void;
	function discoverAllServicesAndCharacteristics(sFilter:Array<String>, cFilter:Array<String>, callback:js.Error->Array<NobleService>->Array<NobleCharacteristic>->Void):Void;
	function discoverServices(filter:Array<String>, callback:js.Error->Array<NobleService>->Void):Void;
}

extern class NobleService extends EventEmitter<NobleService> {
	var uuid:String;
	function discoverCharacteristics(filter:Array<String>, callback:js.Error->Array<NobleCharacteristic>->Void):Void;
	
}

extern class NobleCharacteristic extends EventEmitter<NobleCharacteristic> {
	var uuid:String;
	function subscribe(?callback:js.Error->Void):Void;
	function unsubscribe(?callback:js.Error->Void):Void;
	function write(data:Buffer, withoutResponse:Bool, ?callback:js.Error->Void):Void;
	function read(?callback:js.Error->EitherType<String, Buffer>->Void):Void;
	function discoverDescriptors(?callback:js.Error->Array<NobleDescriptor>->Void):Void;
	
}

extern class NobleDescriptor extends EventEmitter<NobleDescriptor> {
	var uuid:String;
	function writeValue(data:Buffer, ?callback:js.Error->Void):Void;
	function readValue(?callback:js.Error->Buffer->Void):Void;
	
}

typedef NobleAdvertisement = {
	localName:String,
	txPowerLevel:Int,
	serviceUuids:Array<String>,
	serviceSolicitationUuid:Array<String>,
	manufacturerData:Buffer,
	serviceData:Array<{uuid:String, data:Buffer}>,
}