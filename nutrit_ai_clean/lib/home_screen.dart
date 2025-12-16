import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Good Day 👋",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "Track your nutrition smarter with AI",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          _infoCard(
            icon: Icons.local_fire_department,
            title: "Calories Today",
            value: "1,450 kcal",
          ),
          _infoCard(
            icon: Icons.restaurant,
            title: "Meals Logged",
            value: "3 meals",
          ),
          _infoCard(
            icon: Icons.water_drop,
            title: "Water Intake",
            value: "2.1 L",
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(icon, color: Colors.green),
        ),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
