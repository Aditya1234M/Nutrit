# NutritAI — Technical Overview

> An AI-powered nutritional tracking application that uses deep learning to identify food from images, calculate nutrition, and provide personalized dietary guidance.

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Mobile App                      │
│                                                              │
│   ┌──────────┐  ┌──────────────┐  ┌───────────────────┐     │
│   │ Camera /  │→ │  TFLite ML   │→ │  Nutrition Lookup │     │
│   │ Gallery   │  │  Inference   │  │  + Meal Logging   │     │
│   └──────────┘  └──────────────┘  └───────────────────┘     │
│         │                                    │               │
│   ┌─────┴──────────────────────────────────────┐            │
│   │  Provider State Management (3 Providers)    │            │
│   │  AuthProvider │ MealProvider │ ProfileProvider│            │
│   └────────────────────┬────────────────────────┘            │
└────────────────────────┼─────────────────────────────────────┘
                         │ HTTP + JWT
┌────────────────────────┼─────────────────────────────────────┐
│                   FastAPI Backend                             │
│                                                              │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐     │
│  │ Auth API │  │ Nutrition DB │  │ Scoring Engine     │     │
│  │ (JWT)    │  │ (200+ foods) │  │ (0-100 scoring)    │     │
│  └──────────┘  └──────────────┘  └────────────────────┘     │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐     │
│  │ User     │  │ Meal Logging │  │ Mifflin-St Jeor    │     │
│  │ Profiles │  │ + Daily Logs │  │ TDEE Calculator    │     │
│  └──────────┘  └──────────────┘  └────────────────────┘     │
│                        │                                     │
│                   SQLite Database                             │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. AI / Machine Learning Pipeline

### 2.1 Multi-Head Classification Architecture

**Problem:** We have two food datasets of vastly different sizes — Food-101 (101 classes, ~101,000 images) and Indian Food (80 classes, ~4,000 images). Training a single unified classifier causes the model to be biased toward Food-101, dropping Indian food accuracy to ~70%.

**Solution: Multi-Head Output Architecture**

```
                    ┌─────────────────────┐
                    │  Input Image        │
                    │  (380 × 380 × 3)    │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   EfficientNet-B3   │
                    │   (Shared Backbone) │
                    │   Pretrained on     │
                    │   ImageNet          │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Global Average     │
                    │  Pooling + Dropout  │
                    └────┬───────────┬────┘
                         │           │
              ┌──────────▼──┐  ┌────▼──────────┐
              │  Head A:    │  │  Head B:       │
              │  Food-101   │  │  Indian Food   │
              │  (101 cls)  │  │  (80 cls)      │
              │  Softmax    │  │  Softmax       │
              └─────────────┘  └────────────────┘
```

**Why Multi-Head?**
- Each head specializes in its domain — no class confusion between datasets
- The shared backbone learns universal food features (texture, color, shape)
- Indian food head gets dedicated capacity despite having 25× fewer samples
- At inference time, we pick the head with the highest-confidence prediction

**Implementation:** `NutritionAI_v2.py` — custom Keras model with `tf.keras.Model` subclassing, two separate `Dense` output layers sharing the same feature extractor.

---

### 2.2 Masked Loss Function

**Problem:** In a multi-head setup, each training image only belongs to ONE dataset. When a Food-101 image is processed, the Indian head's output is meaningless — but a naive loss would still penalize it, corrupting the Indian head's gradients. The original code used label `0` for inactive heads, which taught the model "everything is class 0" — a catastrophic bug.

**Solution: Masked Cross-Entropy Loss with Label `-1`**

```python
def masked_sparse_categorical_crossentropy(y_true, y_pred):
    mask = tf.not_equal(y_true, -1)           # True where labels are valid
    mask_float = tf.cast(mask, tf.float32)

    y_true_safe = tf.where(mask, y_true, 0)   # Replace -1 with 0 (won't affect loss)
    loss = tf.keras.losses.sparse_categorical_crossentropy(y_true_safe, y_pred)
    loss = loss * mask_float                   # Zero out loss for inactive heads

    # Average only over valid samples (avoid division by zero)
    return tf.reduce_sum(loss) / (tf.reduce_sum(mask_float) + 1e-7)
```

