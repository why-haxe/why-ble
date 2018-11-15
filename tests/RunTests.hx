package ;

class RunTests {

  static function main() {
    ble.centrals.NodeCentral;
    travix.Logger.println('it works');
    travix.Logger.exit(0); // make sure we exit properly, which is necessary on some targets, e.g. flash & (phantom)js
  }
  
}