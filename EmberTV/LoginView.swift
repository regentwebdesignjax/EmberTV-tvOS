import SwiftUI

struct LoginView: View {
    @EnvironmentObject var api: EmberAPIClient

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum LoginField: Hashable {
        case email
        case password
    }

    @FocusState private var focusedField: LoginField?

    // MARK: - Computed colors (keeps text readable + visible)
    private var emailTextColor: Color {
        if focusedField == .email { return .white }
        return email.isEmpty ? .white : EmberTheme.primary
    }

    private var passwordTextColor: Color {
        if focusedField == .password { return .white }
        return password.isEmpty ? .white : EmberTheme.primary
    }

    var body: some View {
        ZStack {
            EmberTheme.background
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 40) {
                    Image("ember-tv-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)

                    VStack(spacing: 12) {
                        Text("Sign in to EmberTV")
                            .font(EmberTheme.titleFont(44))
                            .foregroundColor(.white)

                        Text("Use your EmberTV email and password to sign in.")
                            .font(EmberTheme.bodyFont(22))
                            .foregroundColor(EmberTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 900)
                    }

                    VStack(spacing: 24) {

                        // Email
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(EmberTheme.bodyFont(20))
                                .foregroundColor(EmberTheme.textSecondary)

                            TextField("name@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                // UPDATED: Increased font size to 32
                                .font(EmberTheme.bodyFont(32))
                                .textFieldStyle(.plain)                 // IMPORTANT on tvOS
                                .foregroundStyle(emailTextColor)        // IMPORTANT on tvOS
                                .tint(EmberTheme.primary)               // cursor / selection color
                                .submitLabel(.done)
                                .focused($focusedField, equals: .email)
                                .onSubmit { focusedField = .password }  // go to next field
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            focusedField == .email
                                                ? EmberTheme.primary.opacity(0.95)
                                                : Color.white.opacity(0.18),
                                            lineWidth: focusedField == .email ? 3 : 1
                                        )
                                        .shadow(
                                            color: focusedField == .email
                                                ? EmberTheme.primary.opacity(0.70)
                                                : .clear,
                                            radius: focusedField == .email ? 18 : 0,
                                            x: 0, y: 0
                                        )
                                )
                                .focusEffectDisabled(true)
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(EmberTheme.bodyFont(20))
                                .foregroundColor(EmberTheme.textSecondary)

                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                // UPDATED: Increased font size to 32
                                .font(EmberTheme.bodyFont(32))
                                .textFieldStyle(.plain)                   // IMPORTANT on tvOS
                                .foregroundStyle(passwordTextColor)       // IMPORTANT on tvOS
                                .tint(EmberTheme.primary)
                                .submitLabel(.done)
                                .focused($focusedField, equals: .password)
                                .onSubmit { focusedField = nil }          // close keyboard
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            focusedField == .password
                                                ? EmberTheme.primary.opacity(0.95)
                                                : Color.white.opacity(0.18),
                                            lineWidth: focusedField == .password ? 3 : 1
                                        )
                                        .shadow(
                                            color: focusedField == .password
                                                ? EmberTheme.primary.opacity(0.70)
                                                : .clear,
                                            radius: focusedField == .password ? 18 : 0,
                                            x: 0, y: 0
                                        )
                                )
                                .focusEffectDisabled(true)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(EmberTheme.bodyFont(20))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 700)
                        }

                        Button {
                            Task { await login() }
                        } label: {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 26, weight: .bold))
                                }
                                Text(isLoading ? "Signing In…" : "Sign In")
                                    .font(EmberTheme.bodySemibold(24))
                            }
                        }
                        .buttonStyle(EmberLoginPrimaryButtonStyle())
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
                    .frame(maxWidth: 900)
                }

                Spacer()
            }
            .padding(.horizontal, 80)
        }
        .onAppear {
            focusedField = .email
        }
    }

    private func login() async {
        print("LoginView → Sign In tapped for email: \(email)")

        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await api.login(email: email, password: password)
        } catch {
            print("LoginView → login error: \(error)")
            errorMessage = "Sign-in failed. Please check your email and password."
        }

        isLoading = false
    }
}

// MARK: - Login button style

struct EmberLoginPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration)
    }

    private struct ButtonBody: View {
        @Environment(\.isFocused) private var isFocused: Bool
        let configuration: Configuration

        var body: some View {
            configuration.label
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(EmberTheme.primary)
                )
                .foregroundColor(.white)
                .scaleEffect(isFocused || configuration.isPressed ? 1.06 : 1.0)
                .shadow(
                    color: isFocused ? EmberTheme.primary.opacity(0.7) : .clear,
                    radius: 18, x: 0, y: 0
                )
                .animation(.easeOut(duration: 0.18), value: isFocused)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .focusEffectDisabled(true)
        }
    }
}
