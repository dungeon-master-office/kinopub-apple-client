//
//  TMDBService.swift
//  KinoPubAppleClient
//
//  Resolves actor/director names to portrait photos via TMDB, since kino.pub returns
//  cast/director as plain text only. Results are cached in-memory per session.
//

import Foundation

protocol TMDBService {
  func personImageURL(for name: String) async -> URL?
}

protocol TMDBServiceProvider {
  var tmdbService: TMDBService { get }
}

final class TMDBServiceImpl: TMDBService {

  private let apiKey: String
  private let session: URLSession
  private let cache = NSCache<NSString, NSURL>()
  private var misses = Set<String>()
  private let lock = NSLock()

  init(apiKey: String, session: URLSession = .shared) {
    self.apiKey = apiKey
    self.session = session
  }

  func personImageURL(for name: String) async -> URL? {
    let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty, !apiKey.isEmpty else { return nil }

    lock.lock()
    if let cached = cache.object(forKey: key as NSString) {
      lock.unlock()
      return cached as URL
    }
    if misses.contains(key) {
      lock.unlock()
      return nil
    }
    lock.unlock()

    guard var components = URLComponents(string: "https://api.themoviedb.org/3/search/person") else { return nil }
    components.queryItems = [
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "query", value: key),
      URLQueryItem(name: "include_adult", value: "false")
    ]
    guard let url = components.url else { return nil }

    do {
      let (data, _) = try await session.data(from: url)
      let response = try JSONDecoder().decode(PersonSearchResponse.self, from: data)
      if let path = response.results.first(where: { $0.profilePath != nil })?.profilePath,
         let imageURL = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
        lock.lock()
        cache.setObject(imageURL as NSURL, forKey: key as NSString)
        lock.unlock()
        return imageURL
      }
    } catch {
      // Network/decoding failures fall through to "no photo".
    }

    lock.lock()
    misses.insert(key)
    lock.unlock()
    return nil
  }

  private struct PersonSearchResponse: Decodable {
    let results: [Person]
    struct Person: Decodable {
      let profilePath: String?
      enum CodingKeys: String, CodingKey { case profilePath = "profile_path" }
    }
  }
}

struct TMDBServiceMock: TMDBService {
  func personImageURL(for name: String) async -> URL? { nil }
}
