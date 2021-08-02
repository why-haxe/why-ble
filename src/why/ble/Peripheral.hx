package why.ble;

import why.ble.peripheral.*;

using tink.CoreApi;

interface Peripheral {
	function startAdvertising(advertisement:Advertisement):Promise<Noise>;
	function stopAdvertising():Promise<Noise>;
}
