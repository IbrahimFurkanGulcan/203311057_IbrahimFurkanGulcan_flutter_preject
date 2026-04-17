import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimlerim')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService().getNotificationsStream(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) return const Center(child: Text("Bildiriminiz bulunmuyor."));

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var notif = snapshot.data![index];
              return ListTile(
                leading: Icon(notif.isRead ? Icons.mark_email_read : Icons.mark_email_unread, color: notif.isRead ? Colors.grey : Colors.blue),
                title: Text(notif.title, style: TextStyle(fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(notif.message),
                onTap: () => NotificationService().markAsRead(notif.id),
              );
            },
          );
        },
      ),
    );
  }
}