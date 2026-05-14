import 'package:flutter/material.dart';
import 'body_parameters_screen.dart';

class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  String? _selectedGoal;

  final List<GoalOption> _goals = [
    GoalOption(
      id: 'lose',
      title: 'Lose Weight',
      description: 'Reduce body weight with healthy nutrition',
      icon: Icons.trending_down_rounded,
      color: const Color(0xFF2D6A4F),
    ),
    GoalOption(
      id: 'maintain',
      title: 'Maintain Weight',
      description: 'Keep your current weight stable',
      icon: Icons.trending_flat_rounded,
      color: const Color(0xFF52B788),
    ),
    GoalOption(
      id: 'gain',
      title: 'Gain Weight',
      description: 'Build muscle and increase body mass',
      icon: Icons.trending_up_rounded,
      color: const Color(0xFF74C69D),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              const Text(
                "What's Your Goal?",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4332),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Choose your primary health objective",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 40),
              
              Expanded(
                child: ListView.builder(
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    return _buildGoalCard(_goals[index]);
                  },
                ),
              ),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Skip validation for demo - navigate to main app
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BodyParametersScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(GoalOption goal) {
    final isSelected = _selectedGoal == goal.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoal = goal.id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? goal.color
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: goal.color.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: goal.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                goal.icon,
                color: goal.color,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4332),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    goal.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: goal.color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GoalOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  GoalOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
