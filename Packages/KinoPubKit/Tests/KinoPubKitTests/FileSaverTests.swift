//
//  FileSaverTests.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import XCTest
@testable import KinoPubKit

class FileSaverTests: XCTestCase {

    // MARK: - Test Variables

    var fileSaver: FileSaver!
    let fileManagerMock = FileManagerMock()

    // MARK: - Test Setup

    override func setUp() {
        super.setUp()
        fileSaver = FileSaver(fileManager: fileManagerMock)
    }

    override func tearDown() {
        fileSaver = nil
        super.tearDown()
    }

    // MARK: - Test Methods

    func testSaveFile_Success() {
        // Arrange
        let sourceURL = URL(string: "http://example.com/sourcefile.txt")!
        let destinationURL = URL(string: "file:///path/to/destinationfile.txt")!

        // Act & Assert
        XCTAssertNoThrow(try fileSaver.saveFile(from: sourceURL, to: destinationURL))
        XCTAssertTrue(fileManagerMock.didRemoveItem)
        XCTAssertTrue(fileManagerMock.didMoveItem)
    }

    func testSaveFile_ThrowsError() {
        // Arrange
        let sourceURL = URL(string: "http://example.com/sourcefile.txt")!
        let destinationURL = URL(string: "file:///path/to/destinationfile.txt")!
        fileManagerMock.shouldThrowError = true

        // Act & Assert
        // saveFile uses `try?` for the pre-removal, then `try moveItem` which throws.
        XCTAssertThrowsError(try fileSaver.saveFile(from: sourceURL, to: destinationURL))
        XCTAssertTrue(fileManagerMock.didRemoveItem)
        XCTAssertTrue(fileManagerMock.didMoveItem)
    }

    func testRemoveFile_Success() {
        // Arrange
        let sourceURL = URL(string: "file:///path/to/removable.txt")!

        // Act & Assert
        XCTAssertNoThrow(try fileSaver.removeFile(at: sourceURL))
        XCTAssertTrue(fileManagerMock.didRemoveItem)
    }

    func testRemoveFile_ThrowsError() {
        // Arrange
        let sourceURL = URL(string: "file:///path/to/removable.txt")!
        fileManagerMock.shouldThrowError = true

        // Act & Assert
        XCTAssertThrowsError(try fileSaver.removeFile(at: sourceURL))
    }

    func testGetDocumentsDirectoryURL() {
        // Arrange
        let filename = "testfile.txt"

        // Act
        let documentsDirectoryURL = fileSaver.getDocumentsDirectoryURL(forFilename: filename)

        // Assert
        XCTAssertEqual(documentsDirectoryURL.lastPathComponent, filename)
        XCTAssertEqual(documentsDirectoryURL.pathExtension, "txt")
    }
}
