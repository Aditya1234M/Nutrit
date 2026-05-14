"""Pydantic schemas for request/response validation."""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime, date


# ── Auth ────────────────────────────────────────────────
class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: str = Field(min_length=5, max_length=200)
    password: str = Field(min_length=6, max_length=100)


class UserLogin(BaseModel):
    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    name: str
    email: str


class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    subscription_tier: str
    created_at: datetime

    class Config:
        from_attributes = True


# ── Profile ─────────────────────────────────────────────
class ProfileUpdate(BaseModel):
    age: Optional[int] = Field(None, ge=13, le=120)
    weight: Optional[float] = Field(None, ge=20, le=300)
    height: Optional[float] = Field(None, ge=100, le=250)
    gender: Optional[str] = None
    activity_level: Optional[str] = None
    goal_type: Optional[str] = None


class ProfileResponse(BaseModel):
    age: Optional[int] = None
    weight: Optional[float] = None
    height: Optional[float] = None
    gender: Optional[str] = None
    activity_level: Optional[str] = None
    goal_type: Optional[str] = None

    class Config:
        from_attributes = True


class NutritionTargets(BaseModel):
    daily_calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float
    water_ml: float


# ── Meals ───────────────────────────────────────────────
class MealFoodCreate(BaseModel):
    food_name: str
    confidence: float = 1.0
    portion_grams: float = 100.0
    calories: float = 0
    protein: float = 0
    carbs: float = 0
    fat: float = 0
    fiber: float = 0


class MealCreate(BaseModel):
    meal_type: str = Field(pattern=r"^(breakfast|lunch|dinner|snack)$")
    foods: List[MealFoodCreate]
    notes: Optional[str] = None


class MealFoodResponse(BaseModel):
    id: str
    food_name: str
    confidence: float
    portion_grams: float
    calories: float
    protein: float
    carbs: float
    fat: float
    fiber: float

    class Config:
        from_attributes = True


class MealResponse(BaseModel):
    id: str
    meal_type: str
    timestamp: datetime
    notes: Optional[str]
    score: Optional[float]
    foods: List[MealFoodResponse]
    total_calories: float = 0
    total_protein: float = 0
    total_carbs: float = 0
    total_fat: float = 0

    class Config:
        from_attributes = True


# ── Daily Summary ───────────────────────────────────────
class DailySummary(BaseModel):
    date: date
    total_calories: float
    total_protein: float
    total_carbs: float
    total_fat: float
    water_ml: float
    meal_count: int
    calorie_goal: float
    calorie_progress: float  # 0-1


class WeeklyProgress(BaseModel):
    days: List[DailySummary]
    avg_calories: float
    avg_protein: float
    avg_carbs: float
    avg_fat: float
    streak: int


# ── Nutrition Lookup ────────────────────────────────────
class NutritionInfo(BaseModel):
    food_name: str
    calories_per_100g: float
    protein_per_100g: float
    carbs_per_100g: float
    fat_per_100g: float
    fiber_per_100g: float
    serving_size_g: float = 100.0


class MealScore(BaseModel):
    overall_score: float  # 0-100
    macro_balance: float
    calorie_appropriateness: float
    protein_adequacy: float
    explanation: List[str]
    suggestions: List[str]
