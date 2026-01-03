# Orbit 🌍

**Keep your world in sync.**

Orbit is a collaborative location and calendar coordination app for groups, built with Flutter and Firebase. It helps families, friends, and teams stay connected by sharing whereabouts and coordinating events seamlessly.

## ✨ Features

- **Group Management**: Create and join groups to coordinate with family, friends, or colleagues.
- **Location Sharing**: Share your current location with group members for specific dates.
- **Event Scheduling**: Create and manage group events with RSVP functionality.
- **Holiday Calendars**: Automatically displays public holidays based on your location.
- **Religious Calendars**: Support for Chinese Lunar and Islamic Hijri calendars.
- **Real-time Sync**: Instant updates across all devices using Firebase.
- **Dark Mode**: Full dark/light theme support.
- **PWA Support**: Install as a Progressive Web App on any device.
- **Admin Controls**: Role-based access and member management.

## 📝 Update Log

### [1.0.1] - 2026-01-03

- **� Text Size Settings**: Added adjustable font size (80%-150%) in Settings for elderly users and accessibility.
- **�🔄 Manual Refresh**: Added a refresh button in the navigation bar for quick page reloads, especially useful for PWA users.
- **📱 iOS PWA Install**: The "Install App" button now always shows on iOS since Safari cannot reliably detect installation status.
- **🔒 Enhanced Security**: Tightened Firestore rules to ensure User Profiles and Group Lists are private and accessible only to relevant members.
- **🛡️ Secure Join Flow**: Improved "Join Group" process to securely handle user identity without exposing public profile data.
- **🚫 Owner Protection**: Enforced strict rules preventing Group Owners from leaving without first transferring ownership, ensuring groups never become orphaned.
- **🐛 Access Fixes**: Resolved issues where valid group members could not see their own groups due to permission configurations.

### [1.0.0] - 2026-01-01

- **🚀 PWA Manual Install**: Added "Install App" button in drawer for Desktop (Chrome/Edge) and Mobile (Android/iOS).
- **🎂 Birthday Reliability**: Implemented lifecycle-aware, group-wide birthday checks to ensure notifications never miss a beat.
- **🔗 Join Link invitations**: Users can now join groups via shareable, PWA-aware links with automatic login, join request handling, and **smart URL cleanup** to prevent refresh loops.
- **📤 Enhanced Sharing**: Mobile users enjoy **native share sheets** for instant app sharing, while desktop users get a reliable clipboard fallback.
- **📋 Device Info**: Added "Copy Info" button in Feedback dialog to instantly grab App Version, User Agent, Timezone, and PWA status for easier debugging.
- **🎨 UI Modernization**: Refined spaces, icons, and **Dismissible Dialogs** (click outside to close) for a smoother experience.
- **🔗 Share Logic**: Fixed a bug where native sharing on mobile would duplicate the invite link.
- **📱 Mobile Paste Fix**: Empowered mobile users with native long-press context menus for seamless ID pasting.
- **🛡️ Admin Hierarchy**: Refined permissions to allow Admins to edit details while protecting Owners and other Admins from removal.
- **🛠️ Stability & Dedup**: Improved notification deduplication, external ID sync, and fixed join link compilation issues.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (^3.9.2)
- Firebase project with Firestore, Auth, and Storage enabled
- Node.js (for Firebase Functions)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/Nzettodess/Orbit.git
   cd Orbit
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Set up Firebase:
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Firestore, Authentication (Email/Password + Google), and Storage
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Run `flutterfire configure` to generate `firebase_options.dart`

4. Create a `.env` file with your API keys:

   ```env
   GOOGLE_API_KEY=your_google_calendar_api_key
   ```

5. Run the app:

   ```bash
   flutter run -d chrome
   ```

## ⚠️ Known Issues

- **Android PWA Keyboard**: Some Android devices may experience UI shifts or difficulty interacting with text areas when the virtual keyboard is active. We are actively working on a more robust viewport-aware solution.

## ⭐ Support

If you find Orbit useful, please consider giving it a star! It helps others discover the project.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
