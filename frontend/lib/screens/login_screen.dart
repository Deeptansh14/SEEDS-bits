import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tts_service.dart';
import 'teacher_dashboard.dart';
import 'student_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isTeacher = false;
  bool isLoading = false;

  Future<void> _login() async {
    final phone = phoneCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      TtsService.speak("Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': phone,
          'password': password,
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final accessToken = data['access_token'];
        final userId = data['user_id'];
        final role = data['role'];

        if (accessToken == null || userId == null || role == null) {
          TtsService.speak("Invalid response from server");
          debugPrint("Login response missing keys: $data");
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', accessToken);
        await prefs.setInt('user_id', userId);
        await prefs.setString('role', role);

        TtsService.speak("Login successful");

        // Navigate based on actual backend role
        if (role.toLowerCase() == 'teacher') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeacherDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentDashboard()),
          );
        }
      } else if (res.statusCode == 401) {
        TtsService.speak("Invalid credentials");
      } else {
        TtsService.speak("Login failed: ${res.statusCode}");
        debugPrint("Login response: ${res.body}");
      }
    } catch (e) {
      TtsService.speak("Login failed. Check network or credentials.");
      debugPrint("Login error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Welcome Back",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: "Phone number",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  onTap: () => TtsService.speak("Enter phone number"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                  onTap: () => TtsService.speak("Enter password"),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Login as Teacher?"),
                    Switch(
                      value: isTeacher,
                      onChanged: (v) => setState(() => isTeacher = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Login",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
