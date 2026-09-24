import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // This watches the token. When the API client updates it, the app will automatically route away from this screen.
    @AppStorage("EmberAuthToken") private var authToken: String = ""
    
    var body: some View {
        ZStack {
            // MARK: - LAYER 1: Premium Ambient Background
            EmberTheme.background.ignoresSafeArea()
            
            // Subtle orange glow originating from the logo side
            RadialGradient(
                gradient: Gradient(colors: [EmberTheme.primary.opacity(0.15), .clear]),
                center: .leading,
                startRadius: 100,
                endRadius: 900
            )
            .ignoresSafeArea()
            
            // MARK: - LAYER 2: Split Screen Content
            HStack(spacing: 0) {
                
                // LEFT COLUMN: Branding & Marketing
                VStack(alignment: .leading, spacing: 32) {
                    Image("ember-tv-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 70)
                    
                    Text("The way family movie nights should be.")
                        .font(EmberTheme.headingFont(48))
                        .foregroundColor(.white)
                        .lineSpacing(8)
                    
                    Text("Rent movies on the EmberTV web app and watch them instantly right here on your Apple TV.")
                        .font(EmberTheme.bodyFont(24))
                        .foregroundColor(EmberTheme.textSecondary)
                        .padding(.trailing, 40)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 120)
                
                // RIGHT COLUMN: The Login Form
                VStack(alignment: .leading, spacing: 40) {
                    Text("Sign In")
                        .font(EmberTheme.titleFont(64))
                        .foregroundColor(.white)
                    
                    // Error Message Banner
                    if let error = errorMessage {
                        Text(error)
                            .font(EmberTheme.bodySemibold(20))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 600, alignment: .leading)
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.6), lineWidth: 1)
                            )
                    }
                    
                    // Input Fields
                    VStack(spacing: 24) {
                        TextField("Email Address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                    .frame(width: 600)
                    
                    // Action Button
                    Button {
                        performLogin()
                    } label: {
                        HStack(spacing: 16) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isLoading ? "Signing In..." : "Log In")
                        }
                        .frame(maxWidth: .infinity) // Makes the button full width of the text fields
                    }
                    .buttonStyle(EmberLoginButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // MARK: - Actions
    private func performLogin() {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Calls your existing EmberAPIClient logic
                try await EmberAPIClient.shared.login(email: email, password: password)
                
                await MainActor.run {
                    isLoading = false
                    // Successful login will automatically save the token to UserDefaults inside the API client,
                    // which updates the @AppStorage variable and dismisses this view.
                }
            } catch EmberAPIClient.LoginError.invalidCredentials {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Invalid email or password. Please try again."
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "A connection error occurred. Please try again."
                }
            }
        }
    }
}

// MARK: - Custom Button Style
// Tailored slightly wider for the login form specifically
private struct EmberLoginButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EmberTheme.bodySemibold(24))
            .padding(.vertical, 18)
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
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(
                color: isFocused ? EmberTheme.primary.opacity(0.4) : .clear,
                radius: 20, x: 0, y: 10
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .focusEffectDisabled(true)
    }
}
