import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import 'teacher_dashboard.dart';
import 'student_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isTeacher = false;
  bool isLoading = false;

  Future<void> register() async {
    setState(() => isLoading = true);

    final data = {
      'name': nameCtrl.text.trim(),
      'phone_number': phoneCtrl.text.trim(),
      'password': passCtrl.text,
      'role': isTeacher ? 'teacher' : 'student',
    };

    try {
      final res = await ApiService.post('/auth/register', data);

      if (res == null) {
        throw Exception("No response from server");
      }

      if (res.containsKey('detail')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${res['detail']}")),
        );
        setState(() => isLoading = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = int.tryParse(res['id'].toString());

      if (userId != null) {
        await prefs.setInt('user_id', userId);
        await prefs.setString('role', isTeacher ? 'teacher' : 'student');
        debugPrint("User registered with ID: $userId");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful!")),
      );

      // Navigate to dashboard
      if (isTeacher) {
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
    } catch (e) {
      debugPrint("Registration error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: $e")),
      );
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
              children: [
                const Text(
                  "Register",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Name"),
                  onTap: () => TtsService.speak("Enter name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: "Phone number"),
                  keyboardType: TextInputType.phone,
                  onTap: () => TtsService.speak("Enter phone number"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password"),
                  onTap: () => TtsService.speak("Enter password"),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Teacher?"),
                    Switch(
                      value: isTeacher,
                      onChanged: (v) => setState(() => isTeacher = v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading ? null : register,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
