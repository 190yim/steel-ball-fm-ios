import Foundation
import Combine

@MainActor
final class RadioStore: ObservableObject {
    @Published private(set) var stations: [RadioStation] = []
    @Published private(set) var countries: [String] = []
    @Published var searchText = ""
    @Published var selectedCountry = ""
    @Published var selectedGenre = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: "SteelBallFM.favorites") ?? [])
    @Published private(set) var recentStations: [RadioStation] = {
        guard let data = UserDefaults.standard.data(forKey: "SteelBallFM.recentStations"),
              let stations = try? JSONDecoder().decode([RadioStation].self, from: data) else { return [] }
        return stations
    }()

    func recordRecent(_ station: RadioStation) {
        recentStations.removeAll { $0.id == station.id }
        recentStations.insert(station, at: 0)
        recentStations = Array(recentStations.prefix(20))
        if let data = try? JSONEncoder().encode(recentStations) {
            UserDefaults.standard.set(data, forKey: "SteelBallFM.recentStations")
        }
    }

    private let service = RadioCatalogService()

    func loadInitial() async {
        guard stations.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let loadedStations = service.popularStations()
            async let loadedCountries = service.countries()
            let (s, c) = try await (loadedStations, loadedCountries)
            stations = s
            countries = c
        } catch {
            errorMessage = "Catalogue inaccessible. Vérifie la connexion puis réessaie."
        }
    }

    func search() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            stations = try await service.search(name: searchText, country: selectedCountry, genre: selectedGenre)
            if stations.isEmpty { errorMessage = "Aucune station trouvée. Modifie ta recherche." }
        } catch {
            errorMessage = "Recherche impossible pour le moment. Réessaie dans un instant."
        }
    }

    func toggleFavorite(_ station: RadioStation) {
        if favoriteIDs.contains(station.id) { favoriteIDs.remove(station.id) }
        else { favoriteIDs.insert(station.id) }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: "SteelBallFM.favorites")
    }
}
