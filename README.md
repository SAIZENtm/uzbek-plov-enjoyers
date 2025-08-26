# Newport Resident App

A modern Flutter-based mobile application for Newport residential complex residents, providing seamless access to apartment services and management features.

## 🏗️ Architecture Overview

The app follows clean architecture principles with a focus on maintainability, testability, and scalability. Key features include:

- **Multi-apartment support**: Residents can manage multiple apartments under one account
- **Passport-based authentication**: Secure login using phone number, apartment number, and passport verification
- **Offline-first approach**: Core features work without internet connection
- **Real-time updates**: Firebase integration for instant data synchronization

## 📋 Prerequisites

- Flutter SDK (^3.29.2)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Android SDK / Xcode (for iOS development)
- Firebase project setup

## 🛠️ Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/newport-resident.git
cd newport-resident
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Add `google-services.json` to `android/app/`
   - Add `GoogleService-Info.plist` to `ios/Runner/`

4. Run the application:
```bash
flutter run
```

## 🔐 Authentication Flow

The app uses a two-step authentication process:

1. **Initial Verification**:
   - User enters apartment number and phone number
   - System searches across all blocks for matching apartment
   - SMS verification code is sent

2. **Apartment Discovery**:
   - After SMS verification, system retrieves passport number
   - Searches for all apartments owned by this passport
   - Displays list if multiple apartments found
   - Direct access if single apartment

## 📊 Data Structure

The app uses Firebase Firestore with the following structure:

### Collections:
- **blocks/{blockId}**: Building blocks (A, B, C, D, E, F)
  - **apartments/{apartmentNumber}**: Individual apartments with owner data
- **clients/{clientId}**: Normalized client data with apartment references

For detailed structure, see [FIRESTORE_STRUCTURE.md](docs/FIRESTORE_STRUCTURE.md)

## 🚀 Key Features

- **Dashboard**: Overview of apartment status and quick actions
- **Service Requests**: Submit and track maintenance requests
- **Utility Readings**: Submit meter readings with photo attachments
- **Payments**: View and pay bills
- **Community News**: Stay updated with complex announcements
- **Interactive Map**: Navigate the complex with offline support

## 📁 Project Structure

```
newport_resident/
├── android/            # Android-specific configuration
├── ios/                # iOS-specific configuration
├── lib/
│   ├── core/           # Core utilities and services
│   │   ├── di/         # Dependency injection
│   │   ├── models/     # Data models
│   │   └── services/   # Business logic services
│   ├── presentation/   # UI screens and widgets
│   ├── routes/         # Application routing
│   ├── theme/          # Theme configuration
│   ├── widgets/        # Reusable UI components
│   └── main.dart       # Application entry point
├── assets/             # Static assets (images, fonts, etc.)
├── docs/               # Documentation
├── scripts/            # Utility scripts
├── test/               # Unit and widget tests
└── pubspec.yaml        # Project dependencies
```

## 🔧 Development

### Running Tests
```bash
flutter test
```

### Building for Production
```bash
# Android
flutter build apk --release

# iOS
flutter build ipa --release
```

### Data Import
To import data from Excel to Firestore:
```bash
dart run scripts/import_data_to_firestore.dart
```

## 🛡️ Security

- All data is encrypted at rest and in transit
- Authentication required for all operations
- Users can only access their own apartment data
- Firestore security rules enforce data isolation

## 📱 Platform Support

- Android (API 21+)
- iOS (11.0+)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is proprietary and confidential. All rights reserved.

## 👥 Team

- Development: Newport IT Team
- Design: Newport UX Team
- Project Management: Newport Management

## 📞 Support

For support, email support@newport.uz or contact the management office.
