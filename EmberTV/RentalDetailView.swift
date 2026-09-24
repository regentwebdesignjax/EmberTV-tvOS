import SwiftUI

struct RentalDetailView: View {
    let rental: Rental
    @EnvironmentObject private var api: EmberAPIClient

    @State private var showPlayer = false
    @State private var startOver = false
    @State private var detail: FilmDetail?
    /// Server-side resume point (shared across devices), updated locally
    /// when the player closes so the button is right without a reload.
    @State private var resumeSeconds: TimeInterval?

    init(rental: Rental) {
        self.rental = rental
        _resumeSeconds = State(initialValue: rental.resume.map { TimeInterval($0.positionSeconds) })
    }

    private var film: LibraryFilm { rental.film }

    private var canResume: Bool { (resumeSeconds ?? 0) > 60 }

    var body: some View {
        ZStack {
            // LAYER 1: Background
            GeometryReader { geo in
                AsyncImage(url: film.backdropURL) { phase in
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
                            if let genre = detail?.genres.first, !genre.isEmpty {
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
                            if let shortDesc = detail?.shortDescription, !shortDesc.isEmpty {
                                Text(shortDesc)
                                    .font(EmberTheme.bodySemibold(26))
                                    .foregroundColor(.white)
                                    .lineSpacing(4)
                                    .frame(maxWidth: 800, alignment: .leading)
                            }
                        }

                        // 3. Actions Area
                        VStack(alignment: .leading, spacing: 20) {
                            if rental.isWatchable() {
                                HStack(spacing: 24) {
                                    Button {
                                        startOver = false
                                        showPlayer = true
                                    } label: {
                                        Text(canResume ? "Resume" : "Watch Now")
                                    }
                                    .buttonStyle(EmberPrimaryPillButtonStyle())

                                    if canResume {
                                        Button {
                                            startOver = true
                                            showPlayer = true
                                        } label: {
                                            Text("Start Over")
                                        }
                                        .buttonStyle(EmberPrimaryPillButtonStyle())
                                    }
                                }
                            }

                            Text(windowText)
                                .font(EmberTheme.bodySemibold(18))
                                .foregroundColor(EmberTheme.textSecondary)
                                .frame(maxWidth: 800, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(rental: rental, resumeFrom: startOver ? nil : resumeSeconds) { lastPosition in
                resumeSeconds = lastPosition
            }
        }
        .task {
            detail = try? await api.fetchFilm(slug: film.slug)
        }
    }

    /// The line under the buttons: when this rental or licence can be watched.
    private var windowText: String {
        let now = Date()
        let venue = rental.screening?.venueName.map { " at \($0)" } ?? ""
        if rental.isUpcoming(at: now) {
            if let date = rental.screening?.screeningDate {
                return "Screening licence\(venue) for \(formattedScreeningDate(date)). You can play it from the day before."
            }
            return "Available from \(rental.entitlement.startsAt?.formattedForEmber() ?? "soon")."
        }
        if rental.isWatchable(at: now) {
            guard let end = rental.expiresAt else { return "" }
            let prefix = rental.isScreening ? "Screening licence\(venue). " : ""
            return "\(prefix)Available until \(end.formattedForEmber())."
        }
        return "This rental has ended. Rent it again at \(EmberAPIConfig.websiteDisplayName)."
    }
}

private struct RentalPosterHero: View {
    let film: LibraryFilm
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
