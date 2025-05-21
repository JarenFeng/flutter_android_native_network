import 'package:native_network_example/log.dart';
import 'package:wifi_iot/wifi_iot.dart';

class WiFiService {
  static const _tag = "WiFiService";

  static final i = WiFiService._();

  String? currentSSID;

  WiFiService._();

  Future<bool> isWiFiEnabled() {
    return WiFiForIoTPlugin.isEnabled();
  }

  Future<String?> getCurrentSSID() {
    return WiFiForIoTPlugin.getSSID();
  }

  Future<bool> connectIfNotConnected(String ssid, String password) async {
    String? currentSSID = await getCurrentSSID();
    LogUtils.d(_tag, "connectIfNotConnected, current SSID: $currentSSID, target SSID: $ssid");
    if (ssid == currentSSID) return true;
    return connect(ssid, password);
  }

  Future<bool> connect(String ssid, String password, {int timeoutSeconds = 20}) {
    return WiFiForIoTPlugin.connect(ssid, password: password, joinOnce: true, security: NetworkSecurity.WPA, timeoutInSeconds: timeoutSeconds, isHidden: true);
  }

  Future<bool> disconnect() {
    return WiFiForIoTPlugin.disconnect();
  }
}
