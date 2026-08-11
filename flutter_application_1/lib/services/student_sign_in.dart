import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus(); // Klavyeyi kapat

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen email ve şifrenizi girin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Servisimizi çağırıyoruz!
    AuthService authService = AuthService();
    var response = await authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    // Go'dan gelen cevaba göre ekrana mesaj basıyoruz
    if (response.status == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GİRİŞ BAŞARILI!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.banner ?? 'Hata oluştu!'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const neonGreen = Color(0xFFC4F34A);
    const bgColor = Color(0xFF121418);
    const inputColor = Color(0xFF1C1F26);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.fitness_center, size: 64, color: neonGreen),
                const SizedBox(height: 16),
                const Text('FitCoaching', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 48),
                
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email', labelStyle: const TextStyle(color: Colors.grey),
                    filled: true, fillColor: inputColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password', labelStyle: const TextStyle(color: Colors.grey),
                    filled: true, fillColor: inputColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(backgroundColor: neonGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('SIGN IN', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}