import os
from dotenv import load_dotenv

# Load environmental variables from .env file if available
load_dotenv()

class Config:
    # ==================== GENERAL CONFIG ====================
    APP_NAME = "MobiTrail FaceReco Backend"
    VERSION = "1.0.0"
    SECRET_KEY = os.environ.get("SECRET_KEY", "mobitrail-super-secret-key-change-in-production-2026")
    
    # ==================== DATABASE CONFIG ====================
    DB_HOST = os.environ.get("DB_HOST", "localhost")
    DB_PORT = int(os.environ.get("DB_PORT", 3306))
    DB_USER = os.environ.get("DB_USER", "root")
    DB_PASSWORD = os.environ.get("DB_PASSWORD", "root") # Fallback to default user database credentials
    DB_NAME = os.environ.get("DB_NAME", "mobitrail_db")

    # ==================== GEOFENCING CONFIG ====================
    # Geographic location of the office coordinates provided by the user
    OFFICE_LATITUDE = float(os.environ.get("OFFICE_LATITUDE", 19.1748076))
    OFFICE_LONGITUDE = float(os.environ.get("OFFICE_LONGITUDE", 72.8576635))
    GEOFENCE_RADIUS_METERS = float(os.environ.get("GEOFENCE_RADIUS_METERS", 9999999.0))

    # ==================== FACE RECOGNITION CONFIG ====================
    # ArcFace cosine similarity thresholds (mapped as: similarity = (1 - cosine_distance) * 100)
    VERIFICATION_THRESHOLD = float(os.environ.get("VERIFICATION_THRESHOLD", 80.0)) # 80% similarity
    ADAPTATION_THRESHOLD = float(os.environ.get("ADAPTATION_THRESHOLD", 92.0))     # 92% similarity for auto-template update

    # ==================== SECURITY & AUTH CONFIG ====================
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "mobitrail-jwt-secret-key-2026")
    JWT_ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 # 24 hours

    # ==================== FILE UPLOAD DIRECTORIES ====================
    BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
    ENROLLMENT_FOLDER = os.path.join(UPLOAD_FOLDER, "enrollments")
    VERIFICATION_FOLDER = os.path.join(UPLOAD_FOLDER, "verifications")
