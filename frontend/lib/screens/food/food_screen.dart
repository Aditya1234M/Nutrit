import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../services/ml_service.dart';
import '../../services/api_service.dart';
import '../../models/food_prediction.dart';
import '../../models/meal.dart';
import '../../providers/meal_provider.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  List<FoodPrediction> _predictions = [];
  bool _isAnalyzing = false;
  String _selectedMealType = 'lunch';

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _predictions = [];
      });
      _analyzeImage(image.path);
    }
  }

  Future<void> _analyzeImage(String imagePath) async {
    setState(() => _isAnalyzing = true);

    try {
      final predictions = await MlService.predict(imagePath);

      // Enrich with nutrition data from backend
      for (var pred in predictions) {
        try {
          final nutrition = await ApiService.get(
            '/api/nutrition/lookup/${Uri.encodeComponent(pred.foodName)}',
          );
          predictions[predictions.indexOf(pred)] = FoodPrediction(
            foodName: pred.foodName,
            confidence: pred.confidence,
            headSource: pred.headSource,
            caloriesPer100g: (nutrition['calories_per_100g'] as num?)?.toDouble(),
            proteinPer100g: (nutrition['protein_per_100g'] as num?)?.toDouble(),
            carbsPer100g: (nutrition['carbs_per_100g'] as num?)?.toDouble(),
            fatPer100g: (nutrition['fat_per_100g'] as num?)?.toDouble(),
            fiberPer100g: (nutrition['fiber_per_100g'] as num?)?.toDouble(),
          );
        } catch (_) {
          // Nutrition lookup failed — keep prediction without nutrition data
        }
      }

      setState(() {
        _predictions = predictions;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    }
  }

  Future<void> _logSelectedFoods() async {
    if (_predictions.isEmpty) return;

    final foods = _predictions.map((p) {
      final portionG = 150.0; // Default portion estimate
      final scale = portionG / 100.0;
      return MealFood(
        id: '',
        foodName: p.foodName,
        confidence: p.confidence,
        portionGrams: portionG,
        calories: (p.caloriesPer100g ?? 150) * scale,
        protein: (p.proteinPer100g ?? 5) * scale,
        carbs: (p.carbsPer100g ?? 20) * scale,
        fat: (p.fatPer100g ?? 5) * scale,
        fiber: (p.fiberPer100g ?? 1) * scale,
      );
    }).toList();

    final meal = await context.read<MealProvider>().logMeal(
      mealType: _selectedMealType,
      foods: foods,
    );

    if (meal != null && mounted) {
      setState(() {
        _selectedImage = null;
        _predictions = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${meal.mealTypeDisplay} logged! Score: ${meal.score?.toStringAsFixed(0) ?? "-"}/100',
          ),
          backgroundColor: const Color(0xFF2D6A4F),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                "Scan Food 📸",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4332),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Take a photo or upload from gallery",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Camera / Gallery Buttons
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.camera_alt_rounded,
                      label: "Camera",
                      color: const Color(0xFF2D6A4F),
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.photo_library_rounded,
                      label: "Gallery",
                      color: const Color(0xFF52B788),
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),

              // Image Preview
              if (_selectedImage != null) ...[
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    _selectedImage!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              // Analyzing Indicator
              if (_isAnalyzing) ...[
                const SizedBox(height: 24),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF2D6A4F)),
                      SizedBox(height: 16),
                      Text(
                        "Analyzing your food...",
                        style: TextStyle(
                          color: Color(0xFF2D6A4F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Predictions Results
              if (_predictions.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  "Identified Foods",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4332),
                  ),
                ),
                const SizedBox(height: 16),
                ..._predictions.map((pred) => _predictionCard(pred)),

                // Meal Type Selector
                const SizedBox(height: 20),
                const Text(
                  "Log as",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B4332),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: ['breakfast', 'lunch', 'dinner', 'snack'].map((type) {
                    final isSelected = _selectedMealType == type;
                    final emoji = type == 'breakfast' ? '🌅' :
                                  type == 'lunch' ? '☀️' :
                                  type == 'dinner' ? '🌙' : '🍎';
                    return ChoiceChip(
                      label: Text('$emoji ${type[0].toUpperCase()}${type.substring(1)}'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedMealType = type);
                      },
                      selectedColor: const Color(0xFF52B788).withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF1B4332) : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),

                // Log Meal Button
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: Consumer<MealProvider>(
                    builder: (context, mealProvider, _) {
                      return ElevatedButton.icon(
                        onPressed: mealProvider.isLoading ? null : _logSelectedFoods,
                        icon: mealProvider.isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(
                          mealProvider.isLoading ? "Logging..." : "Log Meal",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Empty State
              if (_selectedImage == null && _predictions.isEmpty) ...[
                const SizedBox(height: 48),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF52B788).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fastfood_rounded,
                          size: 48,
                          color: Color(0xFF52B788),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Snap a photo of your meal",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Our AI will identify the food\nand calculate nutrition info",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _predictionCard(FoodPrediction pred) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pred.headSource == 'indian'
                      ? Colors.orange.withValues(alpha: 0.15)
                      : const Color(0xFF52B788).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pred.headSource == 'indian' ? '🇮🇳 Indian' : '🌍 Global',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pred.headSource == 'indian'
                        ? Colors.orange[800]
                        : const Color(0xFF2D6A4F),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                pred.confidencePercent,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pred.confidence >= 0.7
                      ? const Color(0xFF2D6A4F)
                      : Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pred.displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B4332),
            ),
          ),
          if (pred.caloriesPer100g != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _nutrientChip('🔥 ${pred.caloriesPer100g!.toStringAsFixed(0)} kcal'),
                _nutrientChip('💪 ${pred.proteinPer100g?.toStringAsFixed(0) ?? "?"}g P'),
                _nutrientChip('🌾 ${pred.carbsPer100g?.toStringAsFixed(0) ?? "?"}g C'),
                _nutrientChip('🫧 ${pred.fatPer100g?.toStringAsFixed(0) ?? "?"}g F'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'per 100g',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nutrientChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
      ),
    );
  }
}
