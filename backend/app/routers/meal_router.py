"""Meal logging endpoints — create, list, delete meals."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import date, datetime, timezone, timedelta

from ..database import get_db
from ..models import User, Meal, MealFood, DailyLog, UserProfile
from ..schemas import MealCreate, MealResponse, MealFoodResponse
from ..auth import get_current_user
from ..scoring import calculate_meal_score
from ..routers.user_router import _get_targets

router = APIRouter(prefix="/api/meals", tags=["meals"])


def _update_daily_log(db: Session, user_id: str, target_date: date):
    """Recalculate the daily log from all meals on that date."""
    meals = (
        db.query(Meal)
        .filter(
            Meal.user_id == user_id,
            Meal.timestamp >= datetime.combine(target_date, datetime.min.time()),
            Meal.timestamp < datetime.combine(
                target_date + timedelta(days=1),
                datetime.min.time(),
            ),
        )
        .all()
    )

    total_cal = total_pro = total_carb = total_fat = 0
    for meal in meals:
        for food in meal.foods:
            total_cal += food.calories
            total_pro += food.protein
            total_carb += food.carbs
            total_fat += food.fat

    log = (
        db.query(DailyLog)
        .filter(DailyLog.user_id == user_id, DailyLog.date == target_date)
        .first()
    )

    if not log:
        log = DailyLog(user_id=user_id, date=target_date)
        db.add(log)

    log.total_calories = round(total_cal, 1)
    log.total_protein = round(total_pro, 1)
    log.total_carbs = round(total_carb, 1)
    log.total_fat = round(total_fat, 1)
    log.meal_count = len(meals)

    db.commit()


def _meal_to_response(meal: Meal) -> MealResponse:
    total_cal = sum(f.calories for f in meal.foods)
    total_pro = sum(f.protein for f in meal.foods)
    total_carb = sum(f.carbs for f in meal.foods)
    total_fat = sum(f.fat for f in meal.foods)

    return MealResponse(
        id=meal.id,
        meal_type=meal.meal_type,
        timestamp=meal.timestamp,
        notes=meal.notes,
        score=meal.score,
        foods=[MealFoodResponse.model_validate(f) for f in meal.foods],
        total_calories=round(total_cal, 1),
        total_protein=round(total_pro, 1),
        total_carbs=round(total_carb, 1),
        total_fat=round(total_fat, 1),
    )


@router.post("/log", response_model=MealResponse)
def log_meal(
    data: MealCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meal = Meal(
        user_id=current_user.id,
        meal_type=data.meal_type,
        notes=data.notes,
    )
    db.add(meal)
    db.flush()

    for food_data in data.foods:
        food = MealFood(
            meal_id=meal.id,
            food_name=food_data.food_name,
            confidence=food_data.confidence,
            portion_grams=food_data.portion_grams,
            calories=food_data.calories,
            protein=food_data.protein,
            carbs=food_data.carbs,
            fat=food_data.fat,
            fiber=food_data.fiber,
        )
        db.add(food)

    # Calculate and store meal score
    total_cal = sum(f.calories for f in data.foods)
    total_pro = sum(f.protein for f in data.foods)
    total_carb = sum(f.carbs for f in data.foods)
    total_fat = sum(f.fat for f in data.foods)

    # Get user targets for scoring
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if profile:
        targets = _get_targets(profile)
        per_meal_cal = targets.daily_calories / 3
        per_meal_pro = targets.protein_g / 3
    else:
        per_meal_cal = 600
        per_meal_pro = 25

    score_result = calculate_meal_score(
        total_cal, total_pro, total_carb, total_fat,
        target_calories=per_meal_cal,
        target_protein=per_meal_pro,
    )
    meal.score = score_result["overall_score"]

    db.commit()
    db.refresh(meal)

    # Update daily log
    _update_daily_log(db, current_user.id, meal.timestamp.date())

    return _meal_to_response(meal)


@router.get("/today", response_model=list[MealResponse])
def get_today_meals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    meals = (
        db.query(Meal)
        .filter(
            Meal.user_id == current_user.id,
            Meal.timestamp >= datetime.combine(today, datetime.min.time()),
        )
        .order_by(Meal.timestamp.desc())
        .all()
    )
    return [_meal_to_response(m) for m in meals]


@router.get("/history", response_model=list[MealResponse])
def get_meal_history(
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meals = (
        db.query(Meal)
        .filter(Meal.user_id == current_user.id)
        .order_by(Meal.timestamp.desc())
        .limit(limit)
        .all()
    )
    return [_meal_to_response(m) for m in meals]


@router.delete("/{meal_id}")
def delete_meal(
    meal_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meal = (
        db.query(Meal)
        .filter(Meal.id == meal_id, Meal.user_id == current_user.id)
        .first()
    )
    if not meal:
        raise HTTPException(status_code=404, detail="Meal not found")

    meal_date = meal.timestamp.date()
    db.delete(meal)
    db.commit()

    # Recalculate daily log
    _update_daily_log(db, current_user.id, meal_date)

    return {"detail": "Meal deleted"}
