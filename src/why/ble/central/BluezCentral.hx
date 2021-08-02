package why.ble.central;

import why.dbus.types.Variant;
import why.dbus.Signature;
import why.ble.RemoteValue;
import tink.Chunk;

using tink.CoreApi;

class BluezCentral implements Central {
	public final discovered:Signal<Peripheral>;
	public final gone:Signal<Peripheral>;
	final bluez:why.bluez.BlueZ;
	final adapter:Promise<why.bluez.Adapter>;
	
	public function new(bluez) {
		this.bluez = bluez;
		this.adapter = bluez.getAdapters().next(adapters -> switch adapters {
			case []: new Error('No adapter found');
			case v: v[0];
		});
		
		final peripherals = new Map<String, Peripheral>();
		
		function get(device:why.bluez.Device)
			return switch peripherals[device.uuid] {
				case null: peripherals[device.uuid] = new BluezPeripheral(device);
				case v: v;
			}
		
		discovered = new Signal(cb -> {
			function emit(device) cb(get(device));
			bluez.getDevices().handle(o -> switch o {
				case Success(devices): for(device in devices) emit(device);
				case Failure(e): trace(e);
			}) &
			bluez.deviceAdded.handle(emit);
		});
		
		gone = new Signal(cb -> {
			bluez.deviceRemoved.handle(device -> {
				final peripheral = get(device);
				peripherals.remove(device.uuid);
				cb(peripheral);
			});
		});
	}
	
	
	
	public function powered():Promise<Bool> {
		return adapter.next(a -> a.adapter.powered.get());
	}
	
	public function scanning():Promise<Bool> {
		return adapter.next(a -> a.adapter.discovering.get());
	}
	
	public function startScanning():Promise<Noise> {
		return adapter.next(a -> {
			bluez.getDevices()
				// .next(devices -> Promise.inParallel([for(device in devices) a.adapter.removeDevice(device.path)])) // start cleanly
				.next(_ -> a.adapter.setDiscoveryFilter(['RSSI' => new Variant(Int16, -120)])) // this disable the RSSI delta-threshold
				.next(_ -> a.adapter.startDiscovery());
		});
	}
	
	public function stopScanning():Promise<Noise> {
		return adapter.next(a -> a.adapter.stopDiscovery()); 
	}
}

class BluezPeripheral implements Peripheral {
	public final uuid:String;
	
	public final mac:RemoteReadableValue<String>;
	public final name:RemoteReadableValue<String>;
	public final uuids:RemoteReadableValue<Array<String>>;
	public final connected:RemoteReadableValue<Bool>;
	public final rssi:RemoteReadableValue<Int>;
	public final txPower:RemoteReadableValue<Int>;
	public final manufacturerData:RemoteReadableValue<Map<Int, Chunk>>;
	public final serviceData:RemoteReadableValue<Map<String, Chunk>>;
	public final servicesResolved:RemoteReadableValue<Bool>;
	public final advertisingFlags:RemoteReadableValue<Chunk>;
	public final advertisingData:RemoteReadableValue<Map<Int, Chunk>>;
	
	final device:why.bluez.Device;
	
	public function new(device) {
		this.device = device;
		this.uuid = device.uuid;
		
		mac = new BluezRemoteValue(cast device.device.address);
		name = new BluezRemoteValue(cast device.device.name);
		uuids = new BluezRemoteValue(cast device.device.uuids);
		connected = new BluezRemoteValue(cast device.device.connected);
		rssi = new BluezRemoteValue(cast device.device.rssi);
		txPower = new BluezRemoteValue(cast device.device.txPower);
		manufacturerData = new BluezRemoteValue(cast device.device.manufacturerData);
		serviceData = new BluezRemoteValue(cast device.device.serviceData);
		servicesResolved = new BluezRemoteValue(cast device.device.servicesResolved);
		advertisingFlags = new BluezRemoteValue(cast device.device.advertisingFlags);	
		advertisingData = new BluezRemoteValue(cast device.device.advertisingData);	
	}
	
	public function connect() {
		return device.device.connect();
	}
	
	public function disconnect() {
		return device.device.disconnect();
	}
	
	public function getServices() {
		return device.getServices().next(services -> services.map(s -> (new BluezService(s):Service)));
	}
}

class BluezService implements Service {
	public final uuid:String;
	final service:why.bluez.Service;
	
	public function new(service) {
		this.service = service;
		this.uuid = service.uuid;
	}
	
	public function getCharacteristics() {
		return service.getCharacteristics().next(chars -> chars.map(c -> (new BluezCharacteristic(c):Characteristic)));
	}
}

class BluezCharacteristic implements Characteristic {
	public final value:Signal<Chunk>;
	public final uuid:String;
	
	final characteristic:why.bluez.Characteristic;
	
	public function new(characteristic) {
		this.characteristic = characteristic;
		this.uuid = characteristic.uuid;
		this.value = new Signal(cb -> {
			final binding = characteristic.characteristic.value.changed.handle(cb);
			characteristic.characteristic.startNotify().eager();
			binding & () -> characteristic.characteristic.stopNotify().eager();
		});
	}
	
	public function write(chunk:Chunk, ?options:{?withoutResponse:Bool, ?offset:Int}):Promise<Noise> {
		return characteristic.characteristic.writeValue(chunk, [
			'offset' =>
				new Variant(UInt16, switch options {
					case null | {offset: null}: 0;
					case {offset: v}: v;
				}),
			'type' =>
				new Variant(String, switch options {
					case null | {withoutResponse: null | false}: 'command';
					case {withoutResponse: true}: 'request';
				}),
		]);
	}
	
	public function read(?options:{?offset:Int}):Promise<Chunk> {
		return characteristic.characteristic.readValue([
			'offset' =>
				new Variant(UInt16, switch options {
					case null | {offset: null}: 0;
					case {offset: v}: v;
				}),
		]);
	}
}

class BluezRemoteValue<T> implements RemoteValue.RemoteReadableValue<T> implements RemoteValue.RemoteWritableValue<T> {
	final property:why.dbus.client.Property<T>;
	
	public function new(property) {
		this.property = property;
	}
	
	public function get():Promise<RemoteValue<T>> {
		return property.get().next(v -> new Pair(v, property.changed));
	}
	
	public function set(v:T):Promise<Noise> {
		return property.set(v);
	}
}