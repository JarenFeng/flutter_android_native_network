import 'dart:typed_data';

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

  Future<String> openSocket({
    required String host,
    required int port,
    int? connectionTimeoutMilliseconds,
    void Function(SocketEvent)? onEvent,
  }) {
    return NativeNetworkPlatform.instance.openSocket(
      host: host,
      port: port,
      onEvent: onEvent,
      connectionTimeoutMilliseconds: connectionTimeoutMilliseconds,
    ).then((id){
      print("openSocket, done id: $id");
      return id;
    });
  }

  Future closeSocket({required String socketId}) {
    return NativeNetworkPlatform.instance.closeSocket(
      socketId: socketId,
    );
  }

  Future sendSocket({required String socketId, required List<int> data}) {
    return NativeNetworkPlatform.instance.sendSocket(
      socketId: socketId,
      data: data,
    );
  }
}
