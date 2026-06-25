//
//  APIClient.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public class APIClient {
  private let session: URLSessionProtocol
  private let requestBuilder: RequestBuilder
  private let baseUrl: URL
  private var plugins: [APIClientPlugin]
  private let cache: ResponseCaching?

  public init(baseUrl: String,
              plugins: [APIClientPlugin] = [],
              session: URLSessionProtocol = URLSessionImpl(session: .shared),
              cache: ResponseCaching? = nil) {
    self.baseUrl = URL(string: baseUrl)!
    self.plugins = plugins
    self.session = session
    self.cache = cache
    self.requestBuilder = RequestBuilder(baseURL: self.baseUrl)
  }

  /// - Parameter forceRefresh: when true, skips any cached value and always hits the network
  ///   (the fresh result still updates the cache). Pull-to-refresh paths pass `true`.
  public func performRequest<T: Decodable>(with requestData: Endpoint,
                                           decodingType: T.Type,
                                           forceRefresh: Bool = false) async throws -> T {
    // Serve from cache when the request opts in and we're not force-refreshing.
    let cacheable = requestData as? CacheableRequest
    let policy = cacheable?.cachePolicy ?? .noCache
    if !forceRefresh, let cacheable, policy.ttl != nil,
       let cachedData = cache?.data(for: cacheable.cacheKey),
       let cached = try? JSONDecoder().decode(T.self, from: cachedData) {
      return cached
    }

    guard let request = requestBuilder.build(with: requestData) else {
      throw APIClientError.invalidUrlParams
    }

    let preparedRequest = plugins.reduce(request) { $1.prepare(request) }
    // Notify plugins
    plugins.forEach { $0.willSend(preparedRequest) }

    let (data, response) = try await session.data(for: preparedRequest)

    // Notify plugins
    plugins.forEach { $0.didReceive(response, data: data) }

    let result = try decode(T.self, from: data, throwDecodingErrorImmediately: false)
    // Cache only successfully decoded responses (never error bodies), per the request's policy.
    if let cacheable, let ttl = policy.ttl {
      cache?.store(data, for: cacheable.cacheKey, ttl: ttl, persist: policy.persistsToDisk)
    }
    return result
  }

  /// Drops all cached responses. Call on logout so the next user never sees cached data.
  public func clearCache() {
    cache?.clear()
  }

  private func decode<T: Decodable>(_ type: T.Type,
                                    from data: Data,
                                    throwDecodingErrorImmediately: Bool) throws -> T where T: Decodable {
    do {
      let result = try JSONDecoder().decode(T.self, from: data)
      return result
    } catch {
      if throwDecodingErrorImmediately {
        throw APIClientError.decodingError(error)
      }

      if let backendError = try? JSONDecoder().decode(BackendError.self, from: data) {
        throw APIClientError.networkError(backendError)
      }

      throw APIClientError.decodingError(error)
    }
  }
}
