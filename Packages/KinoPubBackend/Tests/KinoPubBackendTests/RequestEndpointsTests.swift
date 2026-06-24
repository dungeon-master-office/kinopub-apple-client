//
//  RequestEndpointsTests.swift
//
//
//  Tests that concrete Endpoint requests build the correct URLRequest
//  (path, HTTP method, query items / body) through the RequestBuilder.
//

import Foundation
import XCTest
@testable import KinoPubBackend

final class RequestEndpointsTests: XCTestCase {

  var requestBuilder: RequestBuilder!
  let baseURL = URL(string: "https://api.example.com")!

  override func setUp() {
    super.setUp()
    requestBuilder = RequestBuilder(baseURL: baseURL)
  }

  override func tearDown() {
    requestBuilder = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func queryItems(for endpoint: Endpoint) -> [String: String] {
    let request = requestBuilder.build(with: endpoint)
    guard let url = request?.url,
          let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
          let items = components.queryItems else {
      return [:]
    }
    var dict = [String: String]()
    for item in items {
      dict[item.name] = item.value
    }
    return dict
  }

  private func bodyDictionary(for endpoint: Endpoint) -> [String: Any] {
    let request = requestBuilder.build(with: endpoint)
    guard let body = request?.httpBody,
          let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
      return [:]
    }
    return object
  }

  // MARK: - ToggleWatchingRequest

  func testToggleWatchingRequest_PathAndMethod() {
    let endpoint = ToggleWatchingRequest(id: 42, video: 3, season: 2)
    let request = requestBuilder.build(with: endpoint)

    XCTAssertEqual(request?.url?.path, "/v1/watching/toggle")
    XCTAssertEqual(request?.httpMethod, "GET")
  }

  func testToggleWatchingRequest_IncludesAllParamsInQuery() {
    let endpoint = ToggleWatchingRequest(id: 42, video: 3, season: 2)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(items["id"], "42")
    XCTAssertEqual(items["video"], "3")
    XCTAssertEqual(items["season"], "2")
  }

  func testToggleWatchingRequest_OmitsSeasonWhenNotProvided() {
    // season defaults to -1 and must be filtered out
    let endpoint = ToggleWatchingRequest(id: 42, video: 3)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(items["id"], "42")
    XCTAssertEqual(items["video"], "3")
    XCTAssertNil(items["season"])
  }

  func testToggleWatchingRequest_ForceSendAsGetParamsKeepsBodyEmpty() {
    // method is GET here, but forceSendAsGetParams is true; ensure no body is set.
    let endpoint = ToggleWatchingRequest(id: 42, video: 3)
    let request = requestBuilder.build(with: endpoint)

    XCTAssertNil(request?.httpBody)
  }

  // MARK: - MarkTimeRequest

  func testMarkTimeRequest_PathMethodAndParams() {
    let endpoint = MarkTimeRequest(id: 7, time: 120, video: 1, season: 4)
    let request = requestBuilder.build(with: endpoint)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(request?.url?.path, "/v1/watching/marktime")
    XCTAssertEqual(request?.httpMethod, "GET")
    XCTAssertEqual(items["id"], "7")
    XCTAssertEqual(items["time"], "120")
    XCTAssertEqual(items["video"], "1")
    XCTAssertEqual(items["season"], "4")
  }

  func testMarkTimeRequest_OmitsOptionalNegativeOneParams() {
    let endpoint = MarkTimeRequest(id: 7, time: 120)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(items["id"], "7")
    XCTAssertEqual(items["time"], "120")
    XCTAssertNil(items["video"])
    XCTAssertNil(items["season"])
  }

  // MARK: - GetWatchingDataRequest

  func testGetWatchingDataRequest_OmitsNegativeOneParams() {
    let endpoint = GetWatchingDataRequest(id: 99)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(items["id"], "99")
    XCTAssertNil(items["video"])
    XCTAssertNil(items["season"])
  }

  func testGetWatchingDataRequest_IncludesProvidedParams() {
    let endpoint = GetWatchingDataRequest(id: 99, video: 5, season: 1)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(items["id"], "99")
    XCTAssertEqual(items["video"], "5")
    XCTAssertEqual(items["season"], "1")
  }

  // MARK: - SearchItemsRequest

  func testSearchItemsRequest_PathAndMethod() {
    let endpoint = SearchItemsRequest(contentType: .movie, page: 2, query: "matrix")
    let request = requestBuilder.build(with: endpoint)

    XCTAssertEqual(request?.url?.path, "/v1/items/search")
    XCTAssertEqual(request?.httpMethod, "GET")
  }

  func testSearchItemsRequest_WithQuery_EncodesAllParams() {
    let endpoint = SearchItemsRequest(contentType: .movie, page: 2, query: "matrix")
    let items = queryItems(for: endpoint)

    XCTAssertEqual(items["type"], MediaType.movie.rawValue)
    XCTAssertEqual(items["page"], "2")
    XCTAssertEqual(items["q"], "matrix")
  }

  func testSearchItemsRequest_WithoutQuery_OmitsQueryParam() {
    let endpoint = SearchItemsRequest(contentType: .serial)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(items["type"], MediaType.serial.rawValue)
    XCTAssertNil(items["q"])
    XCTAssertNil(items["page"])
  }

