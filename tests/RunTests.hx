package ;

class RunTests {

  static function main() {
    // monitor memory
    trace('main');
		new haxe.Timer(2000).run = function() {
			var memory = js.Node.process.memoryUsage();
			inline function format(v:Float)
				return Std.int(v / 1024 / 1024 * 100) / 100;

			trace('${Date.now().toString()}: Heap: ${format(memory.heapUsed)} / ${format(memory.heapTotal)} MB');
    };
    
    
    // Noble.inst.on('discover', v -> trace(v.id));
    // Noble.inst.on('stateChange', v -> if(v == 'poweredOn') Noble.inst.startScanning([], true));
    
    var central:why.ble.Central = new why.ble.centrals.NodeCentral();
    central.status.bind(null, v -> {
      trace(Std.string(v));
      if(v == On) {
        central.scan();
        central.peripherals.discovered.handle(function(o) trace(o.id));
      }
    });
  }
  
}

extern class Noble extends js.node.events.EventEmitter<Noble> {
	static var inst(get, never):Noble;
	static inline function get_inst():Noble
		return js.Lib.require('@abandonware/noble');

	function startScanning(?filter:Array<String>, ?allowDuplicates:Bool):Void;
	function stopScanning():Void;
}