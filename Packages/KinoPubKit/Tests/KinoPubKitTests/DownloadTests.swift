//
//  DownloadTests.swift
//
//
//  Exercises the Download state machine and progress reporting.
//

import Foundation
import Combine
import XCTest
@testable import KinoPubKit

final class DownloadTests: XCTestCase {

  var downloadManager: DownloadManager<TestMeta>!
  var fileSaverMock: FileSaverMock!
  let url = URL(string: "http://example.com/file.txt")!
  let metadata = TestMeta(title: "movie")

  override func setUp() {
    super.setUp()
    fileSaverMock = FileSaverMock()
    downloadManager = DownloadManager(fileSaver: fileSaverMock,
                                      database: DownloadedFilesDatabase(fileSaver: fileSaverMock))
  }

  override func tearDown() {
    downloadManager = nil
    fileSaverMock = nil
    super.tearDown()
  }

  func testInitialState_IsQueued() {
    let download = Download(url: url, metadata: metadata, manager: downloadManager)

    XCTAssertEqual(download.state, .queued)
    XCTAssertEqual(download.progress, 0.0)
    XCTAssertEqual(download.url, url)
    XCTAssertEqual(download.metadata, metadata)
  }

  func testResume_TransitionsToInProgress() {
    let download = Download(url: url, metadata: metadata, manager: downloadManager)

    download.resume()

    XCTAssertEqual(download.state, .inProgress)
    XCTAssertNotNil(download.task)

    // Clean up the created task so it does not linger.
    download.pause()
  }

  func testPause_TransitionsToPausedAndClearsTask() {
    let download = Download(url: url, metadata: metadata, manager: downloadManager)
    download.resume()

    // Replace the real background task with a mock whose resume-data callback
    // fires synchronously, so the paused state transition is deterministic.
    download.task = URLSessionDownloadTaskMock(url: url, resumeBlock: {})

    download.pause()

    XCTAssertEqual(download.state, .paused)
    XCTAssertNil(download.task)
  }

  func testUpdateProgress_PublishesValue() {
    let download = Download(url: url, metadata: metadata, manager: downloadManager)

    let expectation = expectation(description: "progress published")
    let cancellable = download.$progress
      .dropFirst()
      .sink { value in
        if value == 0.75 {
          expectation.fulfill()
        }
      }

    download.updateProgress(0.75)

    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(download.progress, 0.75)
    cancellable.cancel()
  }
}
