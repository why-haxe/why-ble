package why.ble.centrals;

#if !react_native_ble_plx
	#error "Requires the react-native-ble-plx extern library"
#end

import why.ble.Central;
import why.ble.Peripheral;
import why.ble.Service;
import why.ble.Characteristic;
import haxe.crypto.Base64;
import react.native.ble_plx.BleManager as NativeManager;
import react.native.ble_plx.State as NativeState;
import react.native.ble_plx.Device as NativeDevice;
import react.native.ble_plx.Service as NativeService;
import react.native.ble_plx.Service as NativeService;
import react.native.ble_plx.Characteristic as NativeCharacteristic;
import react.native.ble_plx.BleError;
import tink.Chunk;
import tink.state.*;
import tink.core.ext.Subscription;

using tink.CoreApi;
using why.ble.centrals.ReactNativeCentral.Helper;

class ReactNativeCentral extends CentralBase {
	
	public static var inst(get, null):ReactNativeCentral;
	static function get_inst() {
		if(inst == null) inst = new ReactNativeCentral();
		return inst;
	}
	
	static var manager(get, null):NativeManager;
	static function get_manager() {
		if(manager == null) manager = new NativeManager();
		return manager;
	}
	
	function new() {
		super();
		
		manager.onStateChange(function(s) statusState.set(NativeTools.status(s)));
		
		manager.state().toTinkPromise()
			.handle(function(o) {
				switch o {
					case Success(state): statusState.set(NativeTools.status(state));
					case Failure(_):
				}
			});
	}
	
	override function startScan():Void {
		super.startScan();
		manager.startDeviceScan(null, null, function(err, device) {
			if(device != null) {
				switch peripherals.get(device.id) {
					case null:
						var peripheral = new ReactNativePeripheral(device);
						peripherals.set(device.id, peripheral);
					case (cast _:ReactNativePeripheral) => p:
						peripherals.refresh(device.id);
						p.update(device);
				}
			}
		});
	}
	
	override function stopScan():Void {
		super.stopScan();
		manager.stopDeviceScan();
	}
}

@:allow(why.ble.centrals)
private class ReactNativePeripheral extends PeripheralBase {
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
		
	} 
	
	override function getConnection():Promise<CallbackLink> {
		
		function whenConnected<T>(_:T):CallbackLink {
			connectedState.set(true);
			var listener = native.onDisconnected(function(_, _) connectedState.set(false));
			return function() {
				connectedState.set(false);
				native.cancelConnection();
				listener.remove();
			}
		}
		
		return native.isConnected().toTinkPromise()
			.next(function(connected) return {
				if(connected) whenConnected(null);
				else native.connect().toTinkPromise().next(whenConnected);
			});
	}
	
	override function discoverServices():Promise<Array<Service>> {
		return native.discoverAllServicesAndCharacteristics().toTinkPromise()
			.next(function(_) return native.services().toTinkPromise())
			.next(function(services):Array<Service> return [for(service in services) (new ReactNativeService(service):Service)]);
	}
	
	override public function requestConnectionPriority(priority:ConnectionPriority):Promise<Noise> {
		return Promise.ofJsPromise(native.requestConnectionPriority(priority));
	}
	
	function update(native:NativeDevice) {
		connectableState.set(native.isConnectable);
		rssiState.set(native.rssi);
		advertisementState.set(NativeTools.advertisement(native));
	}
	
}
private class ReactNativeService implements ServiceObject {
	
	public var uuid(default, null):Uuid;
	
	var native:NativeService;
	
	public function new(native) {
		this.native = native;
		this.uuid = native.uuid;
	} 
	
	public function discoverCharacteristics():Promise<Array<Characteristic>> {
		return native.characteristics().toTinkPromise()
			.next(function(characteristics):Array<Characteristic> return [for(characteristic in characteristics) (new ReactNativeCharacteristic(characteristic):Characteristic)]);
	}
	
}
private class ReactNativeCharacteristic implements CharacteristicObject {
	
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
		return native.read().toTinkPromise()
			.next(function(char):Chunk return Base64.decode(char.value));
	}
	
	public function write(data:Chunk, withoutResponse:Bool):Promise<Noise> {
		var payload = Base64.encode(data);
		return (withoutResponse ? native.writeWithoutResponse(payload) : native.writeWithResponse(payload)).toTinkPromise();
	}
	
	public function subscribe(handler:Callback<Chunk>):Subscription {
		var error = Future.trigger();
		
		var sub = native.monitor(function(err, char) {
			if(err != null)
				error.trigger(tink.core.Error.ofJsError(err))
			else
				handler.invoke(Base64.decode(char.value));
		});
		
		return new SimpleSubscription(sub.remove, error);
	}
	
}

class Helper {
	public static function toTinkError<T>(e:BleError):Error {
		return tink.core.Error.withData((e.errorCode:Int), e.message, e);
	}
	
	public static function toTinkPromise<T>(promise:js.Promise<T>):Promise<T> {
		return Future.async(function(cb) promise.then(function(a) cb(Success(a))).catchError(function(e:BleError) cb(Failure(e.toTinkError()))));
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

