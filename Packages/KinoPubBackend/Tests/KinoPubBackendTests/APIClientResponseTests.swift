//
//  APIClientResponseTests.swift
//
//
//  Exercises APIClient's decoding paths using the existing URLSessionMock:
//  - successful decoding of wrapped responses
//  - backend-error decoding (BackendError -> APIClientError.networkError)
//  - decoding-error path (APIClientError.decodingError)
//

import XCTest
@testable import KinoPubBackend

final class APIClientResponseTests: XCTestCase {

  var apiClient: APIClient!
  var sessionMock: URLSessionMock!

  override func setUp() {
    super.setUp()
    sessionMock = URLSessionMock()
    apiClient = APIClient(baseUrl: "https://api.example.com", session: sessionMock)
  }

  override func tearDown() {
    apiClient = nil
    sessionMock = nil
    super.tearDown()
  }

  // MARK: - Success decoding

  func testPerformRequest_DecodesSingleItemDataMediaItem() async throws {
    let json = """
    {
      "item": {
        "id": 555,
        "type": "movie",
        "subtype": "",
        "title": "Localized / Original",
        "year": 2021,
        "cast": "Some Cast",
        "director": "Some Director",
        "genres": [{ "id": 1, "title": "Action", "short_title": null }],
        "countries": [{ "id": 1, "title": "USA" }],
        "voice": null,
        "duration": { "average": 0, "total": 7200 },
        "langs": 1,
        "quality": 1080,
        "plot": "A plot",
        "imdb": 0,
        "imdb_rating": 7.5,
        "imdb_votes": 0,
        "kinopoisk": 0,
        "kinopoisk_rating": 8.0,
        "kinopoisk_votes": 0,
        "rating": 0,
        "rating_votes": 0,
        "rating_percentage": 0,
        "views": 100,
        "comments": 0,
        "posters": { "small": "s", "medium": "m", "big": "b", "wide": "w" },
        "trailer": null,
        "finished": true,
        "advert": false,
        "poor_quality": false,
        "created_at": 1000,
        "updated_at": 2000
      }
    }
    """
    sessionMock.data = json.data(using: .utf8)

    let response: SingleItemData<MediaItem> = try await apiClient.performRequest(
      with: RequestData(path: "/v1/items/555", method: "GET"),
      decodingType: SingleItemData<MediaItem>.self
    )

    XCTAssertEqual(response.item.id, 555)
    XCTAssertEqual(response.item.year, 2021)
    XCTAssertEqual(response.item.imdbRating, 7.5)
    XCTAssertEqual(response.item.localizedTitle, "Localized")
    XCTAssertEqual(response.item.originalTitle, "Original")
    XCTAssertEqual(response.item.posters.wide, "w")
  }

  func testPerformRequest_DecodesPaginatedDataMediaItem() async throws {
    let json = """
    {
      "items": [{
        "id": 1,
        "type": "movie",
        "subtype": "",
        "title": "Title",
        "year": 2020,
        "cast": "",
        "director": "",
        "genres": [],
        "countries": [],
        "voice": null,
        "duration": { "average": 0, "total": 60 },
        "langs": 0,
        "quality": 0,
        "plot": "",
        "rating": 0,
        "rating_votes": 0,
        "rating_percentage": 0,
        "views": 0,
        "comments": 0,
        "posters": { "small": "", "medium": "", "big": "", "wide": null },
        "trailer": null,
        "finished": false,
        "advert": false,
        "poor_quality": false,
        "created_at": 0,
        "updated_at": 0
      }],
      "pagination": { "total": 100, "current": 2, "perpage": 25 }
    }
    """
    sessionMock.data = json.data(using: .utf8)

    let response: PaginatedData<MediaItem> = try await apiClient.performRequest(
      with: RequestData(path: "/v1/items", method: "GET"),
      decodingType: PaginatedData<MediaItem>.self
    )

    XCTAssertEqual(response.items.count, 1)
    XCTAssertEqual(response.items.first?.id, 1)
    XCTAssertEqual(response.pagination.total, 100)
    XCTAssertEqual(response.pagination.current, 2)
    XCTAssertEqual(response.pagination.perpage, 25)
  }

  // MARK: - Backend error path

  func testPerformRequest_WhenBackendError_ThrowsNetworkError() async {
    let json = """
    {
      "status": 401,
      "error": "unauthorized",
      "error_description": "Token expired"
    }
    """
    sessionMock.data = json.data(using: .utf8)

    do {
      let _: SingleItemData<MediaItem> = try await apiClient.performRequest(
        with: RequestData(path: "/v1/items/1", method: "GET"),
        decodingType: SingleItemData<MediaItem>.self
      )
      XCTFail("Expected a network error but decoding succeeded")
    } catch APIClientError.networkError(let underlying) {
      guard let backendError = underlying as? BackendError else {
        XCTFail("Expected BackendError but got \(underlying)")
        return
      }
      XCTAssertEqual(backendError.status, 401)
      XCTAssertEqual(backendError.errorCode, .unauthorized)
      XCTAssertEqual(backendError.errorDescription, "Token expired")
    } catch {
      XCTFail("Expected APIClientError.networkError but got \(error)")
    }
  }

  // MARK: - Decoding error path

  func testPerformRequest_WhenInvalidJSON_ThrowsDecodingError() async {
    sessionMock.data = "{ not valid json".data(using: .utf8)

    do {
      let _: SingleItemData<MediaItem> = try await apiClient.performRequest(
        with: RequestData(path: "/v1/items/1", method: "GET"),
        decodingType: SingleItemData<MediaItem>.self
      )
      XCTFail("Expected a decoding error but decoding succeeded")
    } catch APIClientError.decodingError {
      // Expected
    } catch {
      XCTFail("Expected APIClientError.decodingError but got \(error)")
    }
  }
}
