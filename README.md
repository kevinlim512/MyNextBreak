# Holiday Countdown (iOS)

A SwiftUI app for Singapore that tracks your next day off, the next public holiday, and the next long weekend — plus a planning view that suggests when to take 1–2 days of leave to create 4+ day breaks. Built with SwiftUI and Combine, with on-device caching of public holiday data from data.gov.sg.

## Features
- Swipeable countdown cards: next day off, next public holiday, next long weekend
- Leave planning: recommendations to stack annual leave around holidays (4+ day weekends)
- First‑run setup: pick your working days (Mon–Sun)
- Settings: adjust working days and refresh the holiday database
- Smart titles: “Time Off!”/“Day Off!” adapts to your current day and schedule
- Offline support: holiday datasets cached on device; works after first download
- Singapore‑aware: dates calculated using Asia/Singapore timezone and local rules

## Requirements
- Xcode 15 or newer
- iOS 17.0+ (iPhone and iPad supported)

## Getting Started
- Open `Countdown App.xcodeproj` in Xcode.
- Select the “Countdown App” scheme and a simulator or device.
- Build and run. On first launch, complete the quick working‑days setup.

No third‑party package dependencies are required.

## How It Works
- Data source: Public holidays are fetched from data.gov.sg datasets and merged across years for a complete view.
- Caching: JSON responses are stored under the app’s Documents directory as `holidaysYYYY.json` and merged on load for fast startup and offline use.
- Timezone: All calculations use the Singapore timezone to keep dates consistent.

## App Structure
- Entry: `HolidayCountdownApp.swift` — App entry point
- Views:
  - `Views/ContentView.swift` — Swipeable countdown carousel with crescent layout
  - `Views/CountdownCard.swift` — Reusable, gradient countdown card
  - `Views/SetupView.swift` — First‑run working‑days setup
  - `Views/SettingsView.swift` — Working days + holiday data refresh
  - `Views/PlanView.swift` — Leave recommendations (4+ day weekends)
- Models:
  - `Models/CountdownModel.swift` — Live countdown targets and formatting
  - `Models/LeaveRecommendation.swift` — Logic to propose leave days around holidays
  - `Models/Calendar.swift` — Singapore calendar helpers (next day off, etc.)
  - `Models/HolidayStore.swift` — Central store, caching and refresh cycle
  - `Models/HolidayDownloader.swift` — Multi‑year dataset download + local merge
  - `Models/HolidayService.swift` / `Models/HolidayAPI.swift` — Live API and decoding
- Extensions:
  - `Extensions/Font+Manrope.swift` — Custom font helpers with fallbacks

## Usage Notes
- Working days: You can reconfigure any time from Settings. The countdowns and Plan view update automatically.
- Refreshing data: Use Settings → “Refresh Holiday Data” to force an update. The app automatically loads from cache on launch and refreshes in the background.
- Observed holidays: Logic in the Plan view accounts for Sunday holidays (observed on Monday) and skips Saturday holidays when Saturday is already a non‑working day, to keep suggestions practical.

## Privacy Policy
Effective: 2025-10-20

### Overview
- Holiday Countdown does not collect, share, sell, or track any personal data.
- The app operates on-device. Network access is only used to download public holiday datasets from data.gov.sg.

### Data We Collect
- Personal information: none
- Contact information: none
- Identifiers (e.g., IDFA, device IDs): none
- Usage/analytics: none
- Diagnostics/crash logs: none

### On-Device Data
- Working-days preference (Mon–Sun): stored locally on your device to power countdowns and planning.
- Cached holiday datasets: stored locally to enable offline use and faster startup.
- Retention: data persists on your device until you delete the app or refresh the holiday cache via Settings → “Refresh Holiday Data”.
- Backup/sync: iOS may include app data in encrypted device backups if enabled. No data is transmitted to our servers.

### Tracking and Third Parties
- No advertising, analytics, or other third‑party SDKs are integrated.
- No cross‑app tracking; the app does not access or use the IDFA.
- External services: the app connects to data.gov.sg solely to download public holiday datasets. Standard network metadata (e.g., IP address) may be visible to that service per their policies; we do not receive or store it.

### Children’s Privacy
- The app does not collect data from any users, including children under 13.

### Your Choices
- Delete the app to remove all locally stored data and caches.
- Use Settings → “Refresh Holiday Data” to refresh or replace cached datasets.
- Adjust working days in Settings at any time.

### Changes to This Policy
- If features that require data are added in the future, this policy and the App Store privacy labels will be updated prior to release.

### Contact
- For questions about this policy, contact: your-email@example.com

### App Store Privacy Summary
- Data Not Collected; Tracking: No.

## Acknowledgements
- Public holiday data courtesy of data.gov.sg
- Manrope typeface by Michael Sharanda (SIL Open Font License 1.1)

## Roadmap Ideas
- Widgets for upcoming day off/holiday
- In‑app changelog for holiday database updates
- Region selection (beyond Singapore)
