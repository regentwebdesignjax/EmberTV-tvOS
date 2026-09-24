import SwiftUI
import AVKit
import Combine

/// Full-screen playback. Every play asks the server for a fresh signed HLS
/// URL (it checks the rental and binds the link to this TV), then reports
/// the position every 30 seconds and on close so the viewer can resume here
/// or on any other device.
struct PlayerView: View {
    let rental: Rental
    let resumeFrom: TimeInterval?
    /// Called when the player closes with the position to resume from next
    /// time (nil: start from the beginning).
    var onClose: (TimeInterval?) -> Void = { _ in }

    // Sheets don't reliably inherit environment objects, so use the shared client.
    private let api = EmberAPIClient.shared
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var errorMessage: String?
    @State private var finished = false

    private static let heartbeatSeconds: UInt64 = 30

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerContainer(player: player)
                    .ignoresSafeArea()
            } else if let errorMessage {
                VStack(spacing: 32) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 72))
                        .foregroundColor(EmberTheme.primary)
                    Text("Can't play this film")
                        .font(EmberTheme.headingFont(40))
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .font(EmberTheme.bodyFont(24))
                        .foregroundColor(EmberTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 900)
                    Button("Close") { dismiss() }
                        .buttonStyle(EmberPrimaryPillButtonStyle())
                }
            } else {
                ProgressView("Loading…")
                    .foregroundColor(.white)
            }
        }
        .task {
            await load()
            await heartbeat()
        }
        .onDisappear {
            close()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
        ) { note in
            guard let item = note.object as? AVPlayerItem, item === player?.currentItem else { return }
            // Watched to the end: next time starts from the beginning.
            finished = true
            let filmID = rental.film.id
            Task { await api.reportProgress(filmID: filmID, seconds: 0) }
        }
    }

    // MARK: - Load

    private func load() async {
        do {
            let url = try await api.startPlayback(filmID: rental.film.id)
            let item = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer

            if let start = startPosition {
                // Seek once the stream is ready; seeking earlier is unreliable.
                for await status in item.publisher(for: \.status).values where status != .unknown {
                    break
                }
                if item.status == .readyToPlay {
                    await newPlayer.seek(to: CMTime(seconds: start, preferredTimescale: 600))
                }
            }
            newPlayer.play()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Where to start: the resume point, unless it is too early to matter or
    /// within the last minute (then the film was essentially finished).
    private var startPosition: TimeInterval? {
        guard let resumeFrom, resumeFrom > 10 else { return nil }
        if let minutes = rental.film.durationMinutes, minutes > 0,
           resumeFrom > Double(minutes * 60) - 60 {
            return nil
        }
        return resumeFrom
    }

    // MARK: - Progress

    private func heartbeat() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: Self.heartbeatSeconds * 1_000_000_000)
            guard !Task.isCancelled, let player, player.timeControlStatus == .playing else { continue }
            await api.reportProgress(filmID: rental.film.id, seconds: player.currentTime().seconds)
        }
    }

    private func close() {
        guard let player else { return }   // never started: keep the old resume point
        player.pause()
        let seconds = player.currentTime().seconds
        let position: TimeInterval = finished || !seconds.isFinite ? 0 : seconds
        onClose(position > 10 ? position : nil)

        let filmID = rental.film.id
        Task { await api.reportProgress(filmID: filmID, seconds: position) }
    }
}
