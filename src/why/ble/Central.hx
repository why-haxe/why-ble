package why.ble;

import why.ble.central.*;

using tink.CoreApi;

interface Central {
	final discovered:Signal<Peripheral>;
	final gone:Signal<Peripheral>;

	function powered():Promise<Bool>;
	function scanning():Promise<Bool>;

	function startScanning():Promise<Noise>;
	function stopScanning():Promise<Noise>;
}