**How it works:**
- Food-101 samples get labels `(actual_class, -1)` — Indian head is masked
- Indian samples get labels `(-1, actual_class)` — Food-101 head is masked
- Loss is computed ONLY for the active head; the other head's gradients are zeroed
- This prevents cross-contamination between heads

**What problem it solves:** Eliminates the "class 0 corruption" bug where inactive heads learn incorrect associations, which was the primary cause of low accuracy in the original training.

---

### 2.3 Balanced Sampling Strategy

**Problem:** Food-101 has ~101K images vs Indian Food's ~4K. Using standard `zip()` with iterators causes **data starvation** — the Indian dataset exhausts after 4K steps while Food-101 still has 97K samples left. The `zip()` function silently stops when the shortest iterator ends, meaning 96% of Food-101 data is never seen.

**Solution: `tf.data.Dataset.sample_from_datasets()` with `.repeat()`**

```python
food101_ds = food101_ds.repeat()     # Infinite loop
indian_ds  = indian_ds.repeat()      # Infinite loop

combined = tf.data.Dataset.sample_from_datasets(
    [food101_ds, indian_ds],
    weights=[0.65, 0.35],            # 65% Food-101, 35% Indian
    stop_on_empty_dataset=False
)
```

**Why 65/35 split?**
- Pure 50/50 would oversample the tiny Indian dataset too aggressively, causing overfitting
- 65/35 ensures the Indian head sees enough variety while Food-101 maintains broad coverage
- `.repeat()` makes both datasets infinite — no iterator exhaustion
- `steps_per_epoch` controls when an epoch ends, not dataset size

**What problem it solves:** Ensures both heads receive adequate training data regardless of dataset size imbalance. The Indian head sees each image ~9× per epoch (intentional oversampling), while Food-101 sees each image ~0.65× (standard for large datasets).

---

### 2.4 Transfer Learning: EfficientNet-B4

**Problem:** Training a CNN from scratch on ~105K food images would take days and likely underperform. Food images require understanding of fine-grained textures, colors, and spatial patterns.

**Solution: EfficientNet-B3 pretrained on ImageNet**

| Property | Value |
|----------|-------|
| Input size | 300 × 300 × 3 |
| Parameters | ~12M (backbone) |
| ImageNet Top-1 Accuracy | 81.6% |
| Why B3? | Best accuracy/speed/memory tradeoff for Colab T4 + mobile |

**Multi-Stage Training Strategy:**

| Stage | What's Trained | Learning Rate | Epochs | Purpose |
|-------|---------------|---------------|--------|---------|
| Stage 1 | Only the two classification heads | 1e-3 | 5 | Learn food-specific features without destroying pretrained weights |
| Stage 2 | Top 30 backbone layers + heads | 1e-5 | 10 | Fine-tune high-level features for food domain |

**Why two stages?**
- Stage 1 "warms up" the randomly-initialized heads while the backbone provides stable feature extraction
- Stage 2 then gently adjusts the backbone's upper layers to specialize for food recognition
- This prevents catastrophic forgetting of ImageNet features

---

### 2.5 Data Augmentation

**Problem:** The Indian food dataset has only ~50 images per class — nowhere near enough for a deep network to generalize.

**Solution: Aggressive augmentation for the Indian dataset**

```python
indian_augmentation = tf.keras.Sequential([
    RandomFlip("horizontal"),
    RandomRotation(0.15),          # ±15% rotation
    RandomZoom(0.15),              # ±15% zoom
    RandomContrast(0.2),           # ±20% contrast variation
    RandomBrightness(0.1),         # ±10% brightness
])
```

Each Indian food image generates many visual variants — effectively multiplying the dataset size by 10-20×. Food-101 uses lighter augmentation (just horizontal flip) since it already has enough variety.

---

### 2.6 On-Device TFLite Inference

