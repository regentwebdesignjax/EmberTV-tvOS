import SwiftUI
import AVKit

struct PlayerView: View {
    let rental: Rental
    let resumeFrom: TimeInterval?

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerContainer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView("Loading…")
                    .foregroundColor(.white)
            }
        }
        // Use .task instead of manual Task { await ... }
        .task {
            await load()
        }
        .onDisappear {
            saveProgress()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: AVPlayerItem.didPlayToEndTimeNotification
            )
        ) { _ in
            // Clear progress when finished
            PlaybackProgressStore.clearProgress(for: rental.filmID)
        }
    }

    // MARK: - Load & Save

    private func load() async {
        guard let url = rental.film.hlsURL else { return }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)

        if let resumeFrom, resumeFrom > 10 {
            let time = CMTime(seconds: resumeFrom, preferredTimescale: 600)
            await newPlayer.seek(to: time)
        }

        await MainActor.run {
            self.player = newPlayer
            self.player?.play()
        }
    }

    private func saveProgress() {
        guard let player else { return }
        let seconds = player.currentTime().seconds
        guard !seconds.isNaN, seconds > 0 else { return }
        PlaybackProgressStore.saveProgress(seconds, for: rental.filmID)
    }
}
