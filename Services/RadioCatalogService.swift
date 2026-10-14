import Foundation

struct RadioCatalogService {
    private let base = "https://de1.api.radio-browser.info/json"

    func popularStations() async throws -> [RadioStation] {
        try await fetch(URL(string: base + "/stations?hidebroken=true&order=votes&reverse=true&limit=100")!)
    }

    func search(name: String, country: String, genre: String) async throws -> [RadioStation] {
        var components = URLComponents(string: base + "/stations/search")!
        var items = [
            URLQueryItem(name: "hidebroken", value: "true"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "order", value: "votes"),
            URLQueryItem(name: "reverse", value: "true")
        ]
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(URLQueryItem(name: "name", value: name))
        }
        if !country.isEmpty { items.append(URLQueryItem(name: "country", value: country)) }
        if !genre.isEmpty { items.append(URLQueryItem(name: "tag", value: genre)) }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        return try await fetch(url)
    }

    func countries() async throws -> [String] {
        var components = URLComponents(string: base + "/countries")!
        components.queryItems = [
            URLQueryItem(name: "order", value: "stationcount"),
            URLQueryItem(name: "reverse", value: "true")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        struct Country: Decodable { let name: String? }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([Country].self, from: data).compactMap(\.name).filter { !$0.isEmpty }
    }

    private func fetch(_ url: URL) async throws -> [RadioStation] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("SteelBallFM/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([RadioStation].self, from: data)
            .filter { !$0.name.isEmpty && $0.streamURL != nil }
    }
}
