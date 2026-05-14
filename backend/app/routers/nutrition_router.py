"""Nutrition lookup & scoring endpoints."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import User, UserProfile
from ..schemas import NutritionInfo, MealScore, MealFoodCreate
from ..auth import get_current_user
from ..nutrition_db import lookup_food, get_all_food_names
from ..scoring import calculate_meal_score
from ..routers.user_router import _get_targets

router = APIRouter(prefix="/api/nutrition", tags=["nutrition"])


@router.get("/lookup/{food_name}", response_model=NutritionInfo)
def lookup_nutrition(food_name: str):
    """Lookup nutrition data for a food item."""
    result = lookup_food(food_name)
    if not result:
        raise HTTPException(
            status_code=404,
            detail=f"Nutrition data not found for '{food_name}'. Try a similar name.",
        )
    return NutritionInfo(**result)


@router.get("/search")
def search_foods(q: str = ""):
    """Search for food names matching a query."""
    all_foods = get_all_food_names()
    if not q:
        return {"foods": all_foods[:50]}

    query = q.lower()
    matches = [f for f in all_foods if query in f.lower()]
    return {"foods": matches[:20]}


@router.post("/score", response_model=MealScore)
def score_meal(
    foods: list[MealFoodCreate],
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Calculate a nutritional score for a list of foods."""
    total_cal = sum(f.calories for f in foods)
    total_pro = sum(f.protein for f in foods)
    total_carb = sum(f.carbs for f in foods)
    total_fat = sum(f.fat for f in foods)

    # Get personalized targets
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if profile:
        targets = _get_targets(profile)
        per_meal_cal = targets.daily_calories / 3
        per_meal_pro = targets.protein_g / 3
    else:
        per_meal_cal = 600
        per_meal_pro = 25

    result = calculate_meal_score(
        total_cal, total_pro, total_carb, total_fat,
        target_calories=per_meal_cal,
        target_protein=per_meal_pro,
    )

    return MealScore(**result)
