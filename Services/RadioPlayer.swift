import Foundation
import Combine
import AVFoundation
import MediaPlayer

@MainActor
final class RadioPlayer: ObservableObject {
    @Published private(set) var currentStation: RadioStation?
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?
    private var player: AVPlayer?
    private var itemObservers: [NSObjectProtocol] = []
    private var reconnectAttempts = 0
    private var sleepTask: Task<Void, Never>?
    @Published private(set) var sleepTimerEnd: Date?
    @Published private(set) var isReconnecting = false

    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Configuration audio indisponible."
        }
        configureRemoteCommands()
    }

    func play(_ station: RadioStation) {
        guard let url = station.streamURL else {
            errorMessage = "Flux audio invalide pour cette station."
            return
        }
        if currentStation?.id == station.id, let player {
            player.play()
        } else {
            player?.pause()
            removeItemObservers()
            currentStation = station
            reconnectAttempts = 0
            isReconnecting = false
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            observe(item: item)
            player?.play()
        }
        isPlaying = true
        errorMessage = nil
        updateNowPlaying()
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
        updateNowPlaying()
    }

    func stop() {
        player?.pause()
        player = nil
        removeItemObservers()
        currentStation = nil
        isPlaying = false
        isReconnecting = false
        cancelSleepTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func setSleepTimer(minutes: Int?) {
        sleepTask?.cancel()
        sleepTask = nil
        sleepTimerEnd = nil
        guard let minutes, minutes > 0 else { return }
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerEnd = end
        sleepTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(minutes * 60))
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.stop() }
            } catch { }
        }
    }

    func cancelSleepTimer() { setSleepTimer(minutes: nil) }

    private func observe(item: AVPlayerItem) {
        let center = NotificationCenter.default
        itemObservers.append(center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.attemptReconnect() }
        })
        itemObservers.append(center.addObserver(forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.attemptReconnect() }
        })
        itemObservers.append(center.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.attemptReconnect() }
        })
    }

    private func removeItemObservers() {
        itemObservers.forEach(NotificationCenter.default.removeObserver)
        itemObservers.removeAll()
    }

    private func attemptReconnect() {
        guard isPlaying, let station = currentStation, let url = station.streamURL else { return }
        guard reconnectAttempts < 3 else {
            isReconnecting = false
            errorMessage = "La station ne répond pas. Essaie une autre radio."
            return
        }
        reconnectAttempts += 1
        isReconnecting = true
        let delay = UInt64(reconnectAttempts * 2)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.isPlaying, self.currentStation?.id == station.id else { return }
            self.removeItemObservers()
            let item = AVPlayerItem(url: url)
            self.player?.replaceCurrentItem(with: item)
            self.observe(item: item)
            self.player?.play()
            self.isReconnecting = false
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if let self, !self.isPlaying { self.togglePlayback() }
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if let self, self.isPlaying { self.togglePlayback() }
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let station = currentStation else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: station.name,
            MPMediaItemPropertyArtist: station.displayCountry,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }
}
