import 'package:flutter_test/flutter_test.dart';
import 'package:native_network/native_network.dart';
import 'package:native_network/native_network_platform_interface.dart';
import 'package:native_network/native_network_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNativeNetworkPlatform with MockPlatformInterfaceMixin implements NativeNetworkPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<int> bindToWiFiNetwork(String ssid) {
    // TODO: implement bindToNetwork
    throw UnimplementedError();
  }

  @override
  Future<void> openSocket({required String host, required int port}) {
    // TODO: implement openSocket
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse> request(
      {required String url,
      String method = 'GET',
      Map<String, String>? headers,
      String? body,
      String? filePath,
      void Function(NetworkProgress p1)? onProgress,
      Duration? connectionTimeout,
      Duration? readTimeout,
      Duration? writeTimeout}) {
    // TODO: implement request
    throw UnimplementedError();
  }
}

void main() {
  final NativeNetworkPlatform initialPlatform = NativeNetworkPlatform.instance;

  test('$MethodChannelNativeNetwork is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNativeNetwork>());
  });

  test('getPlatformVersion', () async {
    NativeNetwork nativeNetworkPlugin = NativeNetwork();
    MockNativeNetworkPlatform fakePlatform = MockNativeNetworkPlatform();
    NativeNetworkPlatform.instance = fakePlatform;

    expect(await nativeNetworkPlugin.getPlatformVersion(), '42');
  });
}