  func testSearchItemsRequest_WithNilContentType_HasNoParams() {
    let endpoint = SearchItemsRequest(contentType: nil)
    let items = queryItems(for: endpoint)

    XCTAssertTrue(items.isEmpty)
  }

  // MARK: - ItemDetailsRequest

  func testItemDetailsRequest_BuildsCorrectPath() {
    let endpoint = ItemDetailsRequest(id: "12345")
    let request = requestBuilder.build(with: endpoint)

    XCTAssertEqual(request?.url?.path, "/v1/items/12345")
    XCTAssertEqual(request?.httpMethod, "GET")
    XCTAssertNil(request?.httpBody)
  }

  // MARK: - BookmarkItemsRequest / BookmarksRequest

  func testBookmarkItemsRequest_BuildsCorrectPath() {
    let endpoint = BookmarkItemsRequest(id: "777")
    let request = requestBuilder.build(with: endpoint)

    XCTAssertEqual(request?.url?.path, "/v1/bookmarks/777")
    XCTAssertEqual(request?.httpMethod, "GET")
  }

  func testBookmarksRequest_BuildsCorrectPath() {
    let endpoint = BookmarksRequest()
    let request = requestBuilder.build(with: endpoint)

    XCTAssertEqual(request?.url?.path, "/v1/bookmarks")
    XCTAssertEqual(request?.httpMethod, "GET")
  }

  // MARK: - ShortcutItemsRequest

  func testShortcutItemsRequest_PathContainsShortcutRawValue() {
    let endpoint = ShortcutItemsRequest(shortcut: .hot, contentType: .movie, page: 3)
    let request = requestBuilder.build(with: endpoint)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(request?.url?.path, "/v1/items/hot")
    XCTAssertEqual(request?.httpMethod, "GET")
    XCTAssertEqual(items["type"], MediaType.movie.rawValue)
    XCTAssertEqual(items["page"], "3")
  }

  func testShortcutItemsRequest_WithoutPage_OmitsPage() {
    let endpoint = ShortcutItemsRequest(shortcut: .fresh, contentType: .serial)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(items["type"], MediaType.serial.rawValue)
    XCTAssertNil(items["page"])
  }

  // MARK: - GenresRequest / CountriesRequest

  func testGenresRequest_BuildsCorrectPath() {
    let endpoint = GenresRequest()
    let request = requestBuilder.build(with: endpoint)

    XCTAssertEqual(request?.url?.path, "/v1/countries")
    XCTAssertEqual(request?.httpMethod, "GET")
  }

  func testCountriesRequest_BuildsCorrectPath() {
    let endpoint = CountriesRequest()
    let request = requestBuilder.build(with: endpoint)

    XCTAssertEqual(request?.url?.path, "/v1/countries")
    XCTAssertEqual(request?.httpMethod, "GET")
  }

  // MARK: - DeviceCodeRequest (POST + forceSendAsGetParams)

  func testDeviceCodeRequest_ForceSendAsGetParams_PutsParamsInQueryEvenForPOST() {
    let endpoint = DeviceCodeRequest(grantType: .deviceCode,
                                     clientID: "client",
                                     clientSecret: "secret",
                                     code: "abc")
    let request = requestBuilder.build(with: endpoint)
    let items = queryItems(for: endpoint)

    XCTAssertEqual(request?.url?.path, "/oauth2/device")
    XCTAssertEqual(request?.httpMethod, "POST")
    // forceSendAsGetParams == true, so params go in the query string, not the body.
    XCTAssertNil(request?.httpBody)
    XCTAssertEqual(items["grant_type"], DeviceCodeGrantType.deviceCode.rawValue)
    XCTAssertEqual(items["client_id"], "client")
    XCTAssertEqual(items["client_secret"], "secret")
    XCTAssertEqual(items["code"], "abc")
  }

  func testDeviceCodeRequest_OmitsCodeWhenNil() {
    let endpoint = DeviceCodeRequest(grantType: .deviceToken,
                                     clientID: "client",
                                     clientSecret: "secret")
    let items = queryItems(for: endpoint)

    XCTAssertNil(items["code"])
    XCTAssertEqual(items["grant_type"], DeviceCodeGrantType.deviceToken.rawValue)
  }

  // MARK: - RefreshTokenRequest (POST -> JSON body)

  func testRefreshTokenRequest_PutsParamsInJSONBodyForPOST() {
    let endpoint = RefreshTokenRequest(clientID: "client",
                                       clientSecret: "secret",
                                       refreshToken: "refresh")
    let request = requestBuilder.build(with: endpoint)
    let body = bodyDictionary(for: endpoint)

    XCTAssertEqual(request?.url?.path, "/oauth2/token")
    XCTAssertEqual(request?.httpMethod, "POST")
    // forceSendAsGetParams == false, so params are serialized in the body.
    XCTAssertNil(request?.url?.query)
    XCTAssertEqual(body["grant_type"] as? String, "refresh_token")
    XCTAssertEqual(body["client_id"] as? String, "client")
    XCTAssertEqual(body["client_secret"] as? String, "secret")
    XCTAssertEqual(body["refresh_token"] as? String, "refresh")
  }
}
