import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;

  void _register() async {
    // Formdaki zorunlu alanlar doldurulmuş mu kontrol et
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      // Servisimizdeki fonksiyonu çağırıyoruz
      String? result = await AuthService().signUpUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      // 🔥 KRİTİK SATIR: Eğer biz Firebase'i beklerken kullanıcı geri tuşuna 
      // basıp ekranı kapattıysa, aşağıdaki hiçbir kodu çalıştırma ve iptal et.
      if (!mounted) return; 

      setState(() { _isLoading = false; });

      // Kayıt başarılıysa geri dön (Login ekranına)
      if (result == "success") {
        Navigator.pop(context); // Zaten yukarıda mounted kontrolü yaptık, direkt pop edebiliriz.
      } else {
        // Hata varsa ekranda göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result ?? "Bir hata oluştu")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView( 
            child: Column(
              children: [
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'İsim', border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? 'İsim boş bırakılamaz' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Soyisim', border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? 'Soyisim boş bırakılamaz' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.isEmpty ? 'E-posta boş bırakılamaz' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder()),
                  obscureText: true, 
                  validator: (value) => value!.length < 6 ? 'Şifre en az 6 karakter olmalı' : null,
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                        child: const Text('Hesap Oluştur'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}