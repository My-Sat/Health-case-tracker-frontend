# Health Case Tracker

## Flutter Android Application for Health Case Management

Health Case Tracker is a **Flutter mobile application** for recording, managing and monitoring health cases.

The application provides separate experiences for health officers and administrators, allowing users to create and manage cases, monitor patients, manage health facilities and case types, view statistics, and securely communicate with the deployed Health Case Tracker REST API.

The application is designed primarily for **Android devices**.

## Backend API

The mobile application communicates with the deployed Health Case Tracker backend:

https://health-case-tracker-backend-o82a.onrender.com

The backend provides authentication, case management, facility management, case types, location data and other REST API services used by the application.

## Key Features

### Authentication

* User login
* User registration
* Persistent login sessions
* Automatic login restoration
* Logout
* Forgot-password workflow
* Reset-code verification
* Password reset

### Role-Based User Experience

The application provides different dashboards and functionality depending on the authenticated user's role.

* Administrator dashboard
* Health officer dashboard
* Protected administrative functionality
* Role-based navigation

### Health Case Management

* Create health cases
* View assigned cases
* View all cases where permitted
* Edit case information
* Update case status
* View patients assigned to an officer
* Archive cases
* View archived cases
* Restore archived cases

### Health Facility Management

* View health facilities
* Create health facilities
* Edit facility information
* Archive facilities
* View archived facilities
* Retrieve facility details from the backend

### Location Management

Health facilities and cases can work with hierarchical location data including:

* Regions
* Districts
* Sub-districts
* Communities
* Health facilities

Location information is retrieved dynamically from the backend API.

### Case Type Management

* View case types
* Create case types
* Manage case types
* Archive case types
* View archived case types
* Restore archived case types

### Statistics & Monitoring

* Case-type statistics
* Case summaries
* Dashboard information
* Case monitoring and status information

## Technology Stack

### Mobile Application

* Flutter
* Dart
* Material Design

### State Management

* Provider

### API Communication

* Dart HTTP package
* REST API integration
* JSON data processing

### Local Storage

* SharedPreferences

### Other Packages

* intl
* Cupertino Icons
* Flutter Launcher Icons

## Application Architecture

The Flutter source code is organized into separate layers:

```text
lib/
├── models/       # Application data models
├── providers/    # State and authentication management
├── screens/      # Application screens and user interfaces
├── services/     # Backend API communication
├── widgets/      # Reusable user-interface components
└── main.dart     # Application entry point
```

## Authentication Flow

The application uses Provider for authentication state management.

After login, authenticated user information is stored locally using `SharedPreferences`. When the application starts again, it attempts to restore the existing login session.

Users are then directed to the appropriate dashboard according to their role.

```text
Application starts
       ↓
Check saved authentication
       ↓
   Logged in?
    /       \
   No       Yes
   ↓         ↓
Login     Check role
             ↓
       ┌─────┴─────┐
       ↓           ↓
     Admin       Officer
       ↓           ↓
Admin Dashboard  Dashboard
```

## Backend Integration

The application communicates with the Health Case Tracker REST API using HTTP requests.

API base URL:

```text
https://health-case-tracker-backend-o82a.onrender.com/api
```

Authenticated requests use bearer-token authorization where required.

## Getting Started

### Requirements

Before running the project, install:

* Flutter SDK
* Dart SDK
* Android Studio or another Android development environment
* An Android emulator or physical Android device

### 1. Clone the repository

```bash
git clone https://github.com/My-Sat/Health-case-tracker-frontend.git
```

### 2. Enter the project directory

```bash
cd Health-case-tracker-frontend
```

### 3. Install Flutter dependencies

```bash
flutter pub get
```

### 4. Check the Flutter environment

```bash
flutter doctor
```

Resolve any required Android SDK or device configuration reported by Flutter.

### 5. Run the application

Connect an Android device or start an Android emulator, then run:

```bash
flutter run
```

## Building the Android Application

To create a release APK:

```bash
flutter build apk --release
```

The generated APK can normally be found under:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Related Repository

The REST API used by this application is maintained separately:

**Health-case-tracker-backend**

https://github.com/My-Sat/Health-case-tracker-backend

Together, the frontend and backend form the complete **Health Case Tracker system**.

## What This Project Demonstrates

This project demonstrates practical experience with:

* Flutter mobile application development
* Dart
* Android application development
* REST API integration
* JSON data handling
* Provider state management
* Persistent local storage
* Authentication workflows
* Role-based user interfaces
* CRUD application workflows
* Mobile form handling
* Multi-screen application architecture
* Backend/frontend integration
* Health case and facility management workflows
* Git and GitHub version control

## Author

**Ibrahim Iddrisu Chenti**

Full-Stack & Mobile Application Developer

**Technologies:** Flutter, Dart, Node.js, Express.js, MongoDB, Mongoose and REST APIs
