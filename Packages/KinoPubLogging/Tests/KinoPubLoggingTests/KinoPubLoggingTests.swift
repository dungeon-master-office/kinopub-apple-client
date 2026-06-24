import XCTest
import OSLog
@testable import KinoPubLogging

final class KinoPubLoggingTests: XCTestCase {

  // The Logger extension exposes a set of category-specific loggers. These tests
  // exercise that public API and make sure logging is safe to invoke.

  func testLoggersAreUsable() {
    // Calling into each logger must not crash.
    Logger.viewCycle.debug("view cycle test message")
    Logger.analytics.info("analytics test message")
    Logger.backend.debug("backend test message")
    Logger.app.error("app test message")
    Logger.kit.debug("kit test message")
  }

  func testLoggingCategoryRawValues() {
    XCTAssertEqual(LoggingCategory.viewCycle.rawValue, "viewCycle")
    XCTAssertEqual(LoggingCategory.analytics.rawValue, "analytics")
    XCTAssertEqual(LoggingCategory.backend.rawValue, "backend")
    XCTAssertEqual(LoggingCategory.app.rawValue, "app")
    XCTAssertEqual(LoggingCategory.kit.rawValue, "kit")
  }

  func testLoggingCategoryInitFromRawValue() {
    XCTAssertEqual(LoggingCategory(rawValue: "backend"), .backend)
    XCTAssertNil(LoggingCategory(rawValue: "nonexistent"))
  }
}
