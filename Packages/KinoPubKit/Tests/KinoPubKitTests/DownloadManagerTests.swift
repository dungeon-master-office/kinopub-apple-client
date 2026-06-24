//
//  DownloadManagerTests.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import Combine
import XCTest
@testable import KinoPubKit

/// Simple Codable & Equatable metadata used across the KinoPubKit download tests.
struct TestMeta: Codable, Equatable {
  var title: String
}

class DownloadManagerTests: XCTestCase {

  // MARK: - Test Variables

  var downloadManager: DownloadManager<TestMeta>!
  var fileSaverMock: FileSaverMock!
  let metadata = TestMeta(title: "test")

  // MARK: - Test Setup

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

  // MARK: - Test Methods

  func testStartDownload() {
    // Arrange
    let url = URL(string: "http://example.com/testfile.txt")!

    // Act
    let downloadTaskMock = URLSessionDownloadTaskMock(url: url, resumeBlock: {})
    let download = downloadManager.startDownload(url: url, withMetadata: metadata)
    download.task = downloadTaskMock

    // Assert
    XCTAssertNotNil(download)
    XCTAssertEqual(download.metadata, metadata)
    XCTAssertNotNil(downloadManager.activeDownloads[url])
  }

  func testRemoveDownload() {
    // Arrange
    let url = URL(string: "http://example.com/testfile.txt")!
    let downloadTaskMock = URLSessionDownloadTaskMock(url: url, resumeBlock: {})
    let download = downloadManager.startDownload(url: url, withMetadata: metadata)
    download.task = downloadTaskMock

    // Act
    downloadManager.removeDownload(for: url)

    // Assert
    XCTAssertNil(downloadManager.activeDownloads[url])
  }

  func testCompleteDownload() {
    // Arrange
    let url = URL(string: "http://example.com/testfile.txt")!
    let downloadTaskMock = URLSessionDownloadTaskMock(url: url, resumeBlock: {})
    let download = downloadManager.startDownload(url: url, withMetadata: metadata)
    download.task = downloadTaskMock

    // Act
    downloadManager.completeDownload(url)

    // Assert
    XCTAssertNil(downloadManager.activeDownloads[url])
  }

  func testDidFinishDownloadingTo_Success() {
    // Arrange
    let url = URL(string: "http://example.com/testfile.txt")!
    let locationURL = URL(fileURLWithPath: "/path/to/temporary/location.txt")

    let downloadTaskMock = URLSessionDownloadTaskMock(url: url) {}

    // Set the download task on the Download instance.
    let download = downloadManager.startDownload(url: url, withMetadata: metadata)
    download.task = downloadTaskMock

    // Act
    downloadManager.urlSession(downloadManager.session,
                               downloadTask: downloadTaskMock,
                               didFinishDownloadingTo: locationURL)

    // Assert
    XCTAssertTrue(fileSaverMock.didSaveFileCalled)
    XCTAssertEqual(fileSaverMock.savedFileSourceURL, locationURL)
    XCTAssertEqual(fileSaverMock.savedFileDestinationURL,
                   fileSaverMock.getDocumentsDirectoryURL(forFilename: "testfile.txt"))
    // The download should be removed from the active list once finished.
    XCTAssertNil(downloadManager.activeDownloads[url])
  }

  func testDidWriteData_UpdatesProgress() {
    // Arrange
    let url = URL(string: "http://example.com/testfile.txt")!
    let downloadTaskMock = URLSessionDownloadTaskMock(url: url, resumeBlock: {})
    let download = downloadManager.startDownload(url: url, withMetadata: metadata)
    download.task = downloadTaskMock

    let expectation = expectation(description: "progress updated")
    let cancellable = download.$progress
      .dropFirst() // skip initial 0.0
      .sink { progress in
        if progress == 0.5 {
          expectation.fulfill()
        }
      }

    // Act
    downloadManager.urlSession(downloadManager.session,
                               downloadTask: downloadTaskMock,
                               didWriteData: 1024,
                               totalBytesWritten: 1024,
                               totalBytesExpectedToWrite: 2048)

    // Assert
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(download.progress, 0.5)
    cancellable.cancel()
  }
}

// MARK: - Mock Classes

class URLSessionDownloadTaskMock: URLSessionDownloadTask {
  typealias CompletionHandler = (URL?, URLResponse?, Error?) -> Void

  private let completionHandler: CompletionHandler?
  private let url: URL?
  private let resumeBlock: () -> Void

  init(url: URL? = nil, completionHandler: CompletionHandler? = nil, resumeBlock: @escaping () -> Void) {
    self.url = url
    self.completionHandler = completionHandler
    self.resumeBlock = resumeBlock
  }

  override var originalRequest: URLRequest? {
    if let url = url {
      return URLRequest(url: url)
    }
    return nil
  }

  override func resume() {
    resumeBlock()
  }

  override func cancel() {}

  override func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void) {
    completionHandler(nil)
  }

  func triggerCompletion(with location: URL?, response: URLResponse?, error: Error?) {
    completionHandler?(location, response, error)
  }
}
