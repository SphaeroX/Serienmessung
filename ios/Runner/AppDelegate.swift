import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let platformChannel = PlatformChannel()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(
      name: "dev.cyclescope/platform",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler(platformChannel.handle)
  }
}

/// Swift side of the `dev.cyclescope/platform` channel (Kotlin side: MainActivity.kt).
final class PlatformChannel {
  typealias UrlOpener = (URL, @escaping (Bool) -> Void) -> Void

  private let openUrl: UrlOpener
  private let monotonicMicros: () -> Int64

  init(
    openUrl: @escaping UrlOpener = { url, completion in
      UIApplication.shared.open(url, options: [:], completionHandler: completion)
    },
    // Not systemUptime or mach_absolute_time: both are required-reason APIs that would
    // need a privacy manifest. CLOCK_MONOTONIC_RAW also keeps counting while the device
    // sleeps, like Android's elapsedRealtime.
    monotonicMicros: @escaping () -> Int64 = {
      Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1000)
    }
  ) {
    self.openUrl = openUrl
    self.monotonicMicros = monotonicMicros
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "openUrl":
      guard let text = call.arguments as? String,
        let url = URL(string: text),
        url.scheme == "https"
      else {
        result(false)
        return
      }
      openUrl(url) { opened in result(opened) }
    case "elapsedRealtimeMicros":
      result(NSNumber(value: monotonicMicros()))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
