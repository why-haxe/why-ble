package why.ble;

enum CharacteristicProperty {
	Broadcast;
	Read;
	WriteWithoutResponse;
	Write;
	Notify;
	Indicate;
	AuthenticatedSignedWrites;
	ExtendedProperties;
	
	ReliableWrite;
	WritableAuxiliaries;
	EncryptRead;
	EncryptWrite;
	EncryptAuthenticatedRead;
	EncryptAuthenticatedWrite;
	SecureRead;
	SecureWrite;
	Authorize;
}