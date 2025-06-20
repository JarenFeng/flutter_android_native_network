import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'native_network_platform_interface.dart';

/// An implementation of [NativeNetworkPlatform] that uses method channels.
class MethodChannelNativeNetwork extends NativeNetworkPlatform {
  /// The method channel used to interact with the native platform.

  final _methodChannel = const MethodChannel('native_network/method');
  final _httpEventChannel = const EventChannel('native_network/event');
  final _socketEventChannel = const EventChannel('native_network/socket_event');

  final _httpProgressCallbacks = <String, void Function(NetworkProgress)>{};
  final _socketEventCallbacks = <String, void Function(SocketEvent)>{};

  MethodChannelNativeNetwork() {
    _httpEventChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event);
      final type = map['type'];

      switch (type) {
      // download / upload progress
        case 'd-p':
        case 'u-p':
          final progress = NetworkProgress.fromMap(map);
          _httpProgressCallbacks[progress.requestId]?.call(progress);
          break;
        default:
          debugPrint("Unknown event type: \$type");
      }
    });

    _socketEventChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event);
      final socketId = map['socketId'];
      final handler = _socketEventCallbacks[socketId];
      var se = SocketEvent.fromMap(map);
      if (handler != null) handler(se);

      if (se.type == 'disconnected') {
        print("socket disconnected, remove event callback");
        _socketEventCallbacks.remove(socketId);
        return;
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
  Future<String> openSocket({
    required String host,
    required int port,
    int? connectionTimeoutMilliseconds,
    void Function(SocketEvent)? onEvent,
  }) {
    final socketId = generateRandomString(20);
    return _methodChannel.invokeMethod('openSocket', {
      'socketId': socketId,
      'host': host,
      'port': port,
      'connectionTimeoutMilliseconds': connectionTimeoutMilliseconds,
    }).then((id) {
      if (onEvent != null) _socketEventCallbacks[socketId] = onEvent;
      print("Native network, open socket, native returns, socket id: $socketId");
      return socketId;
    });
  }

  @override
  Future closeSocket({required String socketId}) async {
    return _methodChannel.invokeMethod('closeSocket', {'socketId': socketId}).then((_) {
      _socketEventCallbacks.remove(socketId);
      print("remove onEvent callback for socket id: $socketId");
    }).catchError((e) {
      print("close socket error. $e");
      _socketEventCallbacks.remove(socketId);
    });
  }

  @override
  Future sendSocket({required String socketId, required List<int> data}) async {
    return _methodChannel.invokeMethod('sendSocket', {
      'socketId': socketId,
      'data': data,
    });
  }
}

String generateRandomString(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
      r'~!@#$%^&*()-_=+[]{}|;:,.<>?/';
  final rand = Random();
  return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
}
