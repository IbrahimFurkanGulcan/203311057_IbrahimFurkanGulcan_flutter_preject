import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  // Firebase Auth ve Firestore motorlarını başlatıyoruz
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. KAYIT OLMA (Sign Up) Fonsiyonu
  Future<String?> signUpUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      // Adım A: Firebase Authentication'da e-posta ve şifre ile kullanıcı oluştur
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Adım B: Oluşan kullanıcının UID'sini al
      String uid = credential.user!.uid;

      // Adım C: Kendi yazdığımız UserModel'e bu bilgileri doldur
      UserModel newUser = UserModel(
        uid: uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: 'passenger', // Herkes başlangıçta yolcu olarak kaydedilir
      );

      // Adım D: Bu modeli Firestore'daki 'users' tablosuna kaydet
      await _firestore.collection('users').doc(uid).set(newUser.toMap());

      return "success"; // Başarılı olursa success döndür
    } on FirebaseAuthException catch (e) {
      // Firebase'den gelen hataları yakala (Örn: Bu e-posta zaten kullanımda)
      if (e.code == 'email-already-in-use') {
        return "Bu e-posta adresi zaten kullanımda.";
      } else if (e.code == 'weak-password') {
        return "Şifreniz çok zayıf, en az 6 karakter olmalı.";
      }
      return e.message;
    } catch (e) {
      return "Bir hata oluştu: $e";
    }
  }

  // 2. GİRİŞ YAPMA (Sign In) Fonksiyonu
  Future<String?> signInUser({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return "success";
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return "E-posta veya şifre hatalı.";
      }
      return e.message;
    } catch (e) {
      return "Bir hata oluştu: $e";
    }
  }

  // 3. ÇIKIŞ YAPMA (Sign Out) Fonksiyonu
  Future<void> signOutUser() async {
    await _auth.signOut();
  }
}