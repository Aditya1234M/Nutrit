import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/meal_provider.dart';
import '../main_navigation.dart';

class BodyParametersScreen extends StatefulWidget {
  const BodyParametersScreen({super.key});

  @override
  State<BodyParametersScreen> createState() => _BodyParametersScreenState();
}

class _BodyParametersScreenState extends State<BodyParametersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  
  String _selectedGender = 'male';
  String _selectedActivityLevel = 'moderate';

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Body Parameters",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4332),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Help us personalize your nutrition plan",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Gender Selection
                const Text(
                  "Gender",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B4332),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _genderCard(
                        'male',
                        'Male',
                        Icons.male_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _genderCard(
                        'female',
                        'Female',
                        Icons.female_rounded,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Age
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Age",
                    hintText: "Enter your age",
                    suffixText: "years",
                    prefixIcon: const Icon(Icons.cake_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF2D6A4F),
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your age';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 13 || age > 120) {
                      return 'Please enter a valid age';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Weight
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Weight",
                    hintText: "Enter your weight",
                    suffixText: "kg",
                    prefixIcon: const Icon(Icons.monitor_weight_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF2D6A4F),
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your weight';
                    }
                    final weight = double.tryParse(value);
                    if (weight == null || weight < 20 || weight > 300) {
                      return 'Please enter a valid weight';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Height
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Height",
                    hintText: "Enter your height",
                    suffixText: "cm",
                    prefixIcon: const Icon(Icons.height_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF2D6A4F),
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your height';
                    }
                    final height = double.tryParse(value);
                    if (height == null || height < 100 || height > 250) {
                      return 'Please enter a valid height';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Activity Level
                const Text(
                  "Activity Level",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B4332),
                  ),
                ),
                const SizedBox(height: 12),
                
                _activityCard('sedentary', 'Sedentary', 'Little or no exercise'),
                _activityCard('light', 'Lightly Active', 'Exercise 1-3 days/week'),
                _activityCard('moderate', 'Moderately Active', 'Exercise 3-5 days/week'),
                _activityCard('very', 'Very Active', 'Exercise 6-7 days/week'),
                _activityCard('extra', 'Extra Active', 'Physical job + exercise'),
                
                const SizedBox(height: 32),
                
                // Complete Button
                SizedBox(
                  width: double.infinity,
                  child: Consumer<ProfileProvider>(
                    builder: (context, profileProvider, _) {
                      return ElevatedButton(
                        onPressed: profileProvider.isLoading ? null : () async {
                          if (!_formKey.currentState!.validate()) return;

                          final success = await profileProvider.updateProfile(
                            age: int.parse(_ageController.text),
                            weight: double.parse(_weightController.text),
                            height: double.parse(_heightController.text),
                            gender: _selectedGender,
                            activityLevel: _selectedActivityLevel,
                          );

                          if (success && mounted) {
                            // Load fresh data for home screen
                            context.read<MealProvider>().refreshAll();

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const MainNavigation(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: profileProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Complete Setup",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderCard(String value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2D6A4F)
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected
                  ? const Color(0xFF2D6A4F)
                  : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF2D6A4F)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityCard(String value, String title, String description) {
    final isSelected = _selectedActivityLevel == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedActivityLevel = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2D6A4F)
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2D6A4F).withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isSelected
                    ? const Color(0xFF2D6A4F)
                    : Colors.grey[400],
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF2D6A4F)
                          : const Color(0xFF1B4332),
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
