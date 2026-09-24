# Ember TV for Apple TV

SwiftUI tvOS app for Ember TV. It talks to the Ember TV web app's API v2
(`https://app.emberstreaming.com/v2/...`, documented in `docs/API-v2.md` in the
web app repo). Settings live in `EmberTV/EmberAPIConfig.swift`.

## How it works

- **Sign in with a code.** The TV shows a short code and a QR code. The viewer
  opens `app.emberstreaming.com/activate` on a phone or computer, signs in
  there (email and password, Google, anything), and enters the code. The TV
  signs in within about 5 seconds. Codes last 10 minutes and are replaced
  automatically. The session is kept in the keychain and refreshed as needed.
- **My Rentals** comes from `GET /v2/library`: active rentals and screening
  licences, plus recently expired ones.
- **Playback** asks `POST /v2/playback/:filmId` for a fresh signed HLS link on
  every play. The link only works on this TV's connection and expires after
  the film's length.
- **Resume** is shared across devices: the position is sent to
  `POST /v2/progress` every 30 seconds and when the player closes. Start a film
  on the web or on Roku and it resumes here, and the other way round.
- **Log Out** revokes this TV's session on the server.

## Testing on a device

1. Build and run on an Apple TV (or the simulator).
2. On a phone, scan the QR code (or go to the address shown) and sign in with
   an account that has an active rental; enter the code.
3. The TV opens My Rentals. Play a film, stop part way, and check that the web
   app's player resumes at the same point.
4. Try a film whose rental has expired: it shows "This rental has ended".
