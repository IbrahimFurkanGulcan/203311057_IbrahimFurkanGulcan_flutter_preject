import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // FlutterFire'ın bizim için oluşturduğu dosya

void main() async {
  // Flutter widget'larının çizilmeye hazır olduğundan emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase motorunu başlatıyoruz
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
      title: 'Uçak Bileti Sistemi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const Scaffold(
        body: Center(
          child: Text("Firebase Başarıyla Bağlandı! 🎉"),
        ),
      ),
    );
  }
}