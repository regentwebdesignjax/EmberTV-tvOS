import SwiftUI

struct RentalDetailView: View {
    let rental: Rental

    @State private var showPlayer = false

    private var film: RentalFilmSummary { rental.film }

    // MARK: - Resume logic
    private var resumeSeconds: TimeInterval? {
        PlaybackProgressStore.progress(for: film.id)
    }

    private var totalDurationSeconds: TimeInterval? {
        guard let minutes = film.durationMinutes else { return nil }
        return TimeInterval(minutes * 60)
    }

    private var watchedPercent: Double? {
        guard
            let resume = resumeSeconds,
            let total = totalDurationSeconds,
            total > 0
        else { return nil }

        return resume / total
    }

    private var primaryButtonTitle: String {
        if let resume = resumeSeconds, resume > 60 {
            return "Resume"
        } else {
            return "Watch Now"
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // LAYER 1: Cinematic Blurred Background
            GeometryReader { geo in
                AsyncImage(url: film.posterURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        EmberTheme.background
                    }
                }
                .blur(radius: 60)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    EmberTheme.background.opacity(0.4),
                                    EmberTheme.background.opacity(0.95)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
            }
            .ignoresSafeArea()

            // LAYER 2: Content
            VStack(alignment: .leading, spacing: 0) {
                
                // Logo header remains pinned to top-left
                Image("ember-tv-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .padding(.leading, 80)
                    .padding(.top, 60)

                Spacer() // Pushes content down from the top

                // Main Content Block (Centered horizontally and vertically)
                HStack(alignment: .center, spacing: 80) {
                    
                    // Poster hero
                    RentalPosterHero(film: film)
                        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)

                    // Details block
                    VStack(alignment: .leading, spacing: 32) {
                        Text(film.title)
                            .font(EmberTheme.titleFont(72))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        HStack(spacing: 24) {
                            if let genre = film.genre, !genre.isEmpty {
                                Text(genre.uppercased())
                                    .font(EmberTheme.bodySemibold(20))
                                    .kerning(2)
                                    .foregroundColor(EmberTheme.primary)
                            }
                            
                            if let minutes = film.durationMinutes {
                                Text("\(minutes) MIN")
                                    .font(EmberTheme.bodyFont(20))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Text("HD")
                                .font(EmberTheme.captionFont(16))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.4), lineWidth: 1))
                        }

                        if let long = film.longDescription, !long.isEmpty {
                            Text(long)
                                .font(EmberTheme.bodyFont(24))
                                .foregroundColor(.white.opacity(0.8))
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Actions Area
                        VStack(alignment: .leading, spacing: 20) {
                            Button {
                                showPlayer = true
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: primaryButtonTitle == "Resume" ? "play.fill" : "play.rectangle.fill")
                                    Text(primaryButtonTitle)
                                }
                            }
                            .buttonStyle(EmberPrimaryPillButtonStyle())

                            // Progress & Expiration Info
                            Group {
                                if let percent = watchedPercent, percent > 0.05 {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("\(Int(percent * 100))% Watched")
                                            .font(EmberTheme.captionFont(18))
                                            .foregroundColor(EmberTheme.textSecondary)
                                        
                                        // Mini progress bar
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.white.opacity(0.2))
                                                .frame(width: 300, height: 4)
                                            Capsule().fill(EmberTheme.primary)
                                                .frame(width: 300 * CGFloat(percent), height: 4)
                                        }
                                    }
                                } else {
                                    // FIXED: Updated to 48 hours
                                    Text("Available for 48 hour unlimited access")
                                        .font(EmberTheme.captionFont(18))
                                        .foregroundColor(EmberTheme.textSecondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 900, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(rental: rental, resumeFrom: resumeSeconds)
        }
    }
}

// MARK: - Poster hero
private struct RentalPosterHero: View {
    let film: RentalFilmSummary
    private let width: CGFloat = 320
    private let height: CGFloat = 480

    var body: some View {
        AsyncImage(url: film.posterURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView()
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Primary pill button
struct EmberPrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EmberPrimaryPillButton(configuration: configuration)
    }

    private struct EmberPrimaryPillButton: View {
        @Environment(\.isFocused) private var isFocused: Bool
        let configuration: Configuration

        var body: some View {
            configuration.label
                .padding(.horizontal, 44)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        Capsule()
                            .fill(isFocused ? EmberTheme.primary : Color.white.opacity(0.1))
                        
                        if isFocused {
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .blur(radius: 1)
                        }
                    }
                )
                .foregroundColor(isFocused ? .white : .white.opacity(0.8))
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .shadow(
                    color: isFocused ? EmberTheme.primary.opacity(0.4) : .clear,
                    radius: 20, x: 0, y: 10
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .focusEffectDisabled(true)
        }
    }
}
