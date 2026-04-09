import Capacitor

final class FilmtoneBridgeViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        // App-local plugins are not included in Capacitor CLI-generated packageClassList.
        bridge?.registerPluginInstance(FilmtoneMediaPlugin())
    }
}
