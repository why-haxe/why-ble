package ble;

import tink.state.*;

using tink.CoreApi;

abstract Central(CentralObject) from CentralObject to CentralObject {
	public inline function find(filter:Peripheral->Bool):Future<Peripheral> {
		return this.advertisements.nextTime(filter);
	}
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