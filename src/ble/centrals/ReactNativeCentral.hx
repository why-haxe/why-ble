package ble.centrals;

import ble.Central;
import ble.Peripheral;
import ble.Service;
import ble.Characteristic;
import haxe.crypto.Base64;
import react.native.ble_plx.BleManager as NativeManager;
import react.native.ble_plx.State as NativeState;
import react.native.ble_plx.Device as NativeDevice;
import react.native.ble_plx.Service as NativeService;
import react.native.ble_plx.Service as NativeService;
import react.native.ble_plx.Characteristic as NativeCharacteristic;
import tink.Chunk;
import tink.state.*;

using tink.CoreApi;

class ReactNativeCentral extends CentralBase {
	
	
	static var manager(get, null):NativeManager;
	static function get_manager() {
		if(manager == null) manager = new NativeManager();
		return manager;
	}
	
	public function new() {
		super();
		Promise.ofJsPromise(manager.state())
			.handle(function(o) {
				switch o {
					case Success(state): statusState.set(NativeTools.status(state));
					case Failure(_):
				}
				manager.onStateChange(function(s:NativeState) statusState.set(NativeTools.status(s)));
			});
	}
	
	override function startScan():Void {
		manager.startDeviceScan(null, null, function(err, device) {
			if(device != null) {
				switch peripherals.get(device.id) {
					case null:
						var peripheral = new ReactNativePeripheral(device);
						peripherals.set(device.id, peripheral);
						discoveredTrigger.trigger(peripheral);
					case (cast _:ReactNativePeripheral) => p:
						p.update(device);
				}
			}
		});
	}
	
	override function stopScan():Void {
		manager.stopDeviceScan();
	}
}

@:allow(ble.centrals)
class ReactNativePeripheral implements PeripheralObject {
	public var id(default, null):String;
	public var mac(default, null):String;
	public var connectable(default, null):Observable<Bool>;
	public var rssi(default, null):Observable<Int>;
	public var advertisement(default, null):Observable<Advertisement>;
	public var connected(default, null):Observable<Bool>;
	
	var native:NativeDevice;
	var connectableState:State<Bool>;
	var connectedState:State<Bool>;
	var rssiState:State<Int>;
	var advertisementState:State<Advertisement>;
	
	public function new(native) {
		this.native = native;
		this.id = native.id;
		this.mac = native.id;
		connectable = connectableState = new State(native.isConnectable);
		connected = connectedState = new State(false);
		rssi = rssiState = new State(native.rssi);
		advertisement = advertisementState = new State(NativeTools.advertisement(native));
		
		native.onDisconnected(function(_, _) connectedState.set(false));
	} 
	
	
	public function connect():Promise<Noise> {
		var promise = Promise.ofJsPromise(native.connect());
		promise.handle(function(o) {
			trace(o);
			if(o.isSuccess()) connectedState.set(true);
		});
		return promise;
	}
	
	public function disconnect():Promise<Noise> {
		return Promise.ofJsPromise(native.cancelConnection());
	}
	
	public function discoverServices():Promise<Array<Service>> {
		return Promise.ofJsPromise(native.discoverAllServicesAndCharacteristics())
			.next(function(_) return native.services())
			.next(function(services):Array<Service> return [for(service in services) (new ReactNativeService(service):Service)]);
	}
	
	function update(native:NativeDevice) {
		connectableState.set(native.isConnectable);
		rssiState.set(native.rssi);
		advertisementState.set(NativeTools.advertisement(native));
	}
	
}
class ReactNativeService implements ServiceObject {
	
	public var uuid(default, null):Uuid;
	
	var native:NativeService;
	
	public function new(native) {
		this.native = native;
		this.uuid = native.uuid;
	} 
	
	public function discoverCharacteristics():Promise<Array<Characteristic>> {
		return Promise.ofJsPromise(native.characteristics())
			.next(function(characteristics):Array<Characteristic> return [for(characteristic in characteristics) (new ReactNativeCharacteristic(characteristic):Characteristic)]);
	}
	
}
class ReactNativeCharacteristic implements CharacteristicObject {
	
	public var uuid(default, null):Uuid;
	public var properties(default, null):Iterable<Property>;
	
	var native:NativeCharacteristic;
	
	public function new(native) {
		this.native = native;
		this.uuid = native.uuid;
		
		var props = [];
		if(native.isReadable) props.push(Read);
		if(native.isWritableWithResponse) props.push(Write);
		if(native.isWritableWithoutResponse) props.push(WriteWithoutResponse);
		if(native.isNotifiable) props.push(Notify);
		if(native.isIndicatable) props.push(Indicate);
		properties = props;
	}
	
	public function read():Promise<Chunk> {
		return Promise.ofJsPromise(native.read())
			.next(function(char):Chunk return Base64.decode(char.value));
	}
	
	public function write(data:Chunk, withoutResponse:Bool):Promise<Noise> {
		return Promise.ofJsPromise((withoutResponse ? native.writeWithoutResponse : native.writeWithResponse)(Base64.encode(data)));
	}
	
	public function subscribe(handler:Callback<Outcome<Chunk, Error>>):CallbackLink {
		return native.monitor(function(err, char) handler.invoke(err != null ? Failure(Error.ofJsError(err)) : Success(Base64.decode(char.value)))).remove;
	}
	
}

private class NativeTools {
	public static function advertisement(native:NativeDevice):Advertisement {
		return {
			localName: native.localName,
			txPowerLevel: native.txPowerLevel,
			serviceUuids: native.serviceUUIDs,
			serviceSolicitationUuid: native.solicitedServiceUUIDs,
			manufacturerData: native.manufacturerData == null ? Chunk.EMPTY : Base64.decode(native.manufacturerData),
			serviceData: [for(uuid in native.serviceData.keys()) {uuid: uuid, data: Base64.decode(native.serviceData[uuid])}],
		}
	}
	
	
	
	public static function status(status:NativeState):Status {
		return switch status {
			case Unknown: Unknown;
			case Resetting: Resetting;
			case Unsupported: Unsupported;
			case Unauthorized: Unauthorized;
			case PoweredOff: Off;
			case PoweredOn: On;
		}
	}
}

