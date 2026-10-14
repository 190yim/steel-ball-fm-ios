import SwiftUI

@main
struct SteelBallFMApp: App {
    @StateObject private var store = RadioStore()
    @StateObject private var player = RadioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(player)
                .preferredColorScheme(.dark)
        }
    }
}