**Problem:** Cloud-based inference adds latency, requires internet, and raises privacy concerns (uploading food photos to servers).

**Solution: TensorFlow Lite conversion for on-device inference**

```python
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]      # Float16 quantization
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()
```

| Metric | Value |
|--------|-------|
| Model size (original) | ~80 MB |
| Model size (TFLite float16) | ~40 MB |
| Inference time (Snapdragon 800+) | ~200-400ms |
| Inference time (mid-range) | ~500-800ms |

**What problem it solves:** Makes the app work **offline** and **instantly** — no internet required for food recognition. This differentiates NutritAI from most competitors (HealthifyMe, MyFitnessPal) which use cloud-based inference.

---

## 3. Backend Algorithms & Features

### 3.1 Mifflin-St Jeor BMR/TDEE Calculation

**Problem:** Every user has different caloric needs based on their body composition and activity level. A 22-year-old male athlete needs vastly different nutrition than a 45-year-old sedentary woman.

**Solution: Mifflin-St Jeor equation (most accurate BMR formula)**

```
Male:   BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age - 5
Female: BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age - 161

TDEE = BMR × Activity Multiplier
```

| Activity Level | Multiplier | Example |
|---------------|------------|---------|
| Sedentary | 1.2 | Desk job, no exercise |
| Light | 1.375 | 1-3 days/week exercise |
| Moderate | 1.55 | 3-5 days/week exercise |
| Very Active | 1.725 | 6-7 days/week exercise |
| Extra Active | 1.9 | Physical job + daily exercise |

**Goal Adjustment:**
- Weight loss: TDEE - 500 kcal/day (~0.5 kg/week deficit)
- Weight gain: TDEE + 400 kcal/day
- Maintain: TDEE as-is

**Macro Split:** 30% protein / 45% carbs / 25% fat (balanced approach suitable for most goals)

**Implementation:** `backend/app/routers/user_router.py` — `_calculate_bmr()` and `_calculate_tdee()` functions, called whenever profile is updated or targets are requested.

---

### 3.2 Nutritional Scoring Engine

**Problem:** Users don't just want calorie counts — they want to know "was this meal actually good for me?"

**Solution: Multi-factor scoring algorithm (0-100 scale)**

```
Total Score = Calorie Score (30 pts) + Macro Balance (40 pts) + Protein Score (30 pts)
```

**Calorie Appropriateness (0-30 points):**
| Ratio (actual/target) | Points | Feedback |
|----------------------|--------|----------|
| 0.8 - 1.2 | 30 | "Well-balanced" |
| 0.6 - 0.8 or 1.2 - 1.4 | 20 | "Slightly over/under" |
| < 0.6 | 10 | "Too light" |
| > 1.4 | 5 | "Significantly exceeds" |

**Macro Balance (0-40 points):**
- Evaluates protein % (target 20-35%), carbs % (target 40-60%), fat % (target 15-30%)
- Each macro contributes up to 15/15/10 points

**Protein Adequacy (0-30 points):**
| Ratio (actual/target) | Points |
|----------------------|--------|
| ≥ 90% | 30 |
| ≥ 70% | 22 |
| ≥ 50% | 14 |
| < 50% | 6 |

The engine also generates **textual explanations** ("Good protein content") and **actionable suggestions** ("Add more protein — eggs, chicken, paneer, dal").

**Implementation:** `backend/app/scoring.py` — `calculate_meal_score()` function, automatically called when a meal is logged.

---

### 3.3 JWT Authentication

**Problem:** Need stateless, secure authentication that works with mobile apps and can scale to cloud deployment.

**Solution: JSON Web Tokens with bcrypt password hashing**

```
Flow:
1. User registers/logs in → Server verifies credentials
2. Server creates JWT with user_id + email + 30-day expiry
3. Client stores token in SharedPreferences
4. Every API request includes: Authorization: Bearer <token>
5. Server decodes token → identifies user → processes request
```

