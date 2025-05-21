import 'native_network_platform_interface.dart';

class NativeNetwork {
  Future<String?> getPlatformVersion() {
    return NativeNetworkPlatform.instance.getPlatformVersion();
  }

  Future<int> bindToWiFiNetwork(String ssid) {
    return NativeNetworkPlatform.instance.bindToWiFiNetwork(ssid);
  }

  Future<HttpResponse> request({
    required String url,
    String method = 'GET',
    Map<String, String>? headers,
    String? body,
    String? filePath,
    void Function(NetworkProgress)? onProgress,
    Duration? connectionTimeout,
    Duration? readTimeout,
    Duration? writeTimeout,
  }) {
    return NativeNetworkPlatform.instance.request(
        url: url, method: method, headers: headers, body: body, filePath: filePath, onProgress: onProgress, connectionTimeout: connectionTimeout, readTimeout: readTimeout, writeTimeout: writeTimeout);
  }

  Future<void> openSocket({
    required String host,
    required int port,
  }) {
    return NativeNetworkPlatform.instance.openSocket(host: host, port: port);
  }
}
