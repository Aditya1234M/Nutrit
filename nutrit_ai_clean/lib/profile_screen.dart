import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),
        const CircleAvatar(
          radius: 45,
          backgroundColor: Colors.green,
          child: Icon(Icons.person, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text(
          "User Name",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text("Healthy Lifestyle Enthusiast"),
        const SizedBox(height: 20),

        Expanded(
          child: ListView(
            children: const [
              _ProfileItem(icon: Icons.settings, title: "Settings"),
              _ProfileItem(icon: Icons.notifications, title: "Notifications"),
              _ProfileItem(icon: Icons.help, title: "Help & Support"),
              _ProfileItem(icon: Icons.logout, title: "Logout"),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ProfileItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}