**Security:**
- Passwords hashed with **bcrypt** (adaptive hashing, resistant to brute force)
- JWT signed with HMAC-SHA256
- 30-day token expiry (configurable)
- Token stored client-side in `SharedPreferences` (auto-login on app restart)

**Implementation:** `backend/app/auth.py` + `providers/auth_provider.dart`

---

### 3.4 Embedded Nutrition Database

**Problem:** External nutrition APIs (USDA FoodData Central) require API keys, add latency, and may not cover Indian foods.

**Solution: Embedded Python dictionary with ~200 foods**

Coverage:
- **80 Indian foods** — matching every class in the Indian food dataset (adhirasam through unni_appam)
- **~95 Food-101 items** — covering the most common western dishes
- **~25 Indian staples** — rice, dal, roti, idli, dosa, paratha, etc.

Each entry stores per-100g values: `(calories, protein_g, carbs_g, fat_g, fiber_g)`

**Fuzzy Matching:** If exact name isn't found, the system tries partial string matching:
```python
# "chicken tikka masala" → finds "chicken_tikka_masala"
# "tikka" → finds "chicken_tikka" (partial match)
```

**Implementation:** `backend/app/nutrition_db.py` — `lookup_food()` with normalization and fuzzy fallback.

---

### 3.5 Automatic Daily Log Aggregation

**Problem:** Users log multiple meals per day. The home screen needs a consolidated daily summary without expensive real-time aggregation queries.

**Solution: Materialized daily log table, auto-updated on every meal action**

```
Meal logged/deleted
      │
      ▼
_update_daily_log()
      │
      ├─ Query all meals for that date
      ├─ Sum calories, protein, carbs, fat
      ├─ Count meals
      └─ Upsert into DailyLog table
```

This means the home screen's daily summary is a single fast database read, not a complex aggregation query across meals and foods.

**Implementation:** `backend/app/routers/meal_router.py` — `_update_daily_log()` called after every `log_meal()` and `delete_meal()`.

---

## 4. Flutter Architecture

### 4.1 Provider State Management

**Problem:** The original app used hardcoded dummy data. Screens couldn't share state (e.g., logging a meal should update the home screen's calorie count).

**Solution: 3 ChangeNotifier providers with Consumer widgets**

```
MultiProvider
  ├─ AuthProvider     → login state, current user, JWT token
  ├─ MealProvider     → today's meals, daily summary, weekly progress
  └─ ProfileProvider  → user profile, personalized nutrition targets
```

**Reactive data flow:**
1. User logs a meal on the Food screen
2. `MealProvider.logMeal()` calls the API
3. API returns the meal with a score
4. Provider adds meal to `todaysMeals` list, calls `notifyListeners()`
5. Home screen automatically rebuilds with new data (via `context.watch`)
6. `loadDailySummary()` fires in background → calorie progress updates

No manual screen refreshing needed — the UI reacts to data changes automatically.

---

### 4.2 Food Scanning Pipeline

The food screen implements a complete scan-to-log pipeline:

```
Camera/Gallery
      │
      ▼
Image Picker (resize to 1024px, 85% quality)
      │
      ▼
ML Service (TFLite inference → top 3 predictions)
      │
      ▼
Nutrition Enrichment (API lookup for each prediction)
      │
      ▼
Results UI (food name, confidence, calories, macros)
      │
      ▼
Meal Type Selection (breakfast/lunch/dinner/snack)
      │
      ▼
Log Meal (API call → scored → daily log updated)
      │
      ▼
Success Feedback (snackbar with score)
```

**Portion Estimation:** Currently uses a default 150g portion. Future improvement: use image segmentation to estimate portion size.

---

### 4.3 Auto-Login Session Management

**Problem:** Users shouldn't have to log in every time they open the app.

**Solution:**

```dart
// On app start:
1. Read JWT token from SharedPreferences
2. If token exists → call GET /api/auth/me
3. If valid → load profile + meals → navigate to Home
4. If expired/invalid → clear token → show Login screen
```

This happens in the `_AppEntry` widget with a loading spinner, so the user sees either the login screen or the home screen — never a flash of wrong content.

