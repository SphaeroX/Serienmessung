import Flutter
import XCTest

@testable import Runner

final class PlatformChannelTests: XCTestCase {
  private static let fixedClockMicros: Int64 = 9_876_543_210

  private let opener = RecordingUrlOpener()
  private lazy var channel = PlatformChannel(
    openUrl: opener.open,
    monotonicMicros: { Self.fixedClockMicros }
  )

  func testOpenUrl_HttpsLink_OpensLinkAndReturnsTrue() {
    let result = invoke("openUrl", arguments: "https://example.org/privacy")

    XCTAssertEqual(opener.openedUrls.map(\.absoluteString), ["https://example.org/privacy"])
    XCTAssertEqual(result as? Bool, true)
  }

  func testOpenUrl_OpenerFails_ReturnsFalse() {
    opener.succeeds = false

    let result = invoke("openUrl", arguments: "https://example.org/privacy")

    XCTAssertEqual(result as? Bool, false)
  }

  func testOpenUrl_NonHttpsLink_ReturnsFalseWithoutOpening() {
    let result = invoke("openUrl", arguments: "http://example.org")

    XCTAssertTrue(opener.openedUrls.isEmpty)
    XCTAssertEqual(result as? Bool, false)
  }

  func testOpenUrl_MissingArgument_ReturnsFalseWithoutOpening() {
    let result = invoke("openUrl", arguments: nil)

    XCTAssertTrue(opener.openedUrls.isEmpty)
    XCTAssertEqual(result as? Bool, false)
  }

  func testOpenUrl_NonStringArgument_ReturnsFalseWithoutOpening() {
    let result = invoke("openUrl", arguments: 42)

    XCTAssertTrue(opener.openedUrls.isEmpty)
    XCTAssertEqual(result as? Bool, false)
  }

  func testElapsedRealtimeMicros_InjectedClock_ReturnsClockValue() {
    let result = invoke("elapsedRealtimeMicros")

    XCTAssertEqual((result as? NSNumber)?.int64Value, Self.fixedClockMicros)
  }

  func testHandle_UnknownMethod_ReturnsNotImplemented() throws {
    let result = try XCTUnwrap(invoke("unknownMethod"))

    XCTAssertTrue((result as AnyObject) === FlutterMethodNotImplemented)
  }

  private func invoke(_ method: String, arguments: Any? = nil) -> Any? {
    var received: Any?
    channel.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { value in
      received = value
    }
    return received
  }
}

private final class RecordingUrlOpener {
  var succeeds = true
  private(set) var openedUrls: [URL] = []

  func open(_ url: URL, completion: @escaping (Bool) -> Void) {
    openedUrls.append(url)
    completion(succeeds)
  }
}
