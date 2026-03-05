# Attendance Tracker V3

A modern Flutter-based attendance tracking application designed to simplify attendance management for educational institutions and businesses.

## 📋 Features

- **User Authentication**: Secure login and registration system
- **Real-time Tracking**: Record attendance in real-time
- **Dashboard**: Comprehensive dashboard to visualize attendance data
- **Reports Generation**: Export detailed attendance reports
- **User Management**: Different roles for students/employees, teachers/managers
- **Notification System**: Automated alerts and reminders
- **Offline Support**: Works in low connectivity environments
- **Analytics**: Detailed insights and statistical analysis
- **Multiple Language Support**: Internationalization ready
- **Dark Mode**: Eye-friendly interface option


## 🛠️ Tech Stack

- **Frontend**: Flutter
- **Backend**: Firebase Cloud Functions
- **Database**: Firestore
- **Authentication**: Firebase Auth
- **Storage**: Firebase Storage
- **State Management**: Provider/Bloc
- **Analytics**: Firebase Analytics
- **Testing**: Flutter Test Framework

## 🚀 Getting Started

### Prerequisites

- Flutter (latest version)
- Dart SDK
- Android Studio / VS Code
- Git

### Installation

1. Clone the repository
   ```bash
   git clone [your-repository-url]
   ```

2. Navigate to project directory
   ```bash
   cd attandence_v3
   ```

3. Install dependencies
   ```bash
   flutter pub get
   ```

4. Run the app
   ```bash
   flutter run
   ```

## 🔍 Usage

### Login & Registration
- Use your email and password to register
- Administrators can create bulk accounts for students/employees
- Forgot password functionality available

### Taking Attendance
1. Teachers/Managers can create attendance sessions
2. Students/Employees can mark attendance using:
   - QR code scanning
   - Biometric verification
   - Geolocation validation
   - Manual entry (admin only)

### Reports
- Generate daily, weekly, monthly reports
- Export to PDF/Excel formats
- Visualize trends with interactive charts
- Set up automated report delivery via email

### Settings
- Configure notification preferences
- Set working hours and attendance policies
- Customize UI themes and language

## 📁 Project Structure
