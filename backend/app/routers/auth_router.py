"""Authentication endpoints — register, login, current user."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import User, UserProfile
from ..schemas import UserCreate, UserLogin, TokenResponse, UserResponse
from ..auth import hash_password, verify_password, create_access_token, get_current_user

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse)
def register(data: UserCreate, db: Session = Depends(get_db)):
    # Check if email already exists
    existing = db.query(User).filter(User.email == data.email.lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    # Create user
    user = User(
        email=data.email.lower(),
        password_hash=hash_password(data.password),
        name=data.name,
    )
    db.add(user)
    db.flush()

    # Create empty profile
    profile = UserProfile(user_id=user.id)
    db.add(profile)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id, user.email)

    return TokenResponse(
        access_token=token,
        user_id=user.id,
        name=user.name,
        email=user.email,
    )


@router.post("/login", response_model=TokenResponse)
def login(data: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email.lower()).first()

    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    token = create_access_token(user.id, user.email)

    return TokenResponse(
        access_token=token,
        user_id=user.id,
        name=user.name,
        email=user.email,
    )


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user
