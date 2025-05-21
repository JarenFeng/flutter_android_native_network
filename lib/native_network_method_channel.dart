import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'native_network_platform_interface.dart';

/// An implementation of [NativeNetworkPlatform] that uses method channels.
class MethodChannelNativeNetwork extends NativeNetworkPlatform {
  /// The method channel used to interact with the native platform.

  final _methodChannel = const MethodChannel('native_network/method');
  final _eventChannel = const EventChannel('native_network/event');

  final _httpProgressCallbacks = <String, void Function(NetworkProgress)>{};
  final _socketEventCallbacks = <String, void Function(SocketEvent)>{};

  MethodChannelNativeNetwork() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event);
      final type = map['type'];

      switch (type) {
        case 'd-p':
        case 'u-p':
          final progress = NetworkProgress.fromMap(map);
          _httpProgressCallbacks[progress.requestId]?.call(progress);
          break;

        case 's-e':
          final socketId = map['socketId'];
          final handler = _socketEventCallbacks[socketId];
          if (handler != null) {
            handler(SocketEvent.fromMap(map));
          }
          break;

        default:
          debugPrint("Unknown event type: \$type");
      }
    });
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await _methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<int> bindToWiFiNetwork(String ssid) async {
    return await _methodChannel.invokeMethod('bindToWiFiNetwork', {'ssid': ssid});
  }

  @override
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
  }) async {
    final requestId = generateRandomString(20);
    if (onProgress != null) {
      _httpProgressCallbacks[requestId] = onProgress;
      debugPrint("add progress callback for request id: $requestId");
    }
    try {
      final res = await _methodChannel.invokeMethod('httpRequest', {
        'url': url,
        'method': method,
        'headers': headers,
        'body': body,
        'requestId': requestId,
        'filePath': filePath,
        'connectionTimeout': connectionTimeout?.inMilliseconds,
        'readTimeout': readTimeout?.inMilliseconds,
        'writeTimeout': writeTimeout?.inMilliseconds,
      });

      return HttpResponse.fromBytes(
        statusCode: res['statusCode'],
        bodyBytes: res['body'],
        contentLength: res['contentLength'],
        headers: Map<String, String>.from(res['headers'] ?? {}),
      );
    } on PlatformException catch (e) {
      throw NativeHttpException(code: e.code, message: e.message);
    } finally {
      _httpProgressCallbacks.remove(requestId);
      debugPrint("remove progress callback for request id: $requestId");
    }
  }

  @override
  Future<void> openSocket({
    required String host,
    required int port,
  }) async {
    final socketId = generateRandomString(20);
    await _methodChannel.invokeMethod('openSocket', {
      'socketId': socketId,
      'host': host,
      'port': port,
    });
  }

  void registerSocketCallback(String socketId, void Function(SocketEvent) onEvent) {
    _socketEventCallbacks[socketId] = onEvent;
  }

  void unregisterSocketCallback(String socketId) {
    _socketEventCallbacks.remove(socketId);
  }
}

String generateRandomString(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
      r'~!@#$%^&*()-_=+[]{}|;:,.<>?/';
  final rand = Random();
  return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
}
