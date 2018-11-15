package ble;

import tink.state.*;

using tink.CoreApi;

interface Central {
	var status(default, null):Observable<Status>;
	var peripherals(default, null):ObservableMap<String, Peripheral>;
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