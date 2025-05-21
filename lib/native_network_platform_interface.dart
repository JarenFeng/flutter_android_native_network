import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'native_network_method_channel.dart';

abstract class NativeNetworkPlatform extends PlatformInterface {
  /// Constructs a NativeNetworkPlatform.
  NativeNetworkPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeNetworkPlatform _instance = MethodChannelNativeNetwork();

  /// The default instance of [NativeNetworkPlatform] to use.
  ///
  /// Defaults to [MethodChannelNativeNetwork].
  static NativeNetworkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NativeNetworkPlatform] when
  /// they register themselves.
  static set instance(NativeNetworkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int> bindToWiFiNetwork(String ssid);

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
  });

  Future<void> openSocket({
    required String host,
    required int port,
  });
}

class HttpResponse {
  final int statusCode;
  final Uint8List? _bodyBytes;
  final Stream<List<int>>? _responseStream;
  final String? _bodyString;
  final int contentLength;
  final Map<String, String> headers;

  HttpResponse._({
    required this.statusCode,
    required this.contentLength,
    required this.headers,
    Uint8List? bodyBytes,
    String? body,
    Stream<List<int>>? responseStream,
  })  : _bodyBytes = bodyBytes,
        _bodyString = body,
        _responseStream= responseStream;

  factory HttpResponse.fromBytes({
    required int statusCode,
    required Uint8List bodyBytes,
    required int contentLength,
    required Map<String, String> headers,
  }) {
    return HttpResponse._(
      statusCode: statusCode,
      bodyBytes: bodyBytes,
      contentLength: contentLength,
      headers: headers,
    );
  }

  factory HttpResponse.fromString({
    required int statusCode,
    required String body,
    required int contentLength,
    required Map<String, String> headers,
  }) {
    return HttpResponse._(
      statusCode: statusCode,
      body: body,
      contentLength: contentLength,
      headers: headers,
    );
  }

  factory HttpResponse.fromStream({
    required int statusCode,
    required  Stream<List<int>>? responseStream,
    required int contentLength,
    required Map<String, String> headers,
  }) {
    return HttpResponse._(
      statusCode: statusCode,
      responseStream: responseStream,
      contentLength: contentLength,
      headers: headers,
    );
  }

  Uint8List get bodyBytes => _bodyBytes ?? Uint8List.fromList(_bodyString!.codeUnits);

  String get body => _bodyString ?? String.fromCharCodes(_bodyBytes!);

  Stream<List<int>>? get responseStream => _responseStream;

  bool get isOk => statusCode >= 200 && statusCode <= 299;

  bool get hasError => !isOk;
}

class NativeHttpException implements Exception {
  final String code;
  final String? message;

  NativeHttpException({required this.code, this.message});

  bool get isTimeout => code == 'timeout';

  bool get isConnectException => code == 'connect_error';

  bool get isUnknownHost => code == 'dns_error';

  bool get isSSLException => code == 'ssl_error';
}

class NetworkProgress {
  final String requestId;
  final int transferred;
  final int total;

  NetworkProgress({
    required this.requestId,
    required this.transferred,
    required this.total,
  });

  factory NetworkProgress.fromMap(Map<String, dynamic> map) {
    return NetworkProgress(
      requestId: map['requestId'],
      transferred: map['transferred'],
      total: map['total'],
    );
  }

  @override
  String toString() {
    return 'NetworkProgress{requestId: $requestId, transferred: $transferred, total: $total}';
  }
}

class SocketEvent {
  final String socketId;
  final String type; // 'connected', 'data', 'error', 'closed'
  final List<int>? data;
  final String? error;

  SocketEvent({
    required this.socketId,
    required this.type,
    this.data,
    this.error,
  });

  factory SocketEvent.fromMap(Map<String, dynamic> map) {
    return SocketEvent(
      socketId: map['socketId'],
      type: map['type'],
      data: (map['data'] as List?)?.cast<int>(),
      error: map['error'],
    );
  }
}
