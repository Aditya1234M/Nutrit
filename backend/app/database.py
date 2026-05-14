"""Database setup — SQLAlchemy + SQLite."""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
import os

# SQLite database file lives next to the backend code
DB_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATABASE_URL = f"sqlite:///{os.path.join(DB_DIR, 'nutritai.db')}"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    """FastAPI dependency — yields a database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables():
    """Create all tables if they don't exist."""
    Base.metadata.create_all(bind=engine)
