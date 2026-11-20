import Foundation

struct Track: Equatable {
    let title: String
    let artist: String
    let album: String
    let start: Date
    let end: Date

    /// "Tarantula — Spin"
    var shortDescription: String {
        artist.isEmpty ? title : "\(title) — \(artist)"
    }
}

/// Reads the playlist that powers kmhd.org/playlist.
/// The feed is undocumented, so every failure just leaves the last known tracks in place.
enum Playlist {
    private static let pacific = TimeZone(identifier: "America/Los_Angeles")!

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = pacific
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoFormatter = ISO8601DateFormatter()

    /// Most recent tracks first. Pulls in yesterday (Pacific time) too when today has barely started.
    static func fetchRecent(completion: @escaping ([Track]) -> Void) {
        let now = Date()
        Playlist.fetch(day: Playlist.dayFormatter.string(from: now)) { today in
            if today.count >= 6 {
                completion(today)
                return
            }
            let yesterday = Playlist.dayFormatter.string(from: now.addingTimeInterval(-86_400))
            Playlist.fetch(day: yesterday) { earlier in
                completion((today + earlier).sorted { $0.start > $1.start })
            }
        }
    }

    /// Calls completion on the main queue.
    private static func fetch(day: String, completion: @escaping ([Track]) -> Void) {
        var components = URLComponents(string: "https://www.kmhd.org/pf/api/v3/content/fetch/playlist")!
        components.queryItems = [
            URLQueryItem(name: "query", value: "{\"day\":\"\(day)\"}"),
            URLQueryItem(name: "_website", value: "kmhd"),
        ]
        guard let url = components.url else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let tracks = data.map(Playlist.parse) ?? []
            DispatchQueue.main.async { completion(tracks) }
        }.resume()
    }

    private static func parse(_ data: Data) -> [Track] {
        guard let items = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }
        let tracks: [Track] = items.compactMap { item in
            guard let title = item["title"] as? String, !title.isEmpty,
                  let startUTC = (item["start"] as? [String: Any])?["utc"] as? String,
                  let start = Playlist.isoFormatter.date(from: startUTC) else { return nil }

            let artist: String
            if let artists = item["artist"] as? [String] {
                artist = artists.joined(separator: ", ")
            } else {
                artist = item["artist"] as? String ?? ""
            }

            let end: Date
            if let endUTC = (item["end"] as? [String: Any])?["utc"] as? String,
               let parsed = Playlist.isoFormatter.date(from: endUTC) {
                end = parsed
            } else if let duration = item["duration"] as? Double {
                end = start.addingTimeInterval(duration / 1000)
            } else {
                end = start.addingTimeInterval(300)
            }

            return Track(title: title, artist: artist, album: item["album"] as? String ?? "", start: start, end: end)
        }
        return tracks.sorted { $0.start > $1.start }
    }
}
