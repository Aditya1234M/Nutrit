import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/profile_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MealProvider>().refreshAll();
      context.read<ProfileProvider>().loadTargets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final meals = context.watch<MealProvider>();
    final profile = context.watch<ProfileProvider>();

    final summary = meals.dailySummary;
    final targets = profile.targets;
    final userName = auth.currentUser?.name ?? 'there';
    final firstName = userName.split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF2D6A4F),
          onRefresh: () async {
            await meals.refreshAll();
            await profile.loadTargets();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  "Hey $firstName 👋",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4332),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Track your nutrition smarter with AI",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),

                // Daily Summary Card — REAL DATA
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
                        color: const Color(0xFF2D6A4F).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Calories",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.totalCalories.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        "/ ${targets.dailyCalories.toStringAsFixed(0)} kcal",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: summary.calorieProgress.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${(summary.calorieProgress * 100).toStringAsFixed(0)}% of daily goal",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Stats Grid — REAL DATA
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.restaurant_rounded,
                        label: "Meals",
                        value: "${summary.mealCount}",
                        color: const Color(0xFF52B788),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _statCard(
                        icon: Icons.water_drop_rounded,
                        label: "Water",
                        value: "${(summary.waterMl / 1000).toStringAsFixed(1)} L",
                        color: const Color(0xFF74C69D),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.local_fire_department_rounded,
                        label: "Protein",
                        value: "${summary.totalProtein.toStringAsFixed(0)}g",
                        color: const Color(0xFF95D5B2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _statCard(
                        icon: Icons.fitness_center_rounded,
                        label: "Carbs",
                        value: "${summary.totalCarbs.toStringAsFixed(0)}g",
                        color: const Color(0xFFB7E4C7),
                      ),
                    ),
                  ],
                ),

                // Today's meals list
                if (meals.todaysMeals.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text(
                    "Today's Meals",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4332),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...meals.todaysMeals.map((meal) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF52B788).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              meal.mealType == 'breakfast' ? '🌅' :
                              meal.mealType == 'lunch' ? '☀️' :
                              meal.mealType == 'dinner' ? '🌙' : '🍎',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal.foods.map((f) => f.foodName.replaceAll('_', ' ')).join(', '),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1B4332),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${meal.totalCalories.toStringAsFixed(0)} kcal • ${meal.totalProtein.toStringAsFixed(0)}g protein',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (meal.score != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: meal.score! >= 70
                                    ? const Color(0xFF52B788).withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${meal.score!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: meal.score! >= 70
                                      ? const Color(0xFF2D6A4F)
                                      : Colors.orange[800],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B4332),
            ),
          ),
        ],
      ),
    );
  }
}
