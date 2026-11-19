import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let platformChannel = PlatformChannel()
  private let incomingFilesSceneDelegate = IncomingFilesSceneDelegate(files: .shared)

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

    let incoming = FlutterMethodChannel(
      name: "dev.cyclescope/incoming_files",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    incoming.setMethodCallHandler(IncomingFiles.shared.handle)
    IncomingFiles.shared.onFilesWaiting = {
      incoming.invokeMethod("filesWaiting", arguments: nil)
    }
    engineBridge.pluginRegistry.registrar(forPlugin: "CycleScopeIncomingFiles")?
      .addSceneDelegate(incomingFilesSceneDelegate)
  }
}

/// Swift side of the `dev.cyclescope/incoming_files` channel (Kotlin side: MainActivity.kt):
/// keeps the contents of files opened with the app ("Open in CycleScope" from Mail, Files,
/// messengers) until Dart takes them.
final class IncomingFiles {
  static let shared = IncomingFiles()

  /// Larger files are no CycleScope data and are not read.
  static let maxBytes = 32 * 1024 * 1024

  /// Called when a new file waits; set once the Flutter engine runs.
  var onFilesWaiting: (() -> Void)?

  private let read: (URL) -> String?
  private var pending: [String] = []

  init(read: @escaping (URL) -> String? = IncomingFiles.readFile) {
    self.read = read
  }

  func receive(_ url: URL) {
    guard let text = read(url) else { return }
    pending.append(text)
    onFilesWaiting?()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "takeIncomingFiles":
      result(pending)
      pending.removeAll()
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func readFile(_ url: URL) -> String? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    guard let data = try? Data(contentsOf: url), data.count <= maxBytes else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

/// Hands files opened with the app to [IncomingFiles], at launch and while it runs.
final class IncomingFilesSceneDelegate: NSObject, FlutterSceneLifeCycleDelegate {
  private let files: IncomingFiles

  init(files: IncomingFiles) {
    self.files = files
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    connectionOptions?.urlContexts.forEach { files.receive($0.url) }
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    let fileUrls = URLContexts.map(\.url).filter(\.isFileURL)
    fileUrls.forEach(files.receive)
    return !fileUrls.isEmpty
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
