import SwiftUI

struct MyRentalsView: View {
    @State private var rentals: [Rental] = []
    @State private var isLoading = true
    
    @AppStorage("EmberAuthToken") private var authToken: String = ""

    // NEW: Tracks which movie the user is currently focused on
    @FocusState private var focusedRentalID: String?

    private let columns = [
        GridItem(.adaptive(minimum: 250), spacing: 60)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - LAYER 1: Dynamic Cinematic Background
                ZStack {
                    // Find the currently focused rental
                    if let focusedRental = rentals.first(where: { $0.film.id == focusedRentalID }),
                       let url = focusedRental.film.posterURL {
                        
                        GeometryReader { geo in
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .transition(.opacity) // Smooth crossfade
                                } else {
                                    EmberTheme.background
                                }
                            }
                            // The .id modifier forces SwiftUI to recreate the view when the URL changes, triggering the transition
                            .id(url)
                        }
                    } else {
                        EmberTheme.background
                    }
                }
                .blur(radius: 80) // Heavy blur so it's just ambient color
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    EmberTheme.background.opacity(0.5),
                                    EmberTheme.background.opacity(0.95) // Darker at the bottom for readability
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: focusedRentalID) // The crossfade speed

                // MARK: - LAYER 2: UI Content
                VStack(spacing: 0) {
                    
                    // Premium Header (Aligned Top-Center)
                    ZStack {
                        // Center Title
                        Text("My Rentals")
                            .font(EmberTheme.titleFont(52))
                            .foregroundColor(.white)
                        
                        // Left Logo & Right Buttons
                        HStack(alignment: .center) {
                            Image("ember-tv-logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 48)
                            
                            Spacer()
                            
                            HStack(spacing: 24) {
                                Button {
                                    loadRentals()
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                        .font(EmberTheme.bodySemibold(20))
                                }
                                
                                Button {
                                    logout()
                                } label: {
                                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                        .font(EmberTheme.bodySemibold(20))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    .focusSection()

                    // Content Area
                    if isLoading {
                        Spacer()
                        ProgressView("Loading your library...")
                            .controlSize(.large)
                        Spacer()
                    } else if rentals.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "film.stack")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.2))
                            Text("Your library is empty")
                                .font(EmberTheme.headingFont(32))
                                .foregroundColor(EmberTheme.textPrimary)
                            Text("Rentals you purchase on the web will appear here.")
                                .font(EmberTheme.bodyFont(24))
                                .foregroundColor(EmberTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 80) {
                                ForEach(rentals, id: \.film.id) { rental in
                                    NavigationLink(value: rental) {
                                        RentalPosterCard(rental: rental)
                                    }
                                    .buttonStyle(.plain)
                                    .focusEffectDisabled(true)
                                    // NEW: Tells the Focus Engine to update our tracking variable when this card is highlighted
                                    .focused($focusedRentalID, equals: rental.film.id)
                                }
                            }
                            .padding(.horizontal, 60)
                            .padding(.top, 40)
                            .padding(.bottom, 100)
                        }
                        .focusSection()
                    }
                }
            }
            .navigationDestination(for: Rental.self) { rental in
                RentalDetailView(rental: rental)
            }
            .onAppear {
                loadRentals()
            }
        }
    }

    // MARK: - Actions
    private func loadRentals() {
        isLoading = true
        Task {
            do {
                let fetchedRentals = try await EmberAPIClient.shared.fetchMyRentals()
                
                await MainActor.run {
                    self.rentals = fetchedRentals
                    self.isLoading = false
                    
                    // Optional: Set the background to the first movie right when they load in
                    if let first = fetchedRentals.first {
                        self.focusedRentalID = first.film.id
                    }
                }
            } catch {
                print("Failed to fetch rentals: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func logout() {
        authToken = ""
        EmberAPIClient.shared.logout()
        print("User logged out successfully.")
    }
}
