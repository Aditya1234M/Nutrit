"""User profile & progress endpoints."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import date, timedelta, datetime, timezone

from ..database import get_db
from ..models import User, UserProfile, DailyLog
from ..schemas import ProfileUpdate, ProfileResponse, NutritionTargets, DailySummary, WeeklyProgress
from ..auth import get_current_user

router = APIRouter(prefix="/api/users", tags=["users"])


def _calculate_bmr(profile: UserProfile) -> float:
    """Mifflin-St Jeor equation for BMR."""
    if not all([profile.weight, profile.height, profile.age]):
        return 2000  # Fallback default

    if profile.gender == "male":
        bmr = 10 * profile.weight + 6.25 * profile.height - 5 * profile.age + 5
    else:
        bmr = 10 * profile.weight + 6.25 * profile.height - 5 * profile.age - 161

    return bmr


def _calculate_tdee(bmr: float, activity_level: str) -> float:
    """Total Daily Energy Expenditure = BMR × activity multiplier."""
    multipliers = {
        "sedentary": 1.2,
        "light": 1.375,
        "moderate": 1.55,
        "very": 1.725,
        "extra": 1.9,
    }
    return bmr * multipliers.get(activity_level, 1.55)


def _get_targets(profile: UserProfile) -> NutritionTargets:
    """Calculate personalized daily nutrition targets."""
    bmr = _calculate_bmr(profile)
    tdee = _calculate_tdee(bmr, profile.activity_level or "moderate")

    # Adjust for goal
    if profile.goal_type == "lose":
        daily_cal = tdee - 500  # ~0.5 kg/week deficit
    elif profile.goal_type == "gain":
        daily_cal = tdee + 400
    else:
        daily_cal = tdee

    daily_cal = max(daily_cal, 1200)  # Safety floor

    # Macro split: 30% protein, 45% carbs, 25% fat
    protein_cal = daily_cal * 0.30
    carbs_cal = daily_cal * 0.45
    fat_cal = daily_cal * 0.25

    return NutritionTargets(
        daily_calories=round(daily_cal),
        protein_g=round(protein_cal / 4, 1),    # 4 cal/g
        carbs_g=round(carbs_cal / 4, 1),         # 4 cal/g
        fat_g=round(fat_cal / 9, 1),             # 9 cal/g
        fiber_g=30.0,
        water_ml=2500.0,
    )


@router.get("/profile", response_model=ProfileResponse)
def get_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile


@router.put("/profile", response_model=ProfileResponse)
def update_profile(
    data: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        profile = UserProfile(user_id=current_user.id)
        db.add(profile)

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(profile, field, value)

    profile.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(profile)
    return profile


@router.get("/targets", response_model=NutritionTargets)
def get_nutrition_targets(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        return NutritionTargets(
            daily_calories=2000, protein_g=75, carbs_g=250,
            fat_g=65, fiber_g=30, water_ml=2500,
        )
    return _get_targets(profile)


@router.get("/daily-summary/{target_date}", response_model=DailySummary)
def get_daily_summary(
    target_date: date,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    log = (
        db.query(DailyLog)
        .filter(DailyLog.user_id == current_user.id, DailyLog.date == target_date)
        .first()
    )

    # Get targets for progress calculation
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    targets = _get_targets(profile) if profile else NutritionTargets(
        daily_calories=2000, protein_g=75, carbs_g=250,
        fat_g=65, fiber_g=30, water_ml=2500,
    )

    if log:
        progress = min(log.total_calories / targets.daily_calories, 1.0) if targets.daily_calories > 0 else 0
        return DailySummary(
            date=target_date,
            total_calories=log.total_calories,
            total_protein=log.total_protein,
            total_carbs=log.total_carbs,
            total_fat=log.total_fat,
            water_ml=log.water_ml,
            meal_count=log.meal_count,
            calorie_goal=targets.daily_calories,
            calorie_progress=round(progress, 2),
        )

    # No data for this date
    return DailySummary(
        date=target_date,
        total_calories=0, total_protein=0, total_carbs=0, total_fat=0,
        water_ml=0, meal_count=0,
        calorie_goal=targets.daily_calories, calorie_progress=0,
    )


@router.get("/progress", response_model=WeeklyProgress)
def get_weekly_progress(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    week_start = today - timedelta(days=6)

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    targets = _get_targets(profile) if profile else NutritionTargets(
        daily_calories=2000, protein_g=75, carbs_g=250,
        fat_g=65, fiber_g=30, water_ml=2500,
    )

    logs = (
        db.query(DailyLog)
        .filter(
            DailyLog.user_id == current_user.id,
            DailyLog.date >= week_start,
            DailyLog.date <= today,
        )
        .all()
    )

    log_map = {log.date: log for log in logs}

    days = []
    for i in range(7):
        d = week_start + timedelta(days=i)
        log = log_map.get(d)
        if log:
            progress = min(log.total_calories / targets.daily_calories, 1.0) if targets.daily_calories > 0 else 0
            days.append(DailySummary(
                date=d,
                total_calories=log.total_calories,
                total_protein=log.total_protein,
                total_carbs=log.total_carbs,
                total_fat=log.total_fat,
                water_ml=log.water_ml,
                meal_count=log.meal_count,
                calorie_goal=targets.daily_calories,
                calorie_progress=round(progress, 2),
            ))
        else:
            days.append(DailySummary(
                date=d,
                total_calories=0, total_protein=0, total_carbs=0, total_fat=0,
                water_ml=0, meal_count=0,
                calorie_goal=targets.daily_calories, calorie_progress=0,
            ))

    # Calculate streak — consecutive days with at least 1 meal logged
    streak = 0
    for i in range(6, -1, -1):
        if days[i].meal_count > 0:
            streak += 1
        else:
            break

    active_days = [d for d in days if d.meal_count > 0]
    n = max(len(active_days), 1)

    return WeeklyProgress(
        days=days,
        avg_calories=round(sum(d.total_calories for d in active_days) / n, 1),
        avg_protein=round(sum(d.total_protein for d in active_days) / n, 1),
        avg_carbs=round(sum(d.total_carbs for d in active_days) / n, 1),
        avg_fat=round(sum(d.total_fat for d in active_days) / n, 1),
        streak=streak,
    )
