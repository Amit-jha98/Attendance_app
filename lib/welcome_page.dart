import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? employeeId = prefs.getString('employee_id');
    String? email = prefs.getString('email');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (employeeId != null && email != null) {
        // User session exists, navigate to the branch/semester selection screen
        Navigator.pushReplacementNamed(context, arguments: {
          'employee_id': employeeId,
          'email': email,
        },'/branch_semester_selection_screen');
      } else {
        // No user session, navigate to the login screen
        Navigator.pushReplacementNamed(context, '/login_screen');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.orangeAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/clg_logo.ico',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 32), // Space between logo and text
              const Text(
                'WELCOME TO',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 32), // Space between logo and text
              const Text(
                'उपस्थित्यम्-GEC Madhubani',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 100), // Space between title and subtitle
              const Text(
                "By-Amit Kumar Jha",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
