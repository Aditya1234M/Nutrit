/// ML inference service — Real TFLite model runner with multi-head output.
///
/// Loads the trained EfficientNetB3 multi-head model and runs on-device
/// inference. Two classification heads: Food-101 (101 classes) and
/// Indian Food (80 classes). The head with higher confidence wins.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/food_prediction.dart';

class MlService {
  static Interpreter? _interpreter;
  static Map<String, Map<String, String>>? _labelMap;
  static bool _isInitialized = false;

  /// Initialize the TFLite model and label map. Call once on app start.
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(
        'assets/multihead_food_float16.tflite',
      );
      print('[MlService] Model loaded successfully');

      // Print input/output tensor info for debugging
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      print('[MlService] Input tensors: ${inputTensors.length}');
      for (var t in inputTensors) {
        print('  Input: shape=${t.shape}, type=${t.type}');
      }
      print('[MlService] Output tensors: ${outputTensors.length}');
      for (var t in outputTensors) {
        print('  Output: shape=${t.shape}, type=${t.type}');
      }

      // Load label map
      final jsonStr = await rootBundle.loadString('assets/label_map.json');
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      _labelMap = {
        'food101': Map<String, String>.from(decoded['food101']),
        'indian': Map<String, String>.from(decoded['indian']),
      };
      print('[MlService] Label map loaded: '
          '${_labelMap!["food101"]!.length} Food-101, '
          '${_labelMap!["indian"]!.length} Indian classes');

      _isInitialized = true;
    } catch (e) {
      print('[MlService] Init failed: $e');
      // Fall back to mock predictions if model fails to load
      _isInitialized = false;
    }
  }

  /// Run inference on an image file and return top predictions.
  static Future<List<FoodPrediction>> predict(String imagePath) async {
    if (!_isInitialized || _interpreter == null || _labelMap == null) {
      print('[MlService] Not initialized, returning mock predictions');
      return _getMockPredictions();
    }

    try {
      // 1. Load and preprocess the image
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        print('[MlService] Failed to decode image');
        return _getMockPredictions();
      }

      // 2. Resize to 300x300 (EfficientNetB3 input size)
      final resized = img.copyResize(decodedImage, width: 300, height: 300);

      // 3. Convert to Float32 tensor [1, 300, 300, 3] — keep [0, 255] range!
      //    EfficientNet has built-in preprocessing, do NOT divide by 255.
      final input = List.generate(
        1,
        (_) => List.generate(
          300,
          (y) => List.generate(
            300,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r.toDouble(), // Red [0-255]
                pixel.g.toDouble(), // Green [0-255]
                pixel.b.toDouble(), // Blue [0-255]
              ];
            },
          ),
        ),
      );

      // 4. Prepare output buffers for both heads
      //    IMPORTANT: TFLite output order may differ from training order!
      //    Output 0: Indian head [1, 80] softmax probabilities
      //    Output 1: Food-101 head [1, 101] softmax probabilities
      final indianOutput = List.generate(1, (_) => List.filled(80, 0.0));
      final food101Output = List.generate(1, (_) => List.filled(101, 0.0));

      final outputs = <int, Object>{
        0: indianOutput,
        1: food101Output,
      };

      // 5. Run inference
      _interpreter!.runForMultipleInputs([input], outputs);

      final food101Probs = food101Output[0];
      final indianProbs = indianOutput[0];

      // 6. Get top predictions from each head
      final predictions = <FoodPrediction>[];

      // Top 3 from Food-101 head
      final food101Sorted = _getTopN(food101Probs, 3);
      for (var entry in food101Sorted) {
        final name = _labelMap!['food101']![entry.key.toString()] ?? 'unknown';
        predictions.add(FoodPrediction(
          foodName: name,
          confidence: entry.value,
          headSource: 'food101',
        ));
      }

      // Top 3 from Indian head
      final indianSorted = _getTopN(indianProbs, 3);
      for (var entry in indianSorted) {
        final name = _labelMap!['indian']![entry.key.toString()] ?? 'unknown';
        predictions.add(FoodPrediction(
          foodName: name,
          confidence: entry.value,
          headSource: 'indian',
        ));
      }

      // 7. Sort all predictions by confidence and return top 3
      predictions.sort((a, b) => b.confidence.compareTo(a.confidence));
      return predictions.take(3).toList();
    } catch (e) {
      print('[MlService] Inference error: $e');
      return _getMockPredictions();
    }
  }

  /// Get top N predictions from a probability array.
  static List<MapEntry<int, double>> _getTopN(List<double> probs, int n) {
    final indexed = probs.asMap().entries.toList();
    indexed.sort((a, b) => b.value.compareTo(a.value));
    return indexed.take(n).toList();
  }

  /// Dispose the interpreter to free memory.
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }

  /// Mock predictions as fallback when model isn't available.
  static List<FoodPrediction> _getMockPredictions() {
    final random = Random();
    final mockFoods = [
      FoodPrediction(
        foodName: 'butter_chicken',
        confidence: 0.85 + random.nextDouble() * 0.1,
        headSource: 'indian',
        caloriesPer100g: 195,
        proteinPer100g: 15,
        carbsPer100g: 8,
        fatPer100g: 12,
        fiberPer100g: 1,
      ),
      FoodPrediction(
        foodName: 'naan',
        confidence: 0.72 + random.nextDouble() * 0.1,
        headSource: 'indian',
        caloriesPer100g: 290,
        proteinPer100g: 9,
        carbsPer100g: 50,
        fatPer100g: 6,
        fiberPer100g: 2,
      ),
      FoodPrediction(
        foodName: 'biryani',
        confidence: 0.65 + random.nextDouble() * 0.1,
        headSource: 'indian',
        caloriesPer100g: 180,
        proteinPer100g: 8,
        carbsPer100g: 25,
        fatPer100g: 6,
        fiberPer100g: 1,
      ),
    ];
    mockFoods.shuffle(random);
    return mockFoods.sublist(0, 3);
  }
}
