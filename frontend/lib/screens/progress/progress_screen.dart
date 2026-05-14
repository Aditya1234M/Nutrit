import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/profile_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MealProvider>().loadWeeklyProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final weekly = context.watch<MealProvider>().weeklyProgress;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                "Your Progress",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4332),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Track your health journey",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),
              
              // Stats Grid
              // Stats using real data
              _progressCard(
                title: "Weight",
                value: profile.profile?.weight?.toStringAsFixed(0) ?? "--",
                unit: "kg",
                icon: Icons.monitor_weight_rounded,
                color: const Color(0xFF2D6A4F),
                trend: profile.profile?.goalType == 'lose' ? 'Losing' :
                       profile.profile?.goalType == 'gain' ? 'Gaining' : 'Maintaining',
                trendPositive: true,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _progressCard(
                      title: "BMI",
                      value: _calculateBMI(profile.profile?.weight, profile.profile?.height),
                      unit: "",
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFF52B788),
                      trend: "Normal",
                      trendPositive: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _progressCard(
                      title: "Streak",
                      value: "${weekly.streak}",
                      unit: "days",
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFF74C69D),
                      trend: weekly.streak > 0 ? "🔥 Active" : "Start today!",
                      trendPositive: weekly.streak > 0,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _progressCard(
                title: "Avg Calories",
                value: weekly.avgCalories.toStringAsFixed(0),
                unit: "kcal/day",
                icon: Icons.restaurant_rounded,
                color: const Color(0xFF95D5B2),
                trend: weekly.avgCalories > 0 ? "On track" : "No data yet",
                trendPositive: weekly.avgCalories > 0,
              ),
              
              const SizedBox(height: 32),
              
              // Weekly Overview
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "This Week",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4332),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _weeklyBar("Mon", 0.8),
                    _weeklyBar("Tue", 0.95),
                    _weeklyBar("Wed", 0.7),
                    _weeklyBar("Thu", 0.85),
                    _weeklyBar("Fri", 0.9),
                    _weeklyBar("Sat", 0.6),
                    _weeklyBar("Sun", 0.75),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required String trend,
    required bool trendPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: trendPositive
                      ? const Color(0xFF2D6A4F).withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    color: trendPositive ? const Color(0xFF2D6A4F) : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4332),
                  letterSpacing: -0.5,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _weeklyBar(String day, double progress) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 35,
            child: Text(
              day,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.lerp(
                    const Color(0xFF95D5B2),
                    const Color(0xFF2D6A4F),
                    progress,
                  )!,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 35,
            child: Text(
              "${(progress * 100).toInt()}%",
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF1B4332),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateBMI(double? weight, double? height) {
    if (weight == null || height == null || height == 0) return '--';
    final bmi = weight / ((height / 100) * (height / 100));
    return bmi.toStringAsFixed(1);
  }
}
