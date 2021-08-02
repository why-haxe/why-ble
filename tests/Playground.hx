package;

import why.ble.*;
import tink.Chunk;

using tink.CoreApi;
using StringTools;

class Playground {
	static function main() {
		js.Node.process.setuid(1000);
		// central();
		peripheral();
	}
	static function central() {
		final transport = why.dbus.transport.NodeDBusNext.sessionBus({busAddress: 'tcp:host=192.168.0.115,port=7272', authMethods: ['EXTERNAL']});
		final cnx = new why.dbus.Connection(transport);
		final central = new why.ble.central.BluezCentral(new why.bluez.BlueZ(cnx));
		
		central.powered().handle(o -> trace('powered', o.sure()));
		central.scanning().handle(o -> trace('scanning', o.sure()));
		
		central.discovered.handle(peripheral -> {
			peripheral.name.get().handle(o -> {
				final v = o.sure();
				final name = v.value;
				
				if(name != null && name.startsWith('Dasloop')) {
					trace(name);
					peripheral.rssi.get().handle(o -> {
						final v = o.sure();
						trace(name, 'rssi', v.value);
						v.changed.handle(v -> trace(name, 'rssi', v));
					});
					// peripheral.manufacturerData.get().handle(o -> {
					// 	final v = o.sure();
					// 	trace(name, 'manufacturerData', v.value);
					// 	v.changed.handle(v -> trace(name, 'manufacturerData', v));
					// });
				}
			});
		});
		
		central.startScanning().handle(o -> trace(o));
	}
	
	static function peripheral() {
		final transport = why.dbus.transport.NodeDBusNext.sessionBus({busAddress: 'tcp:host=192.168.0.115,port=7272', authMethods: ['EXTERNAL']});
		final cnx = new why.dbus.Connection(transport);
		final application = new tink.Adhoc<why.ble.peripheral.Application>({}, {
			services: [new tink.Adhoc<why.ble.peripheral.Service>({}, {
				uuid: 'b4b0ca7c-2cdc-4165-9640-768471c6b440',
				primary: true,
				characteristics: [new tink.Adhoc<why.ble.peripheral.Characteristic>({}, {
					uuid: 'b4b0ca7c-2cdc-4165-9640-768471c6b441',
					properties: [Read, Write],
					write: (_, chunk:Chunk, ?options:{?withoutResponse:Bool, ?offset:Int}) -> {
						trace('write ${chunk.toString()} $options');
						Promise.NOISE;
					},
					read: (_, ?options:{?offset:Int}) -> {
						trace('read $options');
						Promise.resolve(('read_value':Chunk));
					},
				})],
			})],
		});
		final peripheral = new why.ble.peripheral.BluezPeripheral(new why.bluez.BlueZ(cnx), application);
		
		peripheral.startAdvertising(new tink.Adhoc<why.ble.peripheral.Advertisement>({}, {
			localName: 'why-ble-test',
		})).handle(o -> trace(o));
		
		var stopped = false;
		js.Node.process.on('SIGINT', _ -> {
			trace('SIGINT');
			if(stopped)
				Sys.exit(0);
			else
				peripheral.stopAdvertising().handle(o -> trace(o));
			stopped = true;
		});
	}
}
