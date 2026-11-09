# Worship Harvest OnCue — Apple App Store submission

This is the proposed first-release metadata for App Store Connect. It reflects the current iOS project, including service duplication, local audio storage, and Google Drive import.

## App information

- **App name:** Worship Harvest OnCue
- **Subtitle:** Plan services. Run audio cues
- **Primary category:** Music
- **Secondary category:** Productivity
- **Seller/developer:** Paul Mugarura’s personal Apple Developer account (select the personal team, not an organization team)
- **SKU suggestion:** ONCUE-IOS-001
- **Bundle ID:** `com.paulmugarura.oncue` (must match the Xcode project; register it in Paul Mugarura’s personal Apple Developer account and confirm availability before creating the app record)
- **Support contact email:** worshipharvestoncue@gmail.com
- **Support URL:** Add a public support webpage before submission. It can simply display the support email above; the email address itself belongs in the support contact text on that page.
- **Privacy Policy URL:** Add the public URL after publishing `PrivacyPolicy.md` from an account/repository you control. Apple requires a publicly accessible policy URL.
- **Copyright:** Confirm the legal rights holder and enter the appropriate name and year in App Store Connect.

Worship Harvest OnCue is the product name and describes its intended worship-team audience. The app is being submitted by an independent developer. The product name does not mean Worship Harvest is the seller, developer, support provider, or privacy-policy contact.

## Promotional text

Plan the service flow, import your audio, and run songs, loops, and key pads from one iPhone or iPad. Imported files stay available offline.

## Description

Worship Harvest OnCue helps worship teams plan a service and run its audio cues from one iPhone or iPad. Arrange each service around your team’s order, add the audio you need, and keep playback controls close at hand.

PLAN THE SERVICE

• Create up to eight services with a name, date, and time. Services are listed by date and time.
• Reorder service sections, add custom sections, and edit or remove sections.
• Duplicate a service, including its layout, notes, and imported audio.
• Choose one to four songs in supported song sections. Response / Ministry Moment can also include a repeating loop.
• Keep up to 600 characters of notes with each service.

RUN AUDIO CUES

• Import audio using Files, including locations such as Google Drive when enabled on your device, or paste a Google Drive share link.
• Choose crossfade, continuous, or individual song playback, with two-, four-, or six-second fades.
• Scrub through a song, pause or resume it, and skip forward or back from the bottom player.
• Play repeating service loops and twelve chromatic key pads. Starting a loop fades out other service audio.

Imported audio is copied into the service on your device for offline playback. An internet connection is needed to import from Google Drive. Google Drive share-link imports must be accessible without signing in; files available through the Files app can be selected there when Google Drive is configured on the device. Supported audio formats depend on iOS and the selected file provider; common formats include MP3, WAV, AAC, M4A, and AIFF.

Service plans, notes, and imported audio are stored on the device and are not synced between OnCue users. OnCue does not require an account.

## Keywords

church,service planner,audio cues,multitrack,songs,loops,key pads,playback,order

## What's New — version 1.0

First release of Worship Harvest OnCue. Plan and reorder services, organize song and loop sections, import audio for offline playback, and run songs, loops, and key pads with fades and playback controls.

## App Review notes

Worship Harvest OnCue is a local service-planning and audio-cue app for worship teams. It does not require an account or a sign-in. Services, notes, and audio are saved on the device. Audio playback is the app’s core function; the app uses the audio background mode so playback can continue while the screen is locked. Leaving a service screen stops that service’s audio.

To exercise playback, create a service, open a song or loop slot, and import a short audio file through Files. A Google Drive file can also be imported if the reviewer has a file provider configured or uses a public share link. No reviewer account is needed.

## App Privacy answers to verify in App Store Connect

The code audit found no advertising, analytics, account system, tracking, or third-party SDKs. Service names, dates, notes, settings, and imported audio remain in the app’s local container. A user-selected Google Drive link is sent to Google only to retrieve the selected file; the app does not request Google credentials or send service plans or notes.

If these facts match the release build and your practices, select **No, we do not collect data from this app** in App Store Connect. Keep the public privacy policy URL set. Apple defines data collection for this label and requires the developer to report its own and integrated partners’ practices accurately.

## Submission checklist

- Create the App Store Connect app record with the same bundle ID as Xcode: `com.paulmugarura.oncue`. Confirm that the identifier is available in your personal Developer account before the first upload; the bundle ID cannot be changed for that app record after upload.
- Select Paul Mugarura’s personal seller/developer team in Xcode Signing & Capabilities and App Store Connect. The visible seller name comes from the Apple Developer account, not from the app’s display name.
- Publish the policy and a support page at public URLs you control, and enter those URLs in App Store Connect. The support email is worshipharvestoncue@gmail.com.
- Complete the App Privacy questionnaire, age-rating questionnaire, content-rights questions, and export-compliance questions in App Store Connect based on the final build and your actual practices.
- Provide at least one current iPhone screenshot and, because the app supports iPad, at least one current 13-inch iPad screenshot. Capture them from the final release build; do not use mock screens that differ from the app.
- In Xcode, select a real device, choose **Any iOS Device (arm64)** for archiving, create an Archive, resolve signing, and use Organizer’s Validate App before uploading. Exercise service creation/edit/duplicate/delete, local and Drive audio import, all playback modes, fades, app exit while playing, and iPad layout in the release build.
- Upload version **1.0**, build **1**. If any code change is made after this build is uploaded, increment the build number before uploading another build.

The project’s 1024 × 1024 app icon is included. The bundle ID, signing identity, privacy and support URLs, screenshots, account questionnaires, archive validation, and App Review submission require your personal Apple Developer and App Store Connect accounts.
