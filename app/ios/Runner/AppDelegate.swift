import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerStorageChannel(messenger: engineBridge.applicationRegistrar.messenger())
    registerRegionChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  /// Hands Dart the Region from Settings > General > Language & Region. Flutter
  /// only reports the language list, and an iPhone in Malaysia set to British
  /// English reports `en-GB` there. The app's default rows need the country.
  private func registerRegionChannel(messenger: FlutterBinaryMessenger) {
    let region = FlutterMethodChannel(
      name: "com.digitallinked.atvremote/region", binaryMessenger: messenger)
    region.setMethodCallHandler { call, result in
      guard call.method == "phoneCountry" else {
        return result(FlutterMethodNotImplemented)
      }
      result(Locale.current.regionCode)
    }
  }

  /// Hands Dart the directory for the database (Ruling P8-R1):
  /// `Library/Application Support/Database`, excluded from iCloud and computer
  /// backups and from device transfer, so saved TVs never leave this phone.
  /// On any failure Dart gets an error and the database doesn't open; it never
  /// falls back to Documents, which is backed up.
  private func registerStorageChannel(messenger: FlutterBinaryMessenger) {
    let storage = FlutterMethodChannel(
      name: "com.digitallinked.atvremote/storage", binaryMessenger: messenger)
    storage.setMethodCallHandler { call, result in
      guard call.method == "backupExcludedDatabaseDirectory" else {
        return result(FlutterMethodNotImplemented)
      }
      do {
        var dir = try FileManager.default.url(
          for: .applicationSupportDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true
        )
        .appendingPathComponent("Database", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try dir.setResourceValues(values)
        result(dir.path)
      } catch {
        result(FlutterError(code: "storage", message: "unavailable", details: nil))
      }
    }
  }
}
