import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Profile Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D6A4F), Color(0xFF40916C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2D6A4F).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 45,
                        backgroundColor: Color(0xFFF8FBF9),
                        child: Icon(
                          Icons.person_rounded,
                          size: 50,
                          color: Color(0xFF2D6A4F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.watch<AuthProvider>().currentUser?.name ?? 'User',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Free Plan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Menu Items
              _ProfileItem(
                icon: Icons.workspace_premium_rounded,
                title: "Upgrade to Premium",
                subtitle: "Unlock all features",
                color: const Color(0xFFFFB020),
                onTap: () {},
              ),
              
              const SizedBox(height: 12),
              
              _ProfileItem(
                icon: Icons.person_outline_rounded,
                title: "Edit Profile",
                subtitle: "Update your information",
                color: const Color(0xFF2D6A4F),
                onTap: () {},
              ),
              
              const SizedBox(height: 12),
              
              _ProfileItem(
                icon: Icons.notifications_outlined,
                title: "Notifications",
                subtitle: "Manage your alerts",
                color: const Color(0xFF52B788),
                onTap: () {},
              ),
              
              const SizedBox(height: 12),
              
              _ProfileItem(
                icon: Icons.settings_outlined,
                title: "Settings",
                subtitle: "App preferences",
                color: const Color(0xFF74C69D),
                onTap: () {},
              ),
              
              const SizedBox(height: 12),
              
              _ProfileItem(
                icon: Icons.help_outline_rounded,
                title: "Help & Support",
                subtitle: "Get assistance",
                color: const Color(0xFF95D5B2),
                onTap: () {},
              ),
              
              const SizedBox(height: 24),
              
              // Logout Button
              InkWell(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.red.shade100,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Colors.red.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Logout",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4332),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey[400],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
