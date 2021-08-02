package why.ble.peripheral;

import js.html.CharacterData;
import tink.Chunk;
import why.dbus.server.Property;
import why.dbus.types.*;
import why.dbus.Signature;

using why.ble.peripheral.BluezPeripheral.CharacteristicPropertyTools;
using StringTools;
using tink.CoreApi;

class BluezPeripheral implements Peripheral {
	static final APPLICATION_PATH = '/why/ble/Application';
	static final ADVERTISEMENT_PATH = '/why/ble/Advertisement';
	
	final bluez:why.bluez.BlueZ;
	final application:Application;
	final adapter:Promise<why.bluez.Adapter>;
	
	var bindings:CallbackLink;
	
	public function new(bluez, application) {
		this.bluez = bluez;
		this.application = application;
		this.adapter = bluez.getAdapters().next(adapters -> switch adapters {
			case []: new Error('No adapter found');
			case v: v[0];
		});
	}
	
	public function startAdvertising(advertisement:Advertisement):Promise<Noise> {
		bindings = {
			final links = [
				bluez.cnx.exportObject(ADVERTISEMENT_PATH, (new BluezAdvertisement(advertisement, application, () -> {trace('release'); Promise.NOISE;}):org.bluez.LEAdvertisement1), (new EmptyObjectManager():org.freedesktop.DBus.ObjectManager)),
				bluez.cnx.exportObject(APPLICATION_PATH, (new BluezApplication(application):org.freedesktop.DBus.ObjectManager)),
			];
			
			for(service in application.services) {
				final servicePath = '/why/ble/Service_${service.uuid.replace('-', '')}';
				links.push(bluez.cnx.exportObject(servicePath, (new BluezService(service):org.bluez.GattService1)));
				
				for(characteristic in service.characteristics) {
					final characteristicPath = '$servicePath/Characteristic_${characteristic.uuid.replace('-', '')}';
					links.push(bluez.cnx.exportObject(characteristicPath, (new BluezCharacteristic(characteristic):org.bluez.GattCharacteristic1)));
				}
			}
			
			links;
		}
		
		
		return adapter.next(a -> {
			Promise.inParallel([
				a.gattManager.registerApplication(APPLICATION_PATH, []),
				a.leAdvertisingManager.registerAdvertisement(ADVERTISEMENT_PATH, []),
			]);
		});
	}
	
	public function stopAdvertising():Promise<Noise> {
		bindings.cancel();
		return adapter.next(a -> {
			Promise.inParallel([
				a.gattManager.unregisterApplication(APPLICATION_PATH),
				a.leAdvertisingManager.unregisterAdvertisement(ADVERTISEMENT_PATH),
			]);
		});
	}
}















class BluezAdvertisement implements why.dbus.server.Interface<org.bluez.LEAdvertisement1> {

	public final type:ReadableProperty<String>;
	public final serviceUuids:ReadableProperty<Array<String>>;
	public final manufacturerData:ReadableProperty<Map<UInt16, Variant>>;
	public final solicitUuids:ReadableProperty<Array<String>>;
	public final serviceData:ReadableProperty<Map<String, Variant>>;
	public final data:ReadableProperty<Map<UInt8, Variant>>;
	public final discoverable:ReadableProperty<Bool>;
	public final discoverableTimeout:ReadableProperty<UInt16>;
	public final includes:ReadableProperty<Array<String>>;
	public final localName:ReadableProperty<String>;
	public final appearance:ReadableProperty<UInt16>;
	public final duration:ReadableProperty<UInt16>;
	public final timeout:ReadableProperty<UInt16>;
	public final secondaryChannel:ReadableProperty<String>;
	public final minInterval:ReadableProperty<UInt>;
	public final maxInterval:ReadableProperty<UInt>;
	public final txPower:ReadableProperty<Int16>;
	
	final onRelease:()->Promise<Noise>;
	
	public function new(advertisement:Advertisement, application:Application, onRelease) {
		this.onRelease = onRelease;
		type = new SimpleProperty('peripheral');
		serviceUuids = new SimpleProperty(application.services.map(s -> s.uuid));
		manufacturerData = new SimpleProperty(new Map());
		solicitUuids = new SimpleProperty([]);
		serviceData = new SimpleProperty(new Map());
		data = new SimpleProperty(new Map());
		discoverable = new SimpleProperty(true);
		discoverableTimeout = new SimpleProperty(0);
		includes = new SimpleProperty([]);
		localName = new SimpleProperty(advertisement.localName);
		appearance = new SimpleProperty(0);
		duration = new SimpleProperty(300);
		timeout = new SimpleProperty(0);
		secondaryChannel = new SimpleProperty('1M');
		minInterval = new SimpleProperty(2000);
		maxInterval = new SimpleProperty(4000);
		txPower = new SimpleProperty(0);
	}
	
	public function release():Promise<Noise> {
		return onRelease();
	}
}

class EmptyObjectManager implements why.dbus.server.Interface<org.freedesktop.DBus.ObjectManager> {
	
	public final interfacesAdded = Signal.trigger();
	public final interfacesRemoved = Signal.trigger();
	
	public function new() {}

	public function getManagedObjects():tink.core.Promise<Map<ObjectPath, Map<String, Map<String, Variant>>>> {
		return Promise.resolve(new Map<ObjectPath, Map<String, Map<String, Variant>>>());
	}
}

