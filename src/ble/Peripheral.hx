package ble;

import tink.state.*;

using tink.CoreApi;

interface Peripheral {
	var id(default, null):String;
	var connectable(default, null):Observable<Bool>;
	var rssi(default, null):Observable<Int>;
	var advertisement(default, null):Observable<Advertisement>;
	var connected(default, null):Observable<Bool>;
	
	function connect():Promise<Noise>;
	function disconnect():Promise<Noise>;
	function discoverServices():Promise<Array<Service>>;
}