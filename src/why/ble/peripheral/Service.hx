package why.ble.peripheral;

interface Service {
	final uuid:String;
	final primary:Bool;
	final characteristics:Array<Characteristic>;
}