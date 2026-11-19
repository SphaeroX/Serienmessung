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

final class IncomingFilesTests: XCTestCase {
  private let url = URL(fileURLWithPath: "/tmp/line.json")

  func testTake_ReceivedFiles_ReturnsTheirContentOnce() {
    let files = IncomingFiles(read: { _ in "{\"format\":\"cyclescope-backup\"}" })
    files.receive(url)

    XCTAssertEqual(take(files) as? [String], ["{\"format\":\"cyclescope-backup\"}"])
    XCTAssertEqual(take(files) as? [String], [])
  }

  func testReceive_ReadableFile_TellsDartFilesWait() {
    let files = IncomingFiles(read: { _ in "x" })
    var told = 0
    files.onFilesWaiting = { told += 1 }

    files.receive(url)

    XCTAssertEqual(told, 1)
  }

  func testReceive_UnreadableFile_KeepsNothingAndStaysQuiet() {
    let files = IncomingFiles(read: { _ in nil })
    var told = 0
    files.onFilesWaiting = { told += 1 }

    files.receive(url)

    XCTAssertEqual(told, 0)
    XCTAssertEqual(take(files) as? [String], [])
  }

  func testHandle_UnknownMethod_ReturnsNotImplemented() throws {
    var received: Any?
    IncomingFiles(read: { _ in nil }).handle(
      FlutterMethodCall(methodName: "unknownMethod", arguments: nil)
    ) { received = $0 }

    XCTAssertTrue((try XCTUnwrap(received) as AnyObject) === FlutterMethodNotImplemented)
  }

  private func take(_ files: IncomingFiles) -> Any? {
    var received: Any?
    files.handle(FlutterMethodCall(methodName: "takeIncomingFiles", arguments: nil)) {
      received = $0
    }
    return received
  }
}
