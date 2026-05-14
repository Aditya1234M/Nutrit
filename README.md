# 🥗 NutritAI

> AI-powered nutrition tracking app that identifies food from photos using on-device deep learning, calculates nutrition, and provides personalized dietary guidance.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)
![TensorFlow](https://img.shields.io/badge/TensorFlow-2.x-FF6F00?logo=tensorflow)
![License](https://img.shields.io/badge/License-MIT-green)

---

## ✨ Key Features

- **📸 AI Food Recognition** — Snap a photo, get instant food identification using on-device TFLite inference
- **🍛 Indian Food Specialist** — Dedicated classification head for 80 Indian dishes (biryani, butter chicken, gulab jamun, etc.)
- **🌍 Global Coverage** — 101 international dishes from the Food-101 dataset
- **📊 Smart Nutrition Tracking** — Auto-calculates calories, protein, carbs, fat & fiber
- **🎯 Personalized Goals** — TDEE-based targets using Mifflin-St Jeor equation
- **⭐ Meal Scoring** — Multi-factor 0-100 scoring with actionable suggestions
- **🔒 Privacy First** — All AI runs on-device. No food photos are uploaded to any server
- **📵 Works Offline** — Food recognition works without internet

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter Mobile App                     │
│                                                         │
│  📷 Camera ──→ 🧠 TFLite Model ──→ 🍽️ Nutrition Lookup │
│                                                         │
│  Providers: Auth │ Meal │ Profile                       │
└──────────────────────┬──────────────────────────────────┘
                       │ REST API + JWT
┌──────────────────────┴──────────────────────────────────┐
│                   FastAPI Backend                        │
│                                                         │
│  🔐 Auth  │  🗄️ Nutrition DB  │  📈 Scoring Engine     │
│  (JWT)    │  (200+ foods)     │  (0-100 scale)         │
│                                                         │
│                   SQLite Database                        │
└─────────────────────────────────────────────────────────┘
```

---

## 🧠 ML Model

### Multi-Head Classification

Two specialized heads sharing an **EfficientNet-B3** backbone:

| Head | Classes | Dataset | Accuracy |
|------|---------|---------|----------|
| Food-101 | 101 global dishes | 75K images | **76.88%** |
| Indian Food | 80 Indian dishes | 4K images | **70.63%** |

At inference time, both heads predict simultaneously — the one with higher confidence wins.

### Training Innovations

| Technique | Problem Solved |
|-----------|---------------|
| **Masked Loss (label -1)** | Prevents cross-head gradient corruption when only one head has valid labels |
| **Balanced Sampling (.repeat())** | Prevents dataset exhaustion — Food-101 (75K) vs Indian (4K) |
| **Two-Stage Training** | Stage 1: frozen backbone (5 epochs) → Stage 2: fine-tune top 30 layers (10 epochs) |
| **Data Augmentation** | Multiplies the small Indian dataset with flips, rotations, zoom, contrast |

### On-Device Inference

| Metric | Value |
|--------|-------|
| Model Format | TensorFlow Lite (float16) |
| Model Size | ~22 MB |
| Input | 300 × 300 × 3 (RGB) |
| Inference Time | 200-800ms (device dependent) |

---

## 📁 Project Structure

```
nutrit-ai/
├── frontend/                 # Flutter mobile app
│   ├── lib/
│   │   ├── models/           # Data models (User, Meal, FoodPrediction)
│   │   ├── providers/        # State management (Auth, Meal, Profile)
│   │   ├── services/         # API client + ML inference
│   │   └── screens/          # UI screens (Home, Food, Progress, Profile)
│   └── assets/
│       ├── multihead_food_float16.tflite
│       └── label_map.json
│
├── backend/                  # FastAPI REST API
│   └── app/
│       ├── main.py           # Entry point
│       ├── models.py         # SQLAlchemy ORM models
│       ├── schemas.py        # Pydantic validation
│       ├── auth.py           # JWT + bcrypt authentication
│       ├── nutrition_db.py   # 200+ food nutrition entries
│       ├── scoring.py        # Meal scoring engine
│       └── routers/          # API endpoint handlers
│
├── NutritionAI_v2.py         # Training script (source of truth)
├── NutritionAI_v2.ipynb      # Colab notebook (generated from .py)
└── PROJECT_TECHNICAL_OVERVIEW.md
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter** 3.x with Android SDK
- **Python** 3.10+
- **Android Emulator** or physical device (API 26+)

### 1. Backend Setup

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The API is now running at `http://localhost:8000`. Interactive docs at `/docs`.

### 2. Flutter App Setup

```bash
cd frontend
flutter pub get
flutter run
```

> **Note:** On Android emulator, the app connects to `10.0.2.2:8000` (maps to host's localhost).

### 3. Model Training (optional)

Upload `NutritionAI_v2.ipynb` to [Google Colab](https://colab.research.google.com) with a T4 GPU runtime and run all cells. Training takes ~6 hours total.

The trained model files (`multihead_food_float16.tflite` + `label_map.json`) go into `frontend/assets/`.

---

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login, get JWT token |
| GET | `/api/auth/me` | Current user info |
| GET | `/api/users/profile` | Get user profile |
| PUT | `/api/users/profile` | Update profile (age, weight, height, goals) |
| GET | `/api/users/targets` | Personalized nutrition targets (TDEE-based) |
| GET | `/api/users/weekly-progress` | 7-day progress summary |
| POST | `/api/meals/log` | Log a meal with food items |
| GET | `/api/meals/today` | Today's meals |
| GET | `/api/meals/daily-summary` | Today's calorie/macro totals |
| DELETE | `/api/meals/{id}` | Delete a meal |
| GET | `/api/nutrition/lookup/{food}` | Lookup food nutrition |
| GET | `/api/nutrition/search?q=` | Search foods |
| POST | `/api/nutrition/score` | Score a meal |

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile App** | Flutter 3, Dart |
| **State Management** | Provider (ChangeNotifier) |
| **ML Inference** | TensorFlow Lite (tflite_flutter) |
| **ML Training** | TensorFlow/Keras, EfficientNet-B3 |
| **Backend** | FastAPI, SQLAlchemy, Pydantic |
| **Database** | SQLite (dev) → PostgreSQL (prod) |
| **Auth** | JWT (PyJWT) + bcrypt |
| **Training Env** | Google Colab (T4 GPU) |

---

## 📈 Algorithms

| Algorithm | Purpose | Implementation |
|-----------|---------|---------------|
| **Mifflin-St Jeor** | BMR/TDEE calculation for personalized calorie targets | `user_router.py` |
| **Multi-Factor Scoring** | Rate meals 0-100 based on calories, macros, protein adequacy | `scoring.py` |
| **Masked Cross-Entropy** | Train multi-head model without cross-head gradient corruption | `NutritionAI_v2.py` |
| **Balanced Sampling** | Handle 25:1 dataset size imbalance between Food-101 and Indian | `NutritionAI_v2.py` |
| **Transfer Learning** | Leverage ImageNet-pretrained EfficientNet-B3 for food features | `NutritionAI_v2.py` |

---

## 🗺️ Roadmap

- [ ] Google Sign-In authentication
- [ ] Cloud deployment (Railway/Render)
- [ ] Fine-tune model to 80%+ accuracy
- [ ] Portion size estimation from images
- [ ] Barcode/QR scanning for packaged foods
- [ ] Meal planning & recipe suggestions
- [ ] Social features (share meals, challenges)

---

## 📄 License

This project is for educational and personal use.
