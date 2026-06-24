import XCTest
import SwiftUI
@testable import KinoPubUI

final class KinoPubUITests: XCTestCase {

  // MARK: - KinoPubButton

  func testKinoPubButton_StoresConfiguration() {
    var didTap = false
    let button = KinoPubButton(title: "Watch", color: .green, action: { didTap = true })

    XCTAssertEqual(button.title, "Watch")
    XCTAssertEqual(button.color, .green)

    button.action()
    XCTAssertTrue(didTap)
  }

  func testButtonColor_MapsToExpectedColors() {
    XCTAssertEqual(KinoPubButton.ButtonColor.green.color, Color.KinoPub.accent)
    XCTAssertEqual(KinoPubButton.ButtonColor.red.color, Color.KinoPub.accentRed)
    XCTAssertEqual(KinoPubButton.ButtonColor.blue.color, Color.KinoPub.accentBlue)
    XCTAssertEqual(KinoPubButton.ButtonColor.gray.color, Color.KinoPub.selectionBackground)
  }

  // MARK: - Double formatting

  func testScoreFormatted_RoundsToOneDecimal() {
    XCTAssertEqual((8.0).scoreFormatted, "8.0")
    XCTAssertEqual((7.34).scoreFormatted, "7.3")
    XCTAssertEqual((8.16).scoreFormatted, "8.2")
    XCTAssertEqual((0.0).scoreFormatted, "0.0")
  }

  // MARK: - Color palette

  func testColorPalette_IsAccessible() {
    // Ensure the asset-backed colors resolve from the package bundle without crashing.
    XCTAssertNotNil(Color.KinoPub.accent)
    XCTAssertNotNil(Color.KinoPub.background)
    XCTAssertNotNil(Color.KinoPub.text)
    XCTAssertNotNil(Color.KinoPub.skeleton)
  }
}

extension KinoPubButton.ButtonColor: Equatable {
  public static func == (lhs: KinoPubButton.ButtonColor, rhs: KinoPubButton.ButtonColor) -> Bool {
    switch (lhs, rhs) {
    case (.green, .green), (.gray, .gray), (.red, .red), (.blue, .blue):
      return true
    default:
      return false
    }
  }
}
