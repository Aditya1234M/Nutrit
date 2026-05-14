"""SQLAlchemy ORM models."""

from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, ForeignKey, Date, Text
)
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
import uuid

from .database import Base


def _uuid():
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=_uuid)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    name = Column(String, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    subscription_tier = Column(String, default="free")  # free | premium

    profile = relationship("UserProfile", back_populates="user", uselist=False)
    meals = relationship("Meal", back_populates="user")
    daily_logs = relationship("DailyLog", back_populates="user")


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = Column(String, primary_key=True, default=_uuid)
    user_id = Column(String, ForeignKey("users.id"), unique=True, nullable=False)
    age = Column(Integer)
    weight = Column(Float)       # kg
    height = Column(Float)       # cm
    gender = Column(String)      # male | female
    activity_level = Column(String, default="moderate")  # sedentary|light|moderate|very|extra
    goal_type = Column(String, default="maintain")       # lose | maintain | gain
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="profile")


class Meal(Base):
    __tablename__ = "meals"

    id = Column(String, primary_key=True, default=_uuid)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    meal_type = Column(String, nullable=False)  # breakfast | lunch | dinner | snack
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    notes = Column(Text, nullable=True)
    score = Column(Float, nullable=True)

    user = relationship("User", back_populates="meals")
    foods = relationship("MealFood", back_populates="meal", cascade="all, delete-orphan")


class MealFood(Base):
    __tablename__ = "meal_foods"

    id = Column(String, primary_key=True, default=_uuid)
    meal_id = Column(String, ForeignKey("meals.id"), nullable=False)
    food_name = Column(String, nullable=False)
    confidence = Column(Float, default=1.0)  # AI confidence 0-1
    portion_grams = Column(Float, default=100.0)
    calories = Column(Float, default=0)
    protein = Column(Float, default=0)
    carbs = Column(Float, default=0)
    fat = Column(Float, default=0)
    fiber = Column(Float, default=0)

    meal = relationship("Meal", back_populates="foods")


class DailyLog(Base):
    __tablename__ = "daily_logs"

    id = Column(String, primary_key=True, default=_uuid)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    date = Column(Date, nullable=False)
    total_calories = Column(Float, default=0)
    total_protein = Column(Float, default=0)
    total_carbs = Column(Float, default=0)
    total_fat = Column(Float, default=0)
    water_ml = Column(Float, default=0)
    meal_count = Column(Integer, default=0)

    user = relationship("User", back_populates="daily_logs")
