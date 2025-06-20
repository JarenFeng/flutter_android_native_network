import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:native_network/native_network.dart';
import 'package:native_network_example/log.dart';
import 'package:native_network_example/wifi_connection_helper.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WiFiConnectionHelperMixin {
  String _platformVersion = 'Unknown';
  final _nativeNetworkPlugin = NativeNetwork();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _nativeNetworkPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  String? _currentSocketId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(children: [
          Text('Running on: $_platformVersion\n'),
          OutlinedButton(
              onPressed: () {
                ensureCurrentBikeWiFiConnection().then((r) {
                  LogUtils.d("==WiFi==", "WiFi connect result: $r");
                });
              },
              child: const Text('Connect Wi-Fi')),
          OutlinedButton(
              onPressed: () async {
                LogUtils.d("WiFi", "before bindToWiFiNetwork");
                var r = await _nativeNetworkPlugin.bindToWiFiNetwork('WiFi SSID');
                LogUtils.d("WiFi", "bindToWiFiNetwork result: $r");
              },
              child: const Text('Bind to Network')),
          OutlinedButton(
              onPressed: () async {
                _nativeNetworkPlugin.request(url: "http://192.168.49.1/dav/sdcard/").then((r) {
                  LogUtils.d("request result", "${r.statusCode}, ${r.body}");
                }).catchError((e) {
                  LogUtils.e("WiFi", e, "");
                });
              },
              child: const Text('Request Data')),
          OutlinedButton(
              onPressed: () async {
                String path = "${(await getApplicationCacheDirectory()).path}/${DateTime.now().millisecondsSinceEpoch}.file";
                var downloadAt = DateTime.now();
                _nativeNetworkPlugin
                    .request(
                        url: "http://192.168.49.1/dav/sdcard/1747271711117.xyz",
                        filePath: path,
                        onProgress: (progress) {
                          LogUtils.d("Download", "progress: $progress");
                        })
                    .then((r) {
                  LogUtils.d("request result", "${r.statusCode}, ${r.body}, cost time: ${DateTime.now().millisecondsSinceEpoch - downloadAt.millisecondsSinceEpoch}ms");
                }).catchError((e) {
                  LogUtils.e("download", e, "");
                });
              },
              child: const Text('Download file')),
          OutlinedButton(
              onPressed: () async {
                String path = "${(await getApplicationCacheDirectory()).path}/1747271211066.file";
                var uploadedAt = DateTime.now();
                _nativeNetworkPlugin
                    .request(
                        method: 'PUT',
                        url: "http://192.168.49.1/dav/sdcard/${DateTime.now().millisecondsSinceEpoch}.xyz",
                        filePath: path,
                        onProgress: (progress) {
                          LogUtils.d("Upload", "progress: $progress");
                        })
                    .then((r) {
                  LogUtils.d("Upload", "${r.statusCode}, ${r.body}, cost time: ${DateTime.now().millisecondsSinceEpoch - uploadedAt.millisecondsSinceEpoch}ms");
                }).catchError((e) {
                  LogUtils.e("Upload", e, "");
                });
              },
              child: const Text('Upload file')),
          OutlinedButton(
              onPressed: () async {
                _nativeNetworkPlugin
                    .openSocket(
                        host: '192.168.1.1',
                        port: 6666,
                        onEvent: (event) {
                          //
                          LogUtils.d("Socket Event", "socket id: ${event.socketId}, type: ${event.type}, data: ${event.data}, error: ${event.error}");
                        })
                    .then((socketId) {
                  _currentSocketId = socketId;

                  LogUtils.d("Socket", "socket connected, id: $socketId");
                });
              },
              child: const Text('Socket Test')),
          OutlinedButton(
              onPressed: () async {
                if (_currentSocketId == null) {
                  LogUtils.d("Socket", "current socket id is null");
                  return;
                }
                _nativeNetworkPlugin
                    .sendSocket(
                  socketId: _currentSocketId!,
                  data: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 0]),
                )
                    .then((_) {
                  LogUtils.d("Socket", "send socket data done");
                });
              },
              child: const Text('Send Socket Data')),
          OutlinedButton(
              onPressed: () async {
                HttpClient().get("www.baidu.com", 80, "").then((request) {
                  request.close().then((rsp) {
                    LogUtils.d("request result", "response: status: ${rsp.statusCode}, ${rsp.reasonPhrase}");
                  });
                });
              },
              child: const Text('Internet Test')),
        ]),
      ),
    );
  }
}
