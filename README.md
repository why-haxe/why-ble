# Why BLE (Bluetooth Low Energy)

Abstraction of BLE API.

Currently only supports BLE Central. BLE Peripheral support might be added later.

## Interface

A quick glance:

```haxe
interface Central {
	var status(default, null):Observable<Status>;
	var peripherals(default, null):Peripherals;
	var advertisements(default, null):Signal<Peripheral>;
	function startScan():Void;
	function stopScan():Void;
}

interface Peripheral {
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

interface Service {
	var uuid(default, null):Uuid;
	function discoverCharacteristics():Promise<Array<Characteristic>>;
}

interface Characteristic {
	var uuid(default, null):Uuid;
	var properties(default, null):Iterable<Property>;
	function read():Promise<Chunk>;
	function write(data:Chunk, withoutResponse:Bool):Promise<Noise>;
	function subscribe(handler:Callback<Outcome<Chunk, Error>>):CallbackLink;
	function discoverDescriptors():Promise<Array<Descriptor>>;
}
```


## Usage Example

```haxe
var central:Central = /* ... pick one implementation */

// start scanning for BLE peripherals when the bluetooth hardware is ready
central.status.nextTime(status -> status == On).handle(central.startScan);

// register a listener for newly discovered peripherals
central.peripherals.discovered.handle(peripheral -> {
	trace(peripheral.id);
	
	// connect to the peripheral before we can perform further actions
	peripheral.connect().handle(o -> switch o {
		case Failure(e): trace('Unable to connect');
		case Success(_):
			// discover services
			periperal.discoverServices()
				.handle(o -> switch o {
					case Success(services): trace(services);
					case Failure(e): trace(e);
				});
			
			// read from a characteristic
			// note: `findCharacteristic` is a short hand for `discoverServices` + `discoverCharacteristics` with filtering
			periperal.findCharacteristic(char -> char.id == READ_CHARACTERISTIC_UUID)
				.next(char -> char.read())
				.handle(o -> switch o {
					case Success(chunk): trace(chunk);
					case Failure(e): trace(e);
				});
			
			// write to a characteristic
			periperal.findCharacteristic(char -> char.id == WRITE_CHARACTERISTIC_UUID)
				.next(char -> char.write('my-value', true))
				.handle(o -> switch o {
					case Success(_): trace('Successfully written');
					case Failure(e): trace(e);
				});
	});
});
```