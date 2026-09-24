import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Sign in by activation code. The TV shows a short code; the viewer enters
/// it at app.emberstreaming.com/activate (or scans the QR code) while signed
/// in there with email and password, Google, or anything else. No typing on
/// the remote, and it works for every kind of account.
struct ActivationView: View {
    @EnvironmentObject private var api: EmberAPIClient

    @State private var code: DeviceCodeResponse?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // MARK: - LAYER 1: Premium Ambient Background
            EmberTheme.background.ignoresSafeArea()

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

                // RIGHT COLUMN: The code
                VStack(alignment: .leading, spacing: 36) {
                    Text("Sign In")
                        .font(EmberTheme.titleFont(64))
                        .foregroundColor(.white)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(EmberTheme.bodySemibold(20))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 640, alignment: .leading)
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.6), lineWidth: 1)
                            )
                    }

                    if let code {
                        codePanel(code)
                    } else {
                        ProgressView("Getting your code…")
                            .controlSize(.large)
                            .frame(width: 640, height: 300)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .task { await runActivation() }
    }

    // MARK: - Code panel

    private func codePanel(_ code: DeviceCodeResponse) -> some View {
        HStack(alignment: .top, spacing: 48) {
            VStack(alignment: .leading, spacing: 24) {
                step(1, "On your phone or computer, go to")
                Text("\(EmberAPIConfig.websiteDisplayName)/activate")
                    .font(EmberTheme.bodySemibold(28))
                    .foregroundColor(EmberTheme.primary)

                step(2, "Sign in, then enter this code:")
                Text(code.userCode)
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(EmberTheme.primary.opacity(0.6), lineWidth: 2)
                    )

                HStack(spacing: 16) {
                    ProgressView()
                    Text("Waiting for you to approve…")
                        .font(EmberTheme.bodyFont(20))
                        .foregroundColor(EmberTheme.textSecondary)
                }
                .padding(.top, 8)
            }

            if let qr = QRCode.image(for: code.verificationUriComplete.absoluteString) {
                VStack(spacing: 16) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 240, height: 240)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("Or scan with\nyour phone")
                        .font(EmberTheme.bodyFont(18))
                        .foregroundColor(EmberTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        Text("\(number).  \(text)")
            .font(EmberTheme.bodyFont(24))
            .foregroundColor(.white)
    }

    // MARK: - Activation loop

    /// Gets a code and polls until the viewer approves it. An expired code is
    /// replaced automatically, so a TV left on this screen always shows a
    /// working code. Ends when signed in (the root view swaps this screen out,
    /// cancelling the task).
    private func runActivation() async {
        while !Task.isCancelled {
            let current: DeviceCodeResponse
            do {
                current = try await api.startActivation()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                try? await Task.sleep(for: .seconds(10))
                continue
            }
            code = current
            errorMessage = nil

            let deadline = Date().addingTimeInterval(TimeInterval(current.expiresIn))
            var interval = current.interval
            polling: while Date() < deadline {
                do {
                    try await Task.sleep(for: .seconds(interval))
                    switch try await api.pollActivation(deviceCode: current.deviceCode) {
                    case .approved:
                        return
                    case .pending(let next):
                        interval = max(next, current.interval)
                        errorMessage = nil
                    case .restart:
                        break polling
                    }
                } catch is CancellationError {
                    return
                } catch {
                    // Keep the code on screen and keep polling: the viewer
                    // may be halfway through typing it.
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - QR code

private enum QRCode {
    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