class BluezApplication implements why.dbus.server.Interface<org.freedesktop.DBus.ObjectManager> {

	public final interfacesAdded:why.dbus.server.Signal<ObjectPath, Map<String, Map<String, Variant>>>;
	public final interfacesRemoved:why.dbus.server.Signal<ObjectPath, Array<String>>;
	
	final application:Application;
	
	public function new(application) {
		this.application = application;
		interfacesAdded = tink.core.Signal.trigger();
		interfacesRemoved = tink.core.Signal.trigger();
	}
	
	public function getManagedObjects():Promise<Map<ObjectPath, Map<String, Map<String, Variant>>>> {
		final map = new Map();
		
		for(service in application.services) {
			final servicePath = '/why/ble/Service_${service.uuid.replace('-', '')}';
			final characteristicPaths = [];
			
			map[servicePath] = [
				'org.bluez.GattService1' => [
					'UUID' => new Variant(String, service.uuid),
					'Primary' => new Variant(Boolean, service.primary),
					'Characteristics' => new Variant(Array(ObjectPath), characteristicPaths),
				],
			];
			
			for(characteristic in service.characteristics) {
				final characteristicPath = '$servicePath/Characteristic_${characteristic.uuid.replace('-', '')}';
				characteristicPaths.push(characteristicPath);
				
				map[characteristicPath] = [
					'org.bluez.GattCharacteristic1' => [
						'Service' => new Variant(ObjectPath, servicePath),
						'UUID' => new Variant(String, characteristic.uuid),
						'Flags' => new Variant(Array(String), characteristic.properties.map(CharacteristicPropertyTools.toNativeValue)),
						'Descriptors' => new Variant(Array(ObjectPath), []),
					],
				];
			}
		}
		
		return Promise.resolve(map);
	}
}

class BluezService implements why.dbus.server.Interface<org.bluez.GattService1> {
	public final uuid:ReadableProperty<String>;
	public final primary:ReadableProperty<Bool>;
	public final device:ReadableProperty<ObjectPath>;
	public final includes:ReadableProperty<Array<ObjectPath>>;
	public final handle:ReadWriteProperty<UInt16>;
	
	final service:Service;
	
	public function new(service) {
		this.service = service;
		uuid = new SimpleProperty(service.uuid);
		primary = new SimpleProperty(service.primary);
		device = new SimpleProperty(null);
		includes = new SimpleProperty([]);
		handle = new SimpleProperty(0);
	}
}

class BluezCharacteristic implements why.dbus.server.Interface<org.bluez.GattCharacteristic1> {
	public final uuid:ReadableProperty<String>;
	public final service:ReadableProperty<ObjectPath>;
	public final value:ReadableProperty<Chunk>;
	public final writeAcquired:ReadableProperty<Bool>;
	public final notifyAcquired:ReadableProperty<Bool>;
	public final notifying:ReadableProperty<Bool>;
	public final flags:ReadableProperty<Array<String>>;
	public final handle:ReadWriteProperty<UInt16>;
	
	final characteristic:Characteristic;
	
	public function new(characteristic) {
		this.characteristic = characteristic;
		uuid = new SimpleProperty(characteristic.uuid);
		service = new SimpleProperty(null);
		value = new ClassicProperty(() -> throw 'TODO: BluezCharacteristic.value.get', v -> throw 'TODO: BluezCharacteristic.value.set');
		writeAcquired = new SimpleProperty(false);
		notifyAcquired = new SimpleProperty(false);
		notifying = new SimpleProperty(false);
		flags = new SimpleProperty([]);
		handle = new SimpleProperty(0);
	}

	public function readValue(options:Map<String, Variant>):tink.core.Promise<Chunk> {
		return characteristic.read({
			offset:
				switch options['offset'] {
					case null: 0;
					case variant: variant.value;
				},
		});
	}

	public function writeValue(value:Chunk, options:Map<String, Variant>):tink.core.Promise<tink.core.Noise> {
		return characteristic.write(value, {
			withoutResponse:
				switch options['type'] {
					case null: false;
					case variant: variant.value == 'command';
				},
			offset:
				switch options['offset'] {
					case null: 0;
					case variant: variant.value;
				},
		});
	}

	public function startNotify():tink.core.Promise<tink.core.Noise> {
		throw new haxe.exceptions.NotImplementedException();
	}

	public function stopNotify():tink.core.Promise<tink.core.Noise> {
		throw new haxe.exceptions.NotImplementedException();
	}
}













class CharacteristicPropertyTools {
	public static function toNativeValue(property:CharacteristicProperty):String {
		return switch property {
			case Broadcast: 'broadcast';
			case Read: 'read';
			case WriteWithoutResponse: 'write-without-response';
			case Write: 'write';
			case Notify: 'notify';
			case Indicate: 'indicate';
			case AuthenticatedSignedWrites: 'authenticated-signed-writes';
			case ExtendedProperties: 'extended-properties';
			case ReliableWrite: 'reliable-write';
			case WritableAuxiliaries: 'writable-auxiliaries';
			case EncryptRead: 'encrypt-read';
			case EncryptWrite: 'encrypt-write';
			case EncryptAuthenticatedRead: 'encrypt-authenticated-read';
			case EncryptAuthenticatedWrite: 'encrypt-authenticated-write';
			case SecureRead: 'secure-read';
			case SecureWrite: 'secure-write';
			case Authorize: 'authorize';
		}
	}
}