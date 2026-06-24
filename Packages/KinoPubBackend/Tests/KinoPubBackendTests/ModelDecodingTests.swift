//
//  ModelDecodingTests.swift
//
//
//  Decodes representative JSON fixtures into the backend models and asserts
//  key fields and snake_case CodingKey mappings.
//

import Foundation
import XCTest
@testable import KinoPubBackend

final class ModelDecodingTests: XCTestCase {

  private let decoder = JSONDecoder()

  private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    let data = json.data(using: .utf8)!
    return try decoder.decode(T.self, from: data)
  }

  // MARK: - Pagination

  func testPagination_Decodes() throws {
    let json = """
    { "total": 250, "current": 3, "perpage": 25 }
    """
    let pagination = try decode(Pagination.self, from: json)

    XCTAssertEqual(pagination.total, 250)
    XCTAssertEqual(pagination.current, 3)
    XCTAssertEqual(pagination.perpage, 25)
  }

  // MARK: - Country

  func testCountry_Decodes() throws {
    let json = """
    { "id": 9, "title": "France" }
    """
    let country = try decode(Country.self, from: json)

    XCTAssertEqual(country.id, 9)
    XCTAssertEqual(country.title, "France")
  }

  // MARK: - FileInfo (snake_case quality_id)

  func testFileInfo_DecodesSnakeCaseQualityID_AndResolution() throws {
    let json = """
    {
      "codec": "h264",
      "w": 1920,
      "h": 1080,
      "quality": "1080p",
      "quality_id": 5,
      "url": { "http": "http://x", "hls": "h", "hls4": "h4", "hls2": "h2" }
    }
    """
    let info = try decode(FileInfo.self, from: json)

    XCTAssertEqual(info.codec, "h264")
    XCTAssertEqual(info.w, 1920)
    XCTAssertEqual(info.h, 1080)
    XCTAssertEqual(info.quality, "1080p")
    XCTAssertEqual(info.qualityID, 5)
    XCTAssertEqual(info.url.http, "http://x")
    XCTAssertEqual(info.url.hls4, "h4")
    // resolution drops the trailing "p" of the quality string.
    XCTAssertEqual(info.resolution, 1080)
  }

  // MARK: - Bookmark (count as Int or String)

  func testBookmark_DecodesNumericCountAsString() throws {
    let json = """
    {
      "id": 100,
      "title": "Favorites",
      "views": 3,
      "count": 42,
      "created": 1700000000,
      "updated": 1710000000
    }
    """
    let bookmark = try decode(Bookmark.self, from: json)

    XCTAssertEqual(bookmark.id, 100)
    XCTAssertEqual(bookmark.title, "Favorites")
    XCTAssertEqual(bookmark.views, 3)
    XCTAssertEqual(bookmark.count, "42")
    XCTAssertEqual(bookmark.created, 1700000000)
    XCTAssertEqual(bookmark.updated, 1710000000)
  }

  func testBookmark_DecodesStringCount() throws {
    let json = """
    {
      "id": 101,
      "title": "Later",
      "views": 0,
      "count": "7",
      "created": 1,
      "updated": 2
    }
    """
    let bookmark = try decode(Bookmark.self, from: json)

    XCTAssertEqual(bookmark.count, "7")
  }

  // MARK: - Episode / EpisodeWatching

  func testEpisode_Decodes() throws {
    let json = """
    {
      "id": 11,
      "title": "Pilot",
      "thumbnail": "thumb",
      "duration": 2700,
      "tracks": 2,
      "number": 1,
      "ac3": 0,
      "audios": [],
      "watched": 0,
      "watching": { "status": -1, "time": 0 },
      "subtitles": [],
      "files": []
    }
    """
    let episode = try decode(Episode.self, from: json)

    XCTAssertEqual(episode.id, 11)
    XCTAssertEqual(episode.title, "Pilot")
    XCTAssertEqual(episode.number, 1)
    XCTAssertEqual(episode.watching.status, -1)
    XCTAssertEqual(episode.fixedTitle, "Pilot")
  }

  func testEpisode_FixedTitleFallsBackToNumber() throws {
    let json = """
    {
      "id": 12,
      "title": "",
      "thumbnail": "",
      "duration": 0,
      "tracks": 0,
      "number": 5,
      "ac3": 0,
      "audios": [],
      "watched": 0,
      "watching": { "status": 0, "time": 0 },
      "subtitles": [],
      "files": []
    }
    """
    let episode = try decode(Episode.self, from: json)

    XCTAssertEqual(episode.fixedTitle, "Серия 5")
  }

  // MARK: - Season

  func testSeason_DecodesWithEpisodes() throws {
    let json = """
    {
      "id": 1,
      "title": "",
      "number": 2,
      "watching": { "status": 1 },
      "episodes": [{
        "id": 21,
        "title": "Ep",
        "thumbnail": "",
        "duration": 100,
        "tracks": 1,
        "number": 1,
        "ac3": 0,
        "audios": [],
        "watched": 1,
        "watching": { "status": 1, "time": 50 },
        "subtitles": [],
        "files": []
      }]
    }
    """
    let season = try decode(Season.self, from: json)

    XCTAssertEqual(season.id, 1)
    XCTAssertEqual(season.number, 2)
    XCTAssertEqual(season.watching.status, 1)
    XCTAssertEqual(season.episodes.count, 1)
    XCTAssertEqual(season.episodes.first?.id, 21)
    XCTAssertEqual(season.fixedTitle, "Сезон 2")
  }

  // MARK: - WatchData (nested types)

  func testWatchData_DecodesNestedSeasonsAndVideos() throws {
    let json = """
    {
      "item": {
        "seasons": [{
          "id": 1,
          "number": 1,
          "status": 0,
          "episodes": [{ "id": 5, "number": 1, "title": "E1", "time": 12.5, "status": 1 }]
        }],
        "videos": [{ "id": 9, "number": 1, "title": "V1", "time": 30.0, "status": 0 }]
      }
    }
    """
    let watchData = try decode(WatchData.self, from: json)

    XCTAssertEqual(watchData.item.seasons?.count, 1)
    XCTAssertEqual(watchData.item.seasons?.first?.episodes.first?.id, 5)
    XCTAssertEqual(watchData.item.seasons?.first?.episodes.first?.time, 12.5)
    XCTAssertEqual(watchData.item.videos?.first?.id, 9)
    XCTAssertEqual(watchData.item.videos?.first?.time, 30.0)
  }

  // MARK: - UserData (snake_case keys)

  func testUserData_DecodesSnakeCaseKeys() throws {
    let json = """
    {
      "username": "tester",
      "reg_date": 1600000000,
      "settings": { "show_erotic": true, "show_uncertain": false },
      "subscription": { "active": true, "end_time": 1700000000, "days": 30.5 },
      "profile": { "name": "Tester Full", "avatar": "avatar.png" }
    }
    """
    let userData = try decode(UserData.self, from: json)

    XCTAssertEqual(userData.username, "tester")
    XCTAssertEqual(userData.registrationDate, 1600000000)
    XCTAssertTrue(userData.settings.showErotic)
    XCTAssertFalse(userData.settings.showUncertain)
    XCTAssertTrue(userData.subscription.active)
    XCTAssertEqual(userData.subscription.endTime, 1700000000)
    XCTAssertEqual(userData.subscription.days, 30.5)
    XCTAssertEqual(userData.profile.name, "Tester Full")
  }

  // MARK: - AccessToken (snake_case keys)

  func testAccessToken_DecodesSnakeCaseKeys() throws {
    let json = """
    {
      "access_token": "AAA",
      "refresh_token": "RRR",
      "expires_in": 3600
    }
    """
    let token = try decode(AccessToken.self, from: json)

    XCTAssertEqual(token.accessToken, "AAA")
    XCTAssertEqual(token.refreshToken, "RRR")
    XCTAssertEqual(token.expiresIn, 3600)
  }

  // MARK: - TypeClass (snake_case short_title)

  func testTypeClass_DecodesShortTitle() throws {
    let json = """
    { "id": 3, "title": "Drama", "short_title": "Dr" }
    """
    let typeClass = try decode(TypeClass.self, from: json)

    XCTAssertEqual(typeClass.id, 3)
    XCTAssertEqual(typeClass.title, "Drama")
    XCTAssertEqual(typeClass.shortTitle, "Dr")
  }

  // MARK: - BackendError

  func testBackendError_DecodesErrorKeyMapping() throws {
    let json = """
    { "status": 400, "error": "invalid_client", "error_description": "bad client" }
    """
    let error = try decode(BackendError.self, from: json)

    XCTAssertEqual(error.status, 400)
    XCTAssertEqual(error.errorCode, .invalidClient)
    XCTAssertEqual(error.errorDescription, "bad client")
  }
}
