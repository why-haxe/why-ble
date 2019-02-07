package ble;

import tink.state.*;

using tink.CoreApi;

@:forward
abstract Central(CentralObject) from CentralObject to CentralObject {
	public inline function find(filter:Peripheral->Bool):Future<Peripheral> {
		return this.advertisements.nextTime(filter);
	}
}

class CentralBase implements CentralObject {
	
	public var status(default, null):Observable<Status>;
	public var peripherals(default, null):ObservableMap<String, Peripheral>;
	public var advertisements(default, null):Signal<Peripheral>;
	public var discovered(default, null):Signal<Peripheral>;
	
	var statusState:State<Status>;
	var discoveredTrigger:SignalTrigger<Peripheral>;
	
	function new() {
		
		status = statusState = new State<Status>(Unknown);
		peripherals = new ObservableMap(new Map());
		
		advertisements = Signal.generate(function(trigger) {
			var bindings:CallbackLink = null;
			peripherals.observableValues.bind(null, function(list) {
				bindings.dissolve();
				bindings = [for(peripheral in list) peripheral.advertisement.bind(null, function(_) trigger(peripheral))];
			});
		});
		discovered = discoveredTrigger = Signal.trigger();
	}
	
	
	public function startScan():Void throw 'abstract';
	public function stopScan():Void throw 'abstract';
}

interface CentralObject {
	var status(default, null):Observable<Status>;
	var peripherals(default, null):ObservableMap<String, Peripheral>;
	var advertisements(default, null):Signal<Peripheral>;
	var discovered(default, null):Signal<Peripheral>;
	function startScan():Void;
	function stopScan():Void;
}


enum Status {
	Unknown;
	Unsupported;
	Unauthorized;
	Resetting;
	On;
	Off;
}