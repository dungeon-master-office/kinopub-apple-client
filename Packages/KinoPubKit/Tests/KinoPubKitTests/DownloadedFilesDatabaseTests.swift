//
//  DownloadedFilesDatabaseTests.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import XCTest
@testable import KinoPubKit

/// A FileSaving implementation that stores files inside a unique temporary
/// directory, so the database's real plist read/write round-trips can be tested.
final class TempDirectoryFileSaver: FileSaving {
  let directory: URL
  var didRemoveFileCalled = false
  var removedFileURL: URL?

  init() {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  func saveFile(from sourceURL: URL, to destinationURL: URL) throws {
    try? FileManager.default.removeItem(at: destinationURL)
    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
  }

  func removeFile(at sourceURL: URL) throws {
    didRemoveFileCalled = true
    removedFileURL = sourceURL
  }

  func getDocumentsDirectoryURL(forFilename filename: String) -> URL {
    directory.appendingPathComponent(filename)
  }

  func cleanup() {
    try? FileManager.default.removeItem(at: directory)
  }
}

class DownloadedFilesDatabaseTests: XCTestCase {

  // MARK: - Test Variables

  var downloadedFilesDatabase: DownloadedFilesDatabase<TestMeta>!
  var fileSaver: TempDirectoryFileSaver!

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()
    fileSaver = TempDirectoryFileSaver()
    downloadedFilesDatabase = DownloadedFilesDatabase(fileSaver: fileSaver)
  }

  override func tearDown() {
    downloadedFilesDatabase = nil
    fileSaver.cleanup()
    fileSaver = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func makeFileInfo(filename: String,
                            date: Date = Date()) -> DownloadedFileInfo<TestMeta> {
    DownloadedFileInfo(originalURL: URL(string: "http://example.com/\(filename)")!,
                       localFilename: filename,
                       downloadDate: date,
                       metadata: TestMeta(title: filename))
  }

  // MARK: - Test Methods

  func testReadData_WhenNoFileExists_ReturnsNil() {
    XCTAssertNil(downloadedFilesDatabase.readData())
  }

  func testSaveAndReadData_RoundTrip() {
    // Arrange
    let info = makeFileInfo(filename: "testfile.txt")

    // Act
    downloadedFilesDatabase.save(fileInfo: info)
    let retrieved = downloadedFilesDatabase.readData()

    // Assert
    XCTAssertEqual(retrieved?.count, 1)
    XCTAssertEqual(retrieved?.first, info)
  }

  func testSave_AppendsToExistingData() {
    // Arrange
    let first = makeFileInfo(filename: "first.txt")
    let second = makeFileInfo(filename: "second.txt")

    // Act
    downloadedFilesDatabase.save(fileInfo: first)
    downloadedFilesDatabase.save(fileInfo: second)
    let retrieved = downloadedFilesDatabase.readData()

    // Assert
    XCTAssertEqual(retrieved?.count, 2)
  }

  func testReadData_SortsByDownloadDateDescending() {
    // Arrange
    let older = makeFileInfo(filename: "older.txt", date: Date(timeIntervalSince1970: 1000))
    let newer = makeFileInfo(filename: "newer.txt", date: Date(timeIntervalSince1970: 2000))

    // Act - save in ascending order
    downloadedFilesDatabase.save(fileInfo: older)
    downloadedFilesDatabase.save(fileInfo: newer)
    let retrieved = downloadedFilesDatabase.readData()

    // Assert - newest first
    XCTAssertEqual(retrieved?.first, newer)
    XCTAssertEqual(retrieved?.last, older)
  }

  func testWriteData_OverwritesExisting() {
    // Arrange
    downloadedFilesDatabase.save(fileInfo: makeFileInfo(filename: "a.txt"))

    // Act
    let replacement = [makeFileInfo(filename: "b.txt")]
    downloadedFilesDatabase.writeData(replacement)
    let retrieved = downloadedFilesDatabase.readData()

    // Assert
    XCTAssertEqual(retrieved?.count, 1)
    XCTAssertEqual(retrieved?.first?.localFilename, "b.txt")
  }

  func testRemove_DeletesEntryAndRemovesFile() {
    // Arrange
    let keep = makeFileInfo(filename: "keep.txt")
    let drop = makeFileInfo(filename: "drop.txt")
    downloadedFilesDatabase.save(fileInfo: keep)
    downloadedFilesDatabase.save(fileInfo: drop)

    // Act
    downloadedFilesDatabase.remove(fileInfo: drop)
    let retrieved = downloadedFilesDatabase.readData()

    // Assert
    XCTAssertEqual(retrieved?.count, 1)
    XCTAssertEqual(retrieved?.first, keep)
    XCTAssertTrue(fileSaver.didRemoveFileCalled)
    XCTAssertEqual(fileSaver.removedFileURL, drop.originalURL)
  }

  func testReadData_WhenInvalidPlist_ReturnsNil() {
    // Arrange - write garbage to the plist location.
    let dataURL = fileSaver.getDocumentsDirectoryURL(forFilename: "downloadedFiles.plist")
    try? "not a plist".data(using: .utf8)?.write(to: dataURL)

    // Act & Assert
    XCTAssertNil(downloadedFilesDatabase.readData())
  }
}
