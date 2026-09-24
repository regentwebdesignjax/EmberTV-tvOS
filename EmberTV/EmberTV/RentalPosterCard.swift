import SwiftUI
import Combine // FIXED: Added Combine to allow the Timer publisher to work!

struct RentalPosterCard: View {
    let rental: Rental

    @Environment(\.isFocused) private var isFocused: Bool
    
    // MARK: - Real-Time Timer
    // This tracks the current time and ticks every 60 seconds
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        // Changed to .center so the countdown pill sits perfectly in the middle under the poster
        VStack(alignment: .center, spacing: 16) {
            
            // Poster
            AsyncImage(url: rental.film.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    Color.black.opacity(0.6)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.5))
                        )
                case .empty:
                    Color.black.opacity(0.6)
                        .overlay(ProgressView())
                @unknown default:
                    Color.black
                }
            }
            .frame(width: 250, height: 375)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: isFocused ? EmberTheme.primary.opacity(0.6) : .black.opacity(0.4),
                    radius: isFocused ? 20 : 10, x: 0, y: isFocused ? 15 : 10)

            // Dynamic Countdown Pill
            if let expiresAt = rental.expiresAt {
                Text(expirationText(from: expiresAt, referenceTime: currentTime))
                    .font(EmberTheme.bodySemibold(16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            // A dark background guarantees it's always readable over bright blurs!
                            .fill(Color.black.opacity(0.75))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isFocused ? 0.4 : 0.1), lineWidth: 1)
                    )
                    // Listens for the timer and triggers a UI update every minute
                    .onReceive(timer) { newTime in
                        currentTime = newTime
                    }
            }
        }
        .padding(10)
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }

    // Updated to calculate the remaining time based on our real-time variable
    private func expirationText(from date: Date, referenceTime: Date) -> String {
        let remaining = date.timeIntervalSince(referenceTime)
        guard remaining > 0 else { return "Expired" }

        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "Expires in \(hours)h \(minutes)m"
        } else {
            return "Expires in \(minutes)m"
        }
    }
}
