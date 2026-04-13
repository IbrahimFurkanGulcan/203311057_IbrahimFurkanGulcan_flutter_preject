import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  // Giriş yapan kullanıcının rolünü güvenli bir şekilde çekiyoruz
  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            // Eğer doküman varsa ve 'role' alanı 'admin' ise true yap
            if (userDoc.exists) {
              Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
              _isAdmin = (data != null && data['role'] == 'admin');
            }
            _isLoading = false; // Ne olursa olsun yüklemeyi bitir
          });
        }
      } catch (e) {
        if (mounted) setState(() { _isLoading = false; });
      }
    } else {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 🔥 İŞTE SİHİRLİ KOD: Geri ok tuşunu (<-) ne olursa olsun gizler/kapatır!
        automaticallyImplyLeading: false, 
        title: const Text('FlyCheck Uçuşlar'),
        actions: [
          // SADECE ADMİNSE GÖRÜNECEK BUTON
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add, size: 28),
              onPressed: () {
                // TODO: AddFlightScreen'e yönlendirilecek
              },
            ),
          // DEĞİŞEN KISIM: İkon yerine açıkça yazılı Log Out butonu
          TextButton.icon(
            onPressed: () async {
              await AuthService().signOutUser();
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Text(
                _isAdmin ? 'Hoşgeldin Admin!\nSağ üstten uçuş ekleyebilirsin.' : 'Hoşgeldin Yolcu!\nUçuşları listeliyoruz.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}