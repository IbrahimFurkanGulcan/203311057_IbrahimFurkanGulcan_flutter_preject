import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
  if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
    setState(() { _isLoading = true; });

    String? result = await AuthService().signInUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return; // 🔥 KRİTİK SATIR

    setState(() { _isLoading = false; });

    if (result != "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result ?? "Giriş başarısız")),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea( // Çentiğin/Kameranın altına gelmemesi için
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flight_takeoff, size: 100, color: Colors.blue),
              const SizedBox(height: 20),
              const Text('FlyCheck Sistemine Hoşgeldiniz', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Giriş Yap'),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                },
                child: const Text('Hesabın yok mu? Kayıt Ol'),
              )
            ],
          ),
        ),
      ),
    );
  }
}