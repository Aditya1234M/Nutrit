"""Nutritional scoring engine — rates meals from 0 to 100."""


def calculate_meal_score(
    total_calories: float,
    total_protein: float,
    total_carbs: float,
    total_fat: float,
    target_calories: float = 600,  # per-meal target (daily / 3)
    target_protein: float = 25,
    target_carbs: float = 75,
    target_fat: float = 20,
) -> dict:
    """Score a meal based on nutritional balance and targets.

    Returns a dict with overall_score (0-100), component scores, and text feedback.
    """

    explanations = []
    suggestions = []

    # ── 1. Calorie Appropriateness (0-30 points) ───────
    if target_calories > 0:
        cal_ratio = total_calories / target_calories
        if 0.8 <= cal_ratio <= 1.2:
            cal_score = 30
            explanations.append("Calorie intake is well-balanced for this meal")
        elif 0.6 <= cal_ratio < 0.8 or 1.2 < cal_ratio <= 1.4:
            cal_score = 20
            if cal_ratio < 1:
                explanations.append("Slightly under your calorie target")
                suggestions.append("Consider adding a small side dish")
            else:
                explanations.append("Slightly over your calorie target")
                suggestions.append("Consider reducing portion size next time")
        elif cal_ratio < 0.6:
            cal_score = 10
            explanations.append("Meal is significantly under calorie target")
            suggestions.append("This meal is too light — add more nutrient-dense foods")
        else:
            cal_score = 5
            explanations.append("Meal significantly exceeds calorie target")
            suggestions.append("Try splitting this into two smaller meals")
    else:
        cal_score = 15

    # ── 2. Macro Balance (0-40 points) ─────────────────
    total_macros = total_protein + total_carbs + total_fat
    if total_macros > 0:
        protein_pct = total_protein / total_macros
        carbs_pct = total_carbs / total_macros
        fat_pct = total_fat / total_macros

        # Ideal: ~25% protein, ~50% carbs, ~25% fat (by weight)
        balance_score = 0

        # Protein evaluation (target 20-35%)
        if 0.18 <= protein_pct <= 0.38:
            balance_score += 15
            explanations.append("Good protein content")
        elif protein_pct < 0.18:
            balance_score += 5
            suggestions.append("Add more protein (eggs, chicken, paneer, dal)")
        else:
            balance_score += 8

        # Carbs evaluation (target 40-60%)
        if 0.35 <= carbs_pct <= 0.65:
            balance_score += 15
            explanations.append("Carbohydrate balance is good")
        elif carbs_pct > 0.65:
            balance_score += 5
            suggestions.append("Too many carbs — balance with protein and vegetables")
        else:
            balance_score += 8

        # Fat evaluation (target 15-30%)
        if 0.12 <= fat_pct <= 0.33:
            balance_score += 10
        elif fat_pct > 0.33:
            balance_score += 3
            suggestions.append("High fat content — try grilled instead of fried")
        else:
            balance_score += 7
    else:
        balance_score = 10

    # ── 3. Protein Adequacy (0-30 points) ──────────────
    if target_protein > 0:
        protein_ratio = total_protein / target_protein
        if protein_ratio >= 0.9:
            protein_score = 30
            explanations.append("Excellent protein intake")
        elif protein_ratio >= 0.7:
            protein_score = 22
            explanations.append("Adequate protein intake")
        elif protein_ratio >= 0.5:
            protein_score = 14
            suggestions.append("Try to include more protein-rich foods")
        else:
            protein_score = 6
            suggestions.append("Protein is very low — add chicken, paneer, dal, or eggs")
    else:
        protein_score = 15

    overall = cal_score + balance_score + protein_score

    # Ensure we always have some feedback
    if not explanations:
        explanations.append("Meal logged successfully")
    if not suggestions and overall < 70:
        suggestions.append("Aim for balanced meals with protein, carbs, and healthy fats")

    return {
        "overall_score": round(min(overall, 100), 1),
        "macro_balance": round(balance_score / 40 * 100, 1),
        "calorie_appropriateness": round(cal_score / 30 * 100, 1),
        "protein_adequacy": round(protein_score / 30 * 100, 1),
        "explanation": explanations,
        "suggestions": suggestions,
    }