---

## 5. Expected Performance

### ML Model (Current Accuracy)

| Metric | Food-101 Head | Indian Food Head |
|--------|--------------|-----------------|
| **Current Top-1 Accuracy** | **76.88%** | **70.63%** |
| Future Goal (with fine-tuning) | 82-87% | 55-65% |
| Expected Top-3 Accuracy | 95%+ | 80%+ |
| Training Time (T4 GPU) | ~6 hours total | (included) |
| Inference Time (mobile) | 200-800ms | (same model) |

### Backend

| Metric | Value |
|--------|-------|
| API Response Time | < 50ms (SQLite, local) |
| Concurrent Users | ~100 (SQLite limit; PostgreSQL for production) |
| Database Size | ~1MB per 10,000 meals |

---

## 6. How NutritAI Compares

| Feature | NutritAI | HealthifyMe | MyFitnessPal |
|---------|----------|-------------|-------------|
| Food Recognition | ✅ On-device AI | Cloud-based | Manual search |
| Indian Food Support | ✅ Dedicated head (80 classes) | Yes (cloud) | Limited |
| Offline Mode | ✅ TFLite inference | ❌ | ❌ |
| Personalized Targets | ✅ Mifflin-St Jeor | Yes | Yes |
| Meal Scoring | ✅ Multi-factor (0-100) | Basic | Basic |
| Privacy | ✅ No food photos uploaded | Photos sent to cloud | N/A |
| Cost | Free | Freemium ($5-10/mo) | Freemium ($10/mo) |

**Key differentiator:** On-device inference with dedicated Indian food support — no internet needed, no photos uploaded to servers, and specialized accuracy for Indian cuisine.

---

## 7. Tech Stack Summary

| Layer | Technology | Why |
|-------|-----------|-----|
| ML Framework | TensorFlow / Keras | Best TFLite conversion support |
| Backbone | EfficientNet-B3 | Best accuracy/size/memory tradeoff |
| Mobile Inference | TensorFlow Lite (float16) | On-device, fast, small |
| Mobile App | Flutter (Dart) | Cross-platform, one codebase |
| State Management | Provider | Simple, official Flutter recommendation |
| Backend | FastAPI (Python) | Async, auto-docs, Pydantic validation |
| Database | SQLite (dev) → PostgreSQL (prod) | Zero-config dev, scalable prod |
| Auth | JWT + bcrypt | Stateless, secure, mobile-friendly |
| Training Env | Google Colab (T4 GPU) | Free, powerful, accessible |

---

## 8. Files Created / Modified

### ML Pipeline (1 file)
- `NutritionAI_v2.py` — Complete training pipeline with masked loss, balanced sampling, multi-stage training, TFLite conversion

### Backend (12 files)
- `backend/requirements.txt` — Python dependencies
- `backend/app/main.py` — FastAPI entry point
- `backend/app/database.py` — SQLAlchemy + SQLite
- `backend/app/models.py` — 5 ORM models
- `backend/app/schemas.py` — 15+ Pydantic schemas
- `backend/app/auth.py` — JWT + bcrypt auth
- `backend/app/nutrition_db.py` — 200+ food nutrition entries
- `backend/app/scoring.py` — Multi-factor meal scoring
- `backend/app/routers/auth_router.py` — 3 auth endpoints
- `backend/app/routers/user_router.py` — 4 user endpoints
- `backend/app/routers/meal_router.py` — 4 meal endpoints
- `backend/app/routers/nutrition_router.py` — 3 nutrition endpoints

### Flutter (14 files)
- `pubspec.yaml` — Added 5 dependencies
- `lib/main.dart` — MultiProvider + auto-login
- `lib/models/user.dart`, `meal.dart`, `food_prediction.dart` — Data models
- `lib/services/api_service.dart` — HTTP client
- `lib/services/ml_service.dart` — TFLite inference
- `lib/providers/auth_provider.dart`, `meal_provider.dart`, `profile_provider.dart` — State management
- `lib/screens/` — 8 screens wired to real data
