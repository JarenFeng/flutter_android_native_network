import 'package:native_network_example/log.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  static const _tag = "PermissionUtils";

  static Future<bool> ensurePermissions(BizModuleForPermission bizModule, {bool silent = false}) async {
    List<Permission> permissions2Request = [];
    for (var permission in bizModule.permissions) {
      if (await permission.isGranted) continue;
      permissions2Request.add(permission);
    }

    /// all permissions are granted
    if (permissions2Request.isEmpty) return true;

    /// attempt to request not-granted permissions from the user
    Map<Permission, PermissionStatus> results = await permissions2Request.request();

    List<String> deniedPermissionsName = [];
    List<String> permanentlyDeniedPermissionsName = [];

    /// indicate whether all the permissions are granted
    bool allGranted = true;

    results.forEach((permission, status) {
      if (status.isDenied || status.isPermanentlyDenied) deniedPermissionsName.add(permission.value.toString());
      if (status.isPermanentlyDenied) permanentlyDeniedPermissionsName.add(permission.value.toString());
      if (!(status.isGranted || status.isLimited)) allGranted = false;
    });

    LogUtils.d(_tag, "Permission results: $results");

    /// all permissions are granted
    if (allGranted) return true;

    /// don't show the alert message dialog to user
    if (silent) return false;

    return false;
  }
}

class BizModuleForPermission {
  /// associated permissions
  final List<Permission> permissions;
  final String bizModuleNameKey;

  static var wifi = BizModuleForPermission._('Wi-Fi', [Permission.location]);

  BizModuleForPermission._(this.bizModuleNameKey, this.permissions);
}
