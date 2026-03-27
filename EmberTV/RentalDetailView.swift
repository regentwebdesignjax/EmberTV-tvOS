import SwiftUI

struct RentalDetailView: View {
    let rental: Rental
    @State private var showPlayer = false
    private var film: RentalFilmSummary { rental.film }

    private var resumeSeconds: TimeInterval? {
        PlaybackProgressStore.progress(for: film.id)
    }

    private var watchedPercent: Double? {
        guard let resume = resumeSeconds, let minutes = film.durationMinutes, minutes > 0 else { return nil }
        return resume / (Double(minutes) * 60)
    }

    var body: some View {
        ZStack {
            // LAYER 1: Background
            GeometryReader { geo in
                AsyncImage(url: film.posterURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        EmberTheme.background
                    }
                }
                .blur(radius: 60, opaque: true)
                .overlay(EmberTheme.background.opacity(0.8))
            }
            .ignoresSafeArea()

            // LAYER 2: Content
            VStack(alignment: .leading, spacing: 0) {
                Image("ember-tv-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .padding(.leading, 80)
                    .padding(.top, 60)

                Spacer()

                HStack(alignment: .center, spacing: 80) {
                    RentalPosterHero(film: film)
                        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)

                    VStack(alignment: .leading, spacing: 28) {
                        
                        // Title (FIXED: Wraps, scales dynamically, and prevents truncation)
                        Text(film.title)
                            .font(EmberTheme.titleFont(60))
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        // 1. Metadata Row
                        HStack(spacing: 20) {
                            
                            // Rating Badge
                            if let rating = film.rating, !rating.isEmpty {
                                Text(rating.uppercased())
                                    .font(EmberTheme.bodySemibold(16))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                            }
                            
                            // HD Badge
                            Text("HD")
                                .font(EmberTheme.bodySemibold(16))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                            
                            // Genre
                            if let genre = film.genre, !genre.isEmpty {
                                Text(genre.uppercased())
                                    .font(EmberTheme.bodySemibold(16))
                                    .foregroundColor(.white)
                            }
                            
                            // Duration
                            if let minutes = film.durationMinutes {
                                Text("\(minutes) MIN")
                                    .font(EmberTheme.bodyFont(20))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }

                        // 2. Descriptions Area
                        VStack(alignment: .leading, spacing: 16) {
                            
                            // Short description underneath the badges
                            if let shortDesc = film.description, !shortDesc.isEmpty {
                                Text(shortDesc)
                                    .font(EmberTheme.bodySemibold(26))
                                    .foregroundColor(.white)
                                    .lineSpacing(4)
                                    .frame(maxWidth: 800, alignment: .leading)
                            }
                        }

                        // 3. Actions Area
                        VStack(alignment: .leading, spacing: 20) {
                            Button { showPlayer = true } label: {
                                Text(resumeSeconds ?? 0 > 60 ? "Resume" : "Watch Now")
                            }
                            .buttonStyle(EmberPrimaryPillButtonStyle())

                            Text("Your 48-hour rental period began at the time of purchase.")
                                .font(EmberTheme.bodySemibold(18))
                                .foregroundColor(EmberTheme.textSecondary)
                        }
                    }
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

private struct RentalPosterHero: View {
    let film: RentalFilmSummary
    var body: some View {
        AsyncImage(url: film.posterURL) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else { Color.black.opacity(0.3) }
        }
        .frame(width: 320, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
