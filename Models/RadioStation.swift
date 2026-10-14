import Foundation

struct RadioStation: Identifiable, Codable, Hashable {
    let stationuuid: String
    let name: String
    let url: String
    let url_resolved: String?
    let homepage: String?
    let favicon: String?
    let country: String?
    let countrycode: String?
    let tags: String?
    let language: String?
    let codec: String?
    let bitrate: Int?

    var id: String { stationuuid }

    var streamURL: URL? {
        let candidate = (url_resolved?.isEmpty == false) ? url_resolved! : url
        guard let parsed = URL(string: candidate),
              ["http", "https"].contains(parsed.scheme?.lowercased() ?? "") else { return nil }
        return parsed
    }

    var displayCountry: String {
        let value = country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Pays inconnu" : value
    }

    var firstTag: String? {
        tags?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
