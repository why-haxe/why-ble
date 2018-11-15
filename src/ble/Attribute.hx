package ble;

import tink.Chunk;

typedef Attribute = {
	handle:Int, // Int16
	type:Uuid,
	permissions:Permission,
	encryption:Encrpytion,
	authorization:Authorization,
	value:Chunk,
}