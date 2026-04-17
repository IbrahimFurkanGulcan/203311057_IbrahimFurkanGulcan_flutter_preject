import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ucak_bileti_rezervasyon_ve_check_in_sistemi/screens/admin/add_flight_screen.dart';
import '../services/auth_service.dart';
import 'package:ucak_bileti_rezervasyon_ve_check_in_sistemi/services/dummy_data_service.dart';
import 'passenger/search_flight_screen.dart';
import 'passenger/my_tickets_screen.dart';
import 'passenger/check_in_hub_screen.dart';
import 'package:ucak_bileti_rezervasyon_ve_check_in_sistemi/services/notification_service.dart';
import 'package:ucak_bileti_rezervasyon_ve_check_in_sistemi/screens/passenger/notifications_screen.dart'; 
import 'package:ucak_bileti_rezervasyon_ve_check_in_sistemi/models/notification_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAdmin = false;
  bool _isLoading = true;
  String _currentUserId = '';

  // Alt menü için hangi sekmede olduğumuzu tutan değişken
  int _selectedIndex = 0;

  // Alt menüde gösterilecek ekranların listesi
  final List<Widget> _pages = [
    const SearchFlightScreen(),
    const MyTicketsScreen(),
    const CheckInHubScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  // Giriş yapan kullanıcının rolünü güvenli bir şekilde çekiyoruz
  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            if (userDoc.exists) {
              Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
              _isAdmin = (data != null && data['role'] == 'admin');
            }
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() { _isLoading = false; });
      }
    } else {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Alt menüye tıklandığında çalışacak fonksiyon
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Yükleme ekranını tüm Scaffold'u kaplayacak şekilde ayarladık
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        // Başlık artık seçili sekmeye göre değişiyor
        title: Text(_selectedIndex == 0 ? 'Uçuş Ara' : _selectedIndex == 1 ? 'Biletlerim' : 'Check-in'),
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: NotificationService().getNotificationsStream(_currentUserId),
            builder: (context, snapshot) {
              int unreadCount = 0;
              // Eğer veri varsa ve okunmamış bildirimleri say
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.where((n) => !n.isRead).length;
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, size: 28),
                    onPressed: () {
                      // Zile basılınca bildirimler ekranına götür
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                  // Eğer okunmamış bildirim varsa kırmızı rozeti göster
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // SADECE ADMİNSE GÖRÜNECEK BUTONLAR
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddFlightScreen()),
                );
              },
            ),

          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.orange),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test verileri yükleniyor... Bekleyin.')),
                );
                
                String result = await DummyDataService().generateMockFlights();
                
                if (result == "success" && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('55 Uçuş başarıyla eklendi! 🎉'), backgroundColor: Colors.green),
                  );
                }
              },
            ),
          
          // ÇIKIŞ YAP (LOGOUT) BUTONU
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
      
      // Orta kısım artık statik bir Text değil, seçili sayfayı gösteriyor
      body: _pages[_selectedIndex],

      // Alt Gezinme Menüsü
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Uçuş Ara',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number),
            label: 'Biletlerim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'Check-in',
          ),
        ],
      ),
    );
  }
}