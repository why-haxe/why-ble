package ble;

import tink.Chunk;

typedef Advertisement = {
	localName:String,
	txPowerLevel:Int,
	serviceUuids:Array<String>,
	serviceSolicitationUuid:Array<String>,
	manufacturerData:Chunk,
	serviceData:Array<{uuid:String, data:Chunk}>,
}