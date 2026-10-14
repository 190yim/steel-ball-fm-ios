import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: RadioStore
    @EnvironmentObject private var player: RadioPlayer
    @State private var selectedTab = 0
    @State private var showFilters = false
    @State private var favoritesOnly = false
    @State private var listResetID = UUID()
    @State private var carMode = false
    @State private var showSleepTimer = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if selectedTab == 0 {
                    searchBar
                    if store.isLoading { ProgressView().tint(.mint).padding(.vertical, 8) }
                    if let message = store.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.orange).padding(.horizontal, 18).padding(.bottom, 8)
                    }
                    stationList
                } else if selectedTab == 1 {
                    explorer
                } else if selectedTab == 2 {
                    favoritesView
                } else {
                    nowPlayingView
                }
                if let station = player.currentStation, selectedTab != 3 { miniPlayer(station) }
                bottomBar
            }
        }
        .task { await store.loadInitial() }
        .sheet(isPresented: $showFilters) { filtersSheet }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("SteelBallLogo")
                .resizable().scaledToFill()
                .frame(width: 48, height: 48).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("STEEL BALL ").foregroundStyle(.white)
                    Text("FM").foregroundStyle(LinearGradient(colors: [.mint, .pink], startPoint: .leading, endPoint: .trailing))
                }
                .font(.system(size: 20, weight: .black, design: .rounded)).tracking(1.2)
                Text("Toute la radio, au même endroit.").font(.caption).foregroundStyle(.gray)
                Text("Developed by 190yim").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.30))
            }
            Spacer()
            Button { showFilters = true } label: {
                Image(systemName: "slider.horizontal.3").font(.title3).foregroundStyle(.white)
                    .frame(width: 42, height: 42).background(Color.white.opacity(0.08), in: Circle())
            }
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 14)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.gray)
            TextField("Rechercher une radio…", text: $store.searchText)
                .foregroundStyle(.white).submitLabel(.search)
                .onSubmit { Task { await store.search() } }
            Button { Task { await store.search() } } label: {
                Image(systemName: "arrow.right.circle.fill").font(.title2).foregroundStyle(.mint)
            }
            .accessibilityLabel("Rechercher")
        }
        .padding(13).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
        .padding(.horizontal, 18).padding(.bottom, 12)
    }

    private var stationList: some View {
        let stations = favoritesOnly ? store.stations.filter { store.favoriteIDs.contains($0.id) } : store.stations
        return Group {
            if stations.isEmpty && !store.isLoading {
                ContentUnavailableView(favoritesOnly ? "Aucun favori" : "Aucune station",
                                       systemImage: "dot.radiowaves.left.and.right",
                                       description: Text("Essaie une recherche ou ajoute une radio en favori."))
                    .foregroundStyle(.white)
            } else {
                List(stations) { station in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07))
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.title2)
                                .foregroundStyle(LinearGradient(colors: [.mint, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }.frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                            Text("\(station.displayCountry)\(station.firstTag.map { " · \($0)" } ?? "")")
                                .font(.caption).foregroundStyle(.gray).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Button { store.toggleFavorite(station) } label: {
                            Image(systemName: store.favoriteIDs.contains(station.id) ? "heart.fill" : "heart")
                                .foregroundStyle(store.favoriteIDs.contains(station.id) ? .pink : .gray)
                        }.buttonStyle(.plain)
                        Button { store.recordRecent(station); player.play(station) } label: {
                            Image(systemName: player.currentStation?.id == station.id && player.isPlaying ? "waveform" : "play.fill")
                                .font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                                .frame(width: 38, height: 38)
                                .background(LinearGradient(colors: [.mint, .pink], startPoint: .leading, endPoint: .trailing), in: Circle())
                        }.buttonStyle(.plain)
                    }
                    .padding(.vertical, 5).listRowBackground(Color.black).listRowSeparatorTint(Color.white.opacity(0.08))
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
                .id(listResetID)
            }
        }
    }

    private var explorer: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Explorer").font(.largeTitle.bold()).foregroundStyle(.white)
            Text("Choisis un pays ou un style musical pour découvrir de nouvelles stations.")
                .foregroundStyle(.gray)
            Button { showFilters = true } label: {
                Label("Pays et genres", systemImage: "globe.europe.africa.fill")
                    .font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [.mint, .pink], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16))
            }
            Spacer()
        }.padding(22)
    }

    private var favoritesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Favoris").font(.largeTitle.bold()).foregroundStyle(.white).padding(.horizontal, 20).padding(.top, 10)
            if !store.recentStations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Récemment écoutées").font(.headline).foregroundStyle(.white).padding(.horizontal, 18)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(store.recentStations.prefix(8)) { station in
                                Button { player.play(station); selectedTab = 3 } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Image(systemName: "dot.radiowaves.left.and.right").font(.title2).foregroundStyle(.mint)
                                        Text(station.name).font(.caption.weight(.semibold)).lineLimit(2).foregroundStyle(.white)
                                        Text(station.displayCountry).font(.caption2).foregroundStyle(.gray).lineLimit(1)
                                    }.frame(width: 120, height: 88, alignment: .leading).padding(10)
                                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                                }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, 18)
                    }
                }
            }
            stationList
        }
    }

    private var nowPlayingView: some View {
        Group {
            if let station = player.currentStation {
                VStack(spacing: 0) {
                    HStack {
                        Text(carMode ? "MODE VOITURE" : "À L’ÉCOUTE")
                            .font(.caption.weight(.bold)).tracking(2).foregroundStyle(.mint)
                        Spacer()
                        if player.isReconnecting {
                            ProgressView().tint(.mint)
                            Text("Reconnexion…").font(.caption2).foregroundStyle(.gray)
                        } else {
                            Circle().fill(player.isPlaying ? Color.mint : Color.gray).frame(width: 8, height: 8)
                            Text(player.isPlaying ? "EN DIRECT" : "EN PAUSE").font(.caption2.weight(.bold)).foregroundStyle(.gray)
                        }
                    }.padding(.horizontal, 22).padding(.top, 14)

                    Spacer(minLength: 10)
                    Image("SteelBallLogo")
                        .resizable().scaledToFit()
                        .frame(maxWidth: carMode ? 210 : 270, maxHeight: carMode ? 210 : 270)
                        .clipShape(Circle()).shadow(color: .pink.opacity(0.22), radius: 24)
                    Text(station.name)
                        .font(.system(size: carMode ? 25 : 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white).multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.75)
                        .padding(.horizontal, 22).padding(.top, 20)
                    Text(station.displayCountry + (station.firstTag.map { " · " + $0 } ?? ""))
                        .font(.subheadline).foregroundStyle(.gray).lineLimit(1).padding(.top, 7).padding(.horizontal, 20)
                    if let message = player.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center).padding(.horizontal, 24).padding(.top, 8)
                    }
                    Spacer(minLength: 18)

                    HStack(spacing: carMode ? 22 : 30) {
                        Button { store.toggleFavorite(station) } label: {
                            Image(systemName: store.favoriteIDs.contains(station.id) ? "heart.fill" : "heart")
                                .font(.system(size: carMode ? 28 : 23, weight: .semibold))
                                .foregroundStyle(store.favoriteIDs.contains(station.id) ? .pink : .white)
                                .frame(width: carMode ? 66 : 58, height: carMode ? 66 : 58)
                        }.accessibilityLabel(store.favoriteIDs.contains(station.id) ? "Retirer des favoris" : "Ajouter aux favoris")

                        Button { player.togglePlayback() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: carMode ? 34 : 30, weight: .bold)).foregroundStyle(.black)
                                .frame(width: carMode ? 104 : 88, height: carMode ? 104 : 88)
                                .background(LinearGradient(colors: [.mint, .pink], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                        }.accessibilityLabel(player.isPlaying ? "Mettre en pause" : "Reprendre la lecture")

                        Button { player.stop() } label: {
                            Image(systemName: "stop.fill").font(.system(size: carMode ? 26 : 22)).foregroundStyle(.white)
                                .frame(width: carMode ? 66 : 58, height: carMode ? 66 : 58)
                        }.accessibilityLabel("Arrêter la radio")
                    }.padding(.bottom, carMode ? 12 : 18)

                    HStack(spacing: 10) {
                        Button { carMode.toggle() } label: {
                            Label(carMode ? "Mode normal" : "Mode voiture", systemImage: "car.fill")
                                .font(.caption.weight(.semibold)).foregroundStyle(carMode ? .black : .white)
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(carMode ? Color.mint : Color.white.opacity(0.09), in: Capsule())
                        }
                        Button { showSleepTimer = true } label: {
                            Label(player.sleepTimerEnd != nil ? "Minuteur actif" : "Minuteur", systemImage: "moon.fill")
                                .font(.caption.weight(.semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(Color.white.opacity(0.09), in: Capsule())
                        }
                    }.padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .confirmationDialog("Minuteur de sommeil", isPresented: $showSleepTimer, titleVisibility: .visible) {
                    Button("15 minutes") { player.setSleepTimer(minutes: 15) }
                    Button("30 minutes") { player.setSleepTimer(minutes: 30) }
                    Button("45 minutes") { player.setSleepTimer(minutes: 45) }
                    Button("60 minutes") { player.setSleepTimer(minutes: 60) }
                    if player.sleepTimerEnd != nil { Button("Annuler le minuteur", role: .destructive) { player.cancelSleepTimer() } }
                    Button("Annuler", role: .cancel) { }
                } message: { Text("La radio s'arrêtera automatiquement à la fin du délai.") }
            } else {
                VStack(spacing: 18) {
                    Image("SteelBallLogo").resizable().scaledToFit().frame(width: 180, height: 180).clipShape(Circle())
                    Text("Rien à l’écoute").font(.title2.bold()).foregroundStyle(.white)
                    Text("Choisis une radio pour afficher le lecteur ici.").font(.subheadline).foregroundStyle(.gray).multilineTextAlignment(.center)
                    Button { selectedTab = 0 } label: {
                        Text("Choisir une radio").font(.headline).foregroundStyle(.black).padding(.horizontal, 26).padding(.vertical, 15)
                            .background(LinearGradient(colors: [.mint, .pink], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
            }
        }
    }

    private func miniPlayer(_ station: RadioStation) -> some View {
        HStack(spacing: 11) {
                Image("SteelBallLogo").resizable().scaledToFill().frame(width: 42, height: 42).clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(station.name).font(.subheadline.bold()).foregroundStyle(.white).lineLimit(1)
                    Text(player.isPlaying ? "EN DIRECT · À L’ÉCOUTE" : "EN PAUSE")
                        .font(.system(size: 10, weight: .bold)).tracking(1.1).foregroundStyle(.mint)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(.gray).padding(.trailing, 5)
                Button { player.togglePlayback() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3).foregroundStyle(.white).frame(width: 40, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Mettre en pause" : "Reprendre la lecture")
            }
            .padding(.horizontal, 18).padding(.vertical, 8).background(Color(white: 0.07))
            .contentShape(Rectangle())
            .onTapGesture { selectedTab = 3 }
    }

    private var bottomBar: some View {
        HStack {
            tabButton("house.fill", title: "Accueil", tab: 0)
            tabButton("globe", title: "Explorer", tab: 1)
            tabButton("heart", title: "Favoris", tab: 2)
            tabButton("waveform", title: "À l’écoute", tab: 3)
        }
        .padding(.top, 10).padding(.bottom, 4).background(Color.black)
    }

    private func tabButton(_ symbol: String, title: String, tab: Int) -> some View {
        Button {
            selectedTab = tab
            favoritesOnly = tab == 2
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 19, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? Color.mint : Color.gray)
            .frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    private var filtersSheet: some View {
        NavigationStack {
            Form {
                Section("Pays") {
                    Picker("Pays", selection: $store.selectedCountry) {
                        Text("Tous les pays").tag("")
                        ForEach(store.countries, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Genre musical") {
                    Picker("Genre", selection: $store.selectedGenre) {
                        Text("Tous les styles").tag("")
                        ForEach(["pop", "rock", "jazz", "classical", "news", "electronic", "reggae", "hip-hop", "talk"], id: \.self) {
                            Text($0.capitalized).tag($0)
                        }
                    }
                }
                Section {
                    Button("Appliquer") {
                        selectedTab = 0
                        favoritesOnly = false
                        listResetID = UUID()
                        showFilters = false
                        Task { await store.search() }
                    }.foregroundStyle(.mint)
                    Button("Effacer les filtres") {
                        store.selectedCountry = ""
                        store.selectedGenre = ""
                        store.searchText = ""
                    }.foregroundStyle(.pink)
                }
            }
            .navigationTitle("Explorer les radios")
            .navigationBarTitleDisplayMode(.inline)
        }.preferredColorScheme(.dark)
    }
}
