package why.ble;

using tink.CoreApi;

@:forward.new
abstract RemoteValue<T>(Pair<T, Signal<T>>) from Pair<T, Signal<T>> to Pair<T, Signal<T>> {
	public var value(get, never):T;
	public var changed(get, never):Signal<T>;
	
	public inline function get_value() return this.a;
	public inline function get_changed() return this.b;
}

interface RemoteReadableValue<T> {
	function get():Promise<RemoteValue<T>>;
}

interface RemoteWritableValue<T> {
	function set(v:T):Promise<Noise>;
}