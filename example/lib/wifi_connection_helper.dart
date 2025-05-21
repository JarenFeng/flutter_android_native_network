import 'dart:async';

import 'package:native_network_example/log.dart';
import 'package:native_network_example/permission_utils.dart';
import 'package:native_network_example/wifi_service.dart';

mixin WiFiConnectionHelperMixin {
  static const _tag = 'WiFiConnectionHandler';

  Future<WiFiRequestResult> ensureCurrentBikeWiFiConnection() async {
    String ssid = 'WiFi SSID';
    String pwd = 'PASSWORD';

    bool permissionR = await PermissionUtils.ensurePermissions(BizModuleForPermission.wifi);
    if (!permissionR) {
      LogUtils.d(_tag, "Permission denied.");

      return WiFiRequestResult.permissionDenied;
    }

    bool r = await WiFiService.i.connectIfNotConnected(ssid, pwd);

    if (r) {
      r = ssid == await WiFiService.i.getCurrentSSID();
      if (r) {
        LogUtils.i(_tag, "Succeed to connect to Wi-Fi [$ssid]");
        return WiFiRequestResult.succeed;
      }
      LogUtils.w(_tag, "Waring!!! Connect returns succeed but current Wi-Fi SSID is not [$ssid]");
      // failed
    }

    LogUtils.i(_tag, "Failed to connect to Wi-Fi [$ssid]");
    return WiFiRequestResult.unknown;
  }
}

enum WiFiRequestResult {
  succeed,
  permissionDenied,
  canceled,
  invalid, // todo: support in future
  timeout, // todo: support in future
  unknown,
  ;

  bool get isSucceed => this == WiFiRequestResult.succeed;

  bool get isNotSucceed => !isSucceed;
}
