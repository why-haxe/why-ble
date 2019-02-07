package ble.centrals;

import ble.Central;
import ble.Peripheral;
import ble.Characteristic;
import ble.Service;
import tink.state.*;
import tink.Chunk;

import haxe.extern.EitherType;
import js.node.Buffer;
import js.node.events.EventEmitter;

using tink.CoreApi;

class NodeCentral extends CentralBase {
	
	var trigger:SignalTrigger<Peripheral>;
	
	var noble:Noble;
	
	public function new() {
		
		super();
		
		noble = Noble.inst;
		noble.on('stateChange', function(s:String) {
			statusState.set(NativeTools.status(s));
		});
		
		noble.on('discover', function discover(native:NoblePeripheral) {
			// WORKAROUND for rpi3
			// https://github.com/noble/noble/issues/223
			if(Sys.systemName() == 'Linux') {
				native.removeListener('connect', startScan);
				native.on('connect', startScan);
			}
			
			switch peripherals.get(native.id) {
				case null:
					var peripheral = new NodePeripheral(native);
					peripherals.set(native.id, peripheral);
					discoveredTrigger.trigger((peripheral:Peripheral));
				case (cast _:NodePeripheral) => p:
					p.update(native);
			}
		});
	}
	
	override function startScan():Void {
		noble.startScanning([], true);
	}
	
	override function stopScan():Void {
		noble.stopScanning();
	}
	
	
}

@:allow(ble.centrals)
class NodePeripheral implements PeripheralObject {
	public var id(default, null):String;
	public var mac(default, null):String;
	public var connectable(default, null):Observable<Bool>;
	public var rssi(default, null):Observable<Int>;
	public var advertisement(default, null):Observable<Advertisement>;
	public var connected(default, null):Observable<Bool>;
	
	var connectableState:State<Bool>;
	var connectedState:State<Bool>;
	var rssiState:State<Int>;
	var advertisementState:State<Advertisement>;
	
	var native:NoblePeripheral;
	var binding:CallbackLink;
	
	public function new(native) {
		this.native = native;
		id = native.id;
		mac = native.address;
		
		connectable = connectableState = new State(native.connectable);
		rssi = rssiState = new State(native.rssi);
		advertisement = advertisementState = new State(NativeTools.advertisement(native.advertisement));
		connected = connectedState = new State(false);
		
		listen();
	}
	
	function update(native) {
		this.native = native;
		connectableState.set(native.connectable);
		rssiState.set(native.rssi);
		advertisementState.set(NativeTools.advertisement(native.advertisement));
		
		binding.dissolve();
		listen();
	}
	
	function listen() {
		native.on('connect', function onConnect() connectedState.set(true));
		native.on('disconnect', function onDisconnect() connectedState.set(false));
		binding = [
			native.removeListener.bind('connect', onConnect),
			native.removeListener.bind('disconnect', onDisconnect),
		];
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

class NodeService implements ServiceObject {
	
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

class NodeCharacteristic implements CharacteristicObject {
	
	public var uuid(default, null):Uuid;
	public var properties(default, null):Iterable<Characteristic.Property>;
	
	var native:NobleCharacteristic;
	
	public function new(native) {
		this.native = native;
		this.uuid = native.uuid;
		this.properties = native.properties.map(NativeTools.property);
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
	
	public function subscribe(handler:Callback<Outcome<Chunk, Error>>):CallbackLink {
		native.on('data', function onData(data, isNotification) handler.invoke(Success(chunkify(data))));
		native.on('error', function onError(err) handler.invoke(Failure(Error.ofJsError(err))));
		native.subscribe(function(err) if(err != null) onError(err));

		return [
			(cast native.unsubscribe:Void->Void),
			native.removeListener.bind('data', onData),
			native.removeListener.bind('error', onError),
		];
	}
	
	function chunkify(data:EitherType<String, Buffer>) {
		return Std.is(data, String) ? Chunk.ofString(data) : Chunk.ofBuffer(data);
	}
	
}

private class NativeTools {
	public static function advertisement(native:NobleAdvertisement):Advertisement {
		return {
			localName: native.localName,
			txPowerLevel: native.txPowerLevel,
			serviceUuids: native.serviceUuids,
			serviceSolicitationUuid: native.serviceSolicitationUuid,
			manufacturerData: native.manufacturerData == null ? Chunk.EMPTY : native.manufacturerData,
			serviceData: [for(s in native.serviceData) {uuid: s.uuid, data: s.data}],
		}
	}
	
	public static function property(v:String):Property {
		return switch v {
			case 'broadcast': Broadcast;
			case 'read': Read;
			case 'writeWithoutResponse': WriteWithoutResponse;
			case 'write': Write;
			case 'notify': Notify;
			case 'indicate': Indicate;
			case 'authenticatedSignedWrites': AuthenticatedSignedWrites;
			case 'extendedProperties': ExtendedProperties;
			case _: Unknown(v);
		}
	}
	
	public static inline function status(s:String):Status {
		return switch s {
			case 'resetting': Resetting;
			case 'unsupported': Unsupported;
			case 'unauthorized': Unauthorized;
			case 'poweredOff': Off;
			case 'poweredOn': On;
			case _: Unknown;
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
	var properties:Array<String>;
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