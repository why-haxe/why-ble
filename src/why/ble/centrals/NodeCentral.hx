package why.ble.centrals;

import why.ble.Central;
import why.ble.Peripheral;
import why.ble.Characteristic;
import why.ble.Service;
import tink.state.*;
import tink.core.ext.Subscription;
import tink.Chunk;
import haxe.extern.EitherType;
import js.node.Buffer;
import js.node.events.EventEmitter;
import js.lib.Error as JsError;

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
			if (Sys.systemName() == 'Linux') {
				native.removeListener('connect', startScan);
				native.on('connect', startScan);
			}

			// switch peripherals.get(native.id) {
			// 	case null:
			// 		var peripheral = new NodePeripheral(native);
			// 		peripherals.set(native.id, peripheral);
			// 	case(cast _ : NodePeripheral) => p:
			// 		peripherals.refresh(native.id);
			// 		p.update(native);
			// }
		});
	}

	override function startScan():Void {
		super.startScan();
		noble.startScanning([], true);
	}

	override function stopScan():Void {
		super.stopScan();
		noble.stopScanning();
	}
}

@:allow(why.ble.centrals)
class NodePeripheral extends PeripheralBase {
	var native:NoblePeripheral;
	var binding:CallbackLink;
	var connectableState:State<Bool>;
	var connectedState:State<Bool>;
	var rssiState:State<Int>;
	var advertisementState:State<Advertisement>;

	public function new(native) {
		this.native = native;
		id = native.id;
		mac = native.address;

		connectable = connectableState = new State(native.connectable);
		connected = connectedState = new State(false);
		rssi = rssiState = new State(native.rssi);
		advertisement = advertisementState = new State(NativeTools.advertisement(native.advertisement));

		listen();
	}

	function update(native) {
		var changed = this.native != native;
		this.native = native;
		connectableState.set(native.connectable);
		rssiState.set(native.rssi);
		advertisementState.set(NativeTools.advertisement(native.advertisement));

		if (changed) {
			binding.dissolve();
			listen();
		}
	}

	function listen() {
		var target = native;

		target.on('connect', function onConnect()
			connectedState.set(true));
		target.on('disconnect', function onDisconnect()
			connectedState.set(false));

		binding = function() {
			target.removeListener('connect', onConnect);
			target.removeListener('disconnect', onDisconnect);
		}
	}

	override function dispose():Void {
		native = null;
		connectableState = null;
		connectedState = null;
		rssiState = null;
		advertisementState = null;
		binding.cancel();
		binding = null;
		super.dispose();
	}

	override function getConnection():Promise<CallbackLink> {
		return Future.async(function(cb) {
			native.connect(function(err) {
				if (err != null)
					cb(Failure(Error.ofJsError(err)))
				else
					cb(Success((function() native.disconnect():CallbackLink)));
			});
		});
	}

	override function discoverServices():Promise<Array<Service>> {
		return Future.async(function(cb) {
			native.discoverServices([], function(err, services) {
				if (err != null)
					cb(Failure(Error.ofJsError(err)))
				else
					cb(Success([for (s in services) (new NodeService(s) : Service)]));
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
				if (err != null)
					cb(Failure(Error.ofJsError(err)))
				else
					cb(Success([for (c in characteristics) (new NodeCharacteristic(c) : Characteristic)]));
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
				if (err != null)
					cb(Failure(Error.ofJsError(err)))
				else
					cb(Success(chunkify(data)));
			});
		});
	}

	public function write(data:Chunk, withoutResponse:Bool):Promise<Noise> {
		final key = StringTools.lpad(StringTools.hex(Std.random(1 << 28), 6), '0', 6);
		return new Future(cb -> {
			Sys.println('${Date.now().toString()}: $key: reg');
			native.once('write', function onWrite(err) {
				Sys.println('${Date.now().toString()}: $key: fired');
				cb(err != null ? Failure(Error.ofJsError(err)) : Success(Noise));
			});
			native.write(data.toBuffer(), withoutResponse);
			() -> {
				Sys.println('${Date.now().toString()}: $key: unreg');
				native.removeListener('write', onWrite);
			}
		});
	}

	public function subscribe(handler:Callback<Chunk>):Subscription {
		var error = Signal.trigger();

		native.on('data', function onData(data, isNotification)
			handler.invoke(chunkify(data)));
		native.on('error', function onError(err)
			error.trigger(Error.ofJsError(err)));
		native.subscribe(function(err) if (err != null)
			onError(err));

		return new SimpleSubscription([
			(cast native.unsubscribe : Void->Void),
			native.removeListener.bind('data', onData),
			native.removeListener.bind('error', onError),
		], error);
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
			serviceData: if (native.serviceData == null) [] else [
				for (s in native.serviceData) {
					{
						uuid: s.uuid,
						data: s.data
					}
				}
			],
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
// @:jsRequire('@abandonware/noble')
extern class Noble extends EventEmitter<Noble> {
	static var inst(get, never):Noble;
	static inline function get_inst():Noble
		return js.Lib.require('@abandonware/noble');

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
	function connect(callback:JsError->Void):Void;
	function disconnect(?callback:JsError->Void):Void;
	function discoverAllServicesAndCharacteristics(sFilter:Array<String>, cFilter:Array<String>,
		callback:JsError->Array<NobleService>->Array<NobleCharacteristic>->Void):Void;
	function discoverServices(filter:Array<String>, callback:JsError->Array<NobleService>->Void):Void;
}

extern class NobleService extends EventEmitter<NobleService> {
	var uuid:String;
	function discoverCharacteristics(filter:Array<String>, callback:JsError->Array<NobleCharacteristic>->Void):Void;
}

extern class NobleCharacteristic extends EventEmitter<NobleCharacteristic> {
	var uuid:String;
	var properties:Array<String>;
	function subscribe(?callback:JsError->Void):Void;
	function unsubscribe(?callback:JsError->Void):Void;
	function write(data:Buffer, withoutResponse:Bool, ?callback:JsError->Void):Void;
	function read(?callback:JsError->EitherType<String, Buffer>->Void):Void;
	function discoverDescriptors(?callback:JsError->Array<NobleDescriptor>->Void):Void;
}

extern class NobleDescriptor extends EventEmitter<NobleDescriptor> {
	var uuid:String;
	function writeValue(data:Buffer, ?callback:JsError->Void):Void;
	function readValue(?callback:JsError->Buffer->Void):Void;
}

typedef NobleAdvertisement = {
	localName:String,
	txPowerLevel:Int,
	serviceUuids:Array<String>,
	serviceSolicitationUuid:Array<String>,
	manufacturerData:Buffer,
	serviceData:Array<{uuid:String, data:Buffer}>,
}
