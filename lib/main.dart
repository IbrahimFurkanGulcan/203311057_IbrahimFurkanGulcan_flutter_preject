import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UcakBiletiApp());
}

class UcakBiletiApp extends StatelessWidget {
  const UcakBiletiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FlyCheck',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      // Sihirli Kısım: StreamBuilder
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(), // Firebase Auth'u dinle
        builder: (context, snapshot) {
          // Eğer giriş yapmış bir kullanıcı verisi geliyorsa Ana Sayfaya git
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          // Veri yoksa (çıkış yapmışsa veya yeni indirmişse) Login'e git
          return const LoginScreen();
        },
      ),
    );
  }
}