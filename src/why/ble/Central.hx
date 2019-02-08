package why.ble;

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
	public var peripherals(default, null):Peripherals;
	public var advertisements(default, null):Signal<Peripheral>;
	
	var statusState:State<Status>;
	
	function new() {
		
		status = statusState = new State<Status>(Unknown);
		peripherals = new Peripherals();
		
		advertisements = Signal.generate(function(trigger) {
			var bindings:CallbackLink = null;
			peripherals.observableValues.bind(null, function(list) {
				bindings.dissolve();
				bindings = [for(peripheral in list) peripheral.advertisement.bind(null, function(_) trigger(peripheral))];
			});
		});
	}
	
	public function startScan():Void throw 'abstract';
	public function stopScan():Void throw 'abstract';
}

interface CentralObject {
	var status(default, null):Observable<Status>;
	var peripherals(default, null):Peripherals;
	var advertisements(default, null):Signal<Peripheral>;
	function startScan():Void;
	function stopScan():Void;
}

@:allow(why.ble)
class Peripherals extends ObservableMap<String, Peripheral> {
	public var discovered(default, null):Signal<Peripheral>;
	public var gone(default, null):Signal<Peripheral>;
	
	public var timeout:Int = 120000; // ms
	
	var lastSeen:Map<String, Float>;
	
	public function new() {
		super(new Map());
		
		lastSeen = new Map();
		
		discovered = changes.select(function(v) return switch v {
			case {from: None, to: Some(value)}: Some(value);
			case _: None;
		});
		
		gone = changes.select(function(v) return switch v {
			case {from: Some(value), to: None}: Some(value);
			case _: None;
		});
		
		check();
	}
	
	override function set(k, v) {
		refresh(k);
		super.set(k, v);
	}
	
	override function remove(k) {
		lastSeen.remove(k);
		return super.remove(k);
	}
	
	inline function refresh(k) {
		lastSeen.set(k, Date.now().getTime());
	}
	
	function check() {
		haxe.Timer.delay(function() {
			var now = Date.now().getTime();
			var expired = [];
			for(id in keys()) if(now - lastSeen.get(id) > timeout) expired.push(id);
			for(id in expired) remove(id);
			check();
		}, Std.int(timeout / 10));
	}
}


enum Status {
	Unknown;
	Unsupported;
	Unauthorized;
	Resetting;
	On;
	Off;
}