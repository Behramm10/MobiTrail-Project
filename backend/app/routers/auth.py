import os
from datetime import datetime, timedelta
from typing import Optional
import json
import logging

from fastapi import APIRouter, UploadFile, File, Form, HTTPException, status, Depends
from jose import jwt, JWTError
from pydantic import BaseModel, EmailStr

from app.database.config import Config
from app.database.connection import DatabaseConnector
from app.utils.face_engine import FaceEngine
from app.utils.geofence import verify_geofence
from app.utils.storage import StorageManager

logger = logging.getLogger(__name__)

# Create FastAPI Router
router = APIRouter(prefix="/api", tags=["Authentication & Enrollment"])

# ==================== PYDANTIC DATA SCHEMAS ====================

class LoginRequest(BaseModel):
    name: str
    employeeId: str

class VerificationResponse(BaseModel):
    success: bool
    confidence: float
    message: str
    timestamp: str

# ==================== JWT SECURITY HELPERS ====================

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Generate a JWT token containing admin/session info"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=Config.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, Config.JWT_SECRET_KEY, algorithm=Config.JWT_ALGORITHM)
    return encoded_jwt

# ==================== REST ENDPOINTS ====================

@router.post("/auth/login")
async def login(payload: LoginRequest):
    """
    Authenticate an employee.
    If the employee does not exist in the database, automatically insert them 
    as a new inactive record waiting for face enrollment.
    """
    try:
        employee_id = payload.employeeId.strip()
        name = payload.name.strip().upper()  # Convert user names to capital by default
        
        # Initialize default values to avoid NameError on new user registration
        is_enrolled = False
        has_timed_in = False
        has_timed_out = False
        time_in_status = None
        time_out_status = None
        time_in_time_str = None
        time_out_time_str = None
        
        # 1. Check if employee exists
        query = "SELECT name, face_embedding FROM employees WHERE employee_id = %s"
        record = DatabaseConnector.execute_query(query, (employee_id,), fetch_one=True)
        
        if not record:
            # 2. Automatically register the employee profile if not found
            # Generates a placeholder email to keep DB integrity
            placeholder_email = f"{employee_id.lower()}@mobitrail.company"
            insert_query = """
                INSERT INTO employees (employee_id, name, email, face_embedding, enrollment_image_path)
                VALUES (%s, %s, %s, NULL, NULL)
            """
            DatabaseConnector.execute_query(insert_query, (employee_id, name, placeholder_email))
            
            logger.info(f"Auto-registered new employee: {name} (ID: {employee_id})")
        else:
            # Check if name matches (both name and ID must match for a login)
            stored_name = record["name"].upper()
            if name != stored_name:
                logger.warning(f"Login failed: Name mismatch for ID {employee_id}. Entered: {name}, Stored: {stored_name}")
                return {
                    "success": False,
                    "message": "Authentication failed: Entered name does not match record in database."
                }

            # Check if they have a face template enrolled
            is_enrolled = record["face_embedding"] is not None
            logger.info(f"Login success: {name} (ID: {employee_id}). Enrolled status: {is_enrolled}")
            
            # Check if attendance is already marked for today (prioritize approved/pending check-in)
            attendance_query = """
                SELECT time_in_time, time_in_status, time_out_time, time_out_status FROM attendance 
                WHERE employee_id = %s AND DATE(time_in_time) = CURDATE()
                ORDER BY CASE WHEN time_in_status IN ('APPROVED', 'WAITING_FOR_APPROVAL') THEN 0 ELSE 1 END, id DESC
                LIMIT 1
            """
            attendance_record = DatabaseConnector.execute_query(attendance_query, (employee_id,), fetch_one=True)
            if attendance_record:
                time_in_status = attendance_record["time_in_status"]
                time_out_status = attendance_record["time_out_status"]
                if attendance_record["time_in_time"]:
                    time_in_time_str = attendance_record["time_in_time"].strftime('%I:%M %p')
                if attendance_record["time_out_time"]:
                    time_out_time_str = attendance_record["time_out_time"].strftime('%I:%M %p')
                
                if time_in_status in ("APPROVED", "WAITING_FOR_APPROVAL"):
                    has_timed_in = True
                if time_out_status in ("APPROVED", "WAITING_FOR_APPROVAL"):
                    has_timed_out = True

        # 3. Return payload structure expected by Flutter EmployeeProvider
        return {
            "success": True,
            "employee": {
                "name": name,
                "employeeId": employee_id,
                "isEnrolled": is_enrolled,
                "hasTimedIn": has_timed_in,
                "hasTimedOut": has_timed_out,
                "timeInStatus": time_in_status,
                "timeOutStatus": time_out_status,
                "timeInTime": time_in_time_str,
                "timeOutTime": time_out_time_str
            }
        }
    except Exception as e:
        logger.error(f"Error in employee login route: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal login error: {str(e)}"
        )

@router.post("/enrollment/enroll")
async def enroll(
    employeeId: str = Form(...),
    email: Optional[str] = Form(None),
    image: UploadFile = File(...)
):
    """
    Accepts employeeId, email (optional), and face image file.
    Extracts facial embeddings and saves the photo on the server.
    """
    try:
        employee_id = employeeId.strip()
        
        # 1. Verify employee exists in database
        check_query = "SELECT name, email FROM employees WHERE employee_id = %s"
        employee = DatabaseConnector.execute_query(check_query, (employee_id,), fetch_one=True)
        
        if not employee:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Employee profile must be initialized by logging in first."
            )
            
        # 2. Save the uploaded face image to uploads/enrollments/
        file_path = await StorageManager.save_enrollment_image(employee_id, image)
        absolute_file_path = os.path.join(Config.BASE_DIR, file_path)
        
        # 3. Process image to extract ArcFace embedding vector
        embedding = FaceEngine.extract_embedding(absolute_file_path)
        if not embedding:
            # Clean up the file if face detection fails to avoid garbage files
            if os.path.exists(absolute_file_path):
                os.remove(absolute_file_path)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No face detected in the image. Please take another photo with better lighting."
            )
            
        # 4. Serialize embedding list to JSON and save to database
        embedding_json = json.dumps(embedding)
        update_query = """
            UPDATE employees 
            SET face_embedding = %s, enrollment_image_path = %s
            WHERE employee_id = %s
        """
        DatabaseConnector.execute_query(update_query, (embedding_json, file_path, employee_id))
        
        logger.info(f"✓ Face enrolled successfully for Employee ID: {employee_id}")
        
        return {
            "success": True,
            "message": "Face enrolled successfully",
            "embeddingId": f"emb_{employee_id.lower()}"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in enrollment route: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Enrollment failed: {str(e)}"
        )

@router.post("/attendance/time-in", response_model=VerificationResponse)
async def time_in(
    employeeId: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    image: UploadFile = File(...)
):
    """
    Time In clock-in verification endpoint:
    1. Geofence checks GPS coordinates.
    2. Face Engine runs ArcFace 1-to-1 matching.
    3. Handles check-in logging and Adaptive Template Updates.
    """
    try:
        employee_id = employeeId.strip()
        
        # --- STEP 1: GEOFENCE GPS CHECK ---
        is_within_range, distance = verify_geofence(latitude, longitude)
        if not is_within_range:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Verification failed: You are out of range ({distance:.1f}m away from the office geofence)."
            )
            
        # --- STEP 2: DATABASE RETRIEVAL ---
        query = "SELECT face_embedding, is_active FROM employees WHERE employee_id = %s"
        employee = DatabaseConnector.execute_query(query, (employee_id,), fetch_one=True)
        
        if not employee or not employee["is_active"]:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Employee profile is inactive or not found."
            )
            
        if not employee["face_embedding"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No face template enrolled for this employee. Please enroll face first."
            )
            
        # --- CHECK IF ALREADY TIMED IN ---
        check_attendance_query = """
            SELECT id FROM attendance 
            WHERE employee_id = %s AND DATE(time_in_time) = CURDATE()
            AND time_in_status IN ('APPROVED', 'WAITING_FOR_APPROVAL')
        """
        existing_attendance = DatabaseConnector.execute_query(check_attendance_query, (employee_id,), fetch_one=True)
        if existing_attendance:
             raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You have already timed in today."
            )

        stored_embedding = json.loads(employee["face_embedding"])
        
        # --- STEP 3: SAVE TEMPORARY VERIFICATION PHOTO ---
        file_path = await StorageManager.save_verification_image(employee_id, image)
        absolute_file_path = os.path.join(Config.BASE_DIR, file_path)
        
        # --- STEP 4: ARCFACE FACE MATCHING ---
        is_matched, similarity, message = FaceEngine.verify_face(absolute_file_path, stored_embedding)
        
        timestamp_str = DateTime_to_ISO()
        
        # --- STEP 5: ATTENDANCE LOGGING & ADAPTIVE UPDATES ---
        if is_matched:
            attendance_status = "APPROVED"
            msg = "Time In successful. Face verified."
            
            if similarity >= Config.ADAPTATION_THRESHOLD:
                new_embedding = FaceEngine.extract_embedding(absolute_file_path)
                if new_embedding:
                    update_query = "UPDATE employees SET face_embedding = %s WHERE employee_id = %s"
                    DatabaseConnector.execute_query(update_query, (json.dumps(new_embedding), employee_id))
                    logger.info(f"🔄 Adaptive Template Update triggered for user {employee_id} (Score: {similarity:.1f}%)")
        else:
            if similarity >= 60.0:
                attendance_status = "WAITING_FOR_APPROVAL"
                msg = "Face verification borderline. Time In logged for manual review."
            else:
                attendance_status = "REJECTED"
                msg = "Face verification failed. Embedding mismatch."
                
        # Write attendance log in MySQL
        log_query = """
            INSERT INTO attendance (
                employee_id, time_in_time, time_in_status, time_in_image_path, 
                time_in_similarity_score, time_in_latitude, time_in_longitude, time_in_distance_meters
            ) VALUES (%s, NOW(), %s, %s, %s, %s, %s, %s)
        """
        DatabaseConnector.execute_query(
            log_query, 
            (employee_id, attendance_status, file_path, similarity, latitude, longitude, distance)
        )
        
        # Select the today's attendance record to return the exact times from the database
        time_query = """
            SELECT time_in_time, time_out_time FROM attendance 
            WHERE employee_id = %s AND DATE(time_in_time) = CURDATE()
            ORDER BY id DESC LIMIT 1
        """
        times = DatabaseConnector.execute_query(time_query, (employee_id,), fetch_one=True)
        time_in_time_str = None
        time_out_time_str = None
        if times:
            if times["time_in_time"]:
                time_in_time_str = times["time_in_time"].strftime('%I:%M %p')
            if times["time_out_time"]:
                time_out_time_str = times["time_out_time"].strftime('%I:%M %p')
                
        return VerificationResponse(
            success=attendance_status in ("APPROVED", "WAITING_FOR_APPROVAL"),
            confidence=similarity / 100.0,
            message=msg,
            timestamp=timestamp_str
        ).model_dump() | {
            "attendance_status": attendance_status,
            "time_in_time": time_in_time_str,
            "time_out_time": time_out_time_str
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in time-in route: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Time In failed: {str(e)}"
        )

@router.post("/attendance/time-out", response_model=VerificationResponse)
async def time_out(
    employeeId: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    image: UploadFile = File(...)
):
    """
    Time Out verification endpoint:
    1. Checks if timed in.
    2. Geofence checks GPS coordinates.
    3. Face Engine runs ArcFace 1-to-1 matching.
    4. Updates check-out logging.
    """
    try:
        employee_id = employeeId.strip()
        
        # --- CHECK IF TIMED IN ---
        check_attendance_query = """
            SELECT id, time_out_status FROM attendance 
            WHERE employee_id = %s AND DATE(time_in_time) = CURDATE()
            AND time_in_status IN ('APPROVED', 'WAITING_FOR_APPROVAL')
        """
        existing_attendance = DatabaseConnector.execute_query(check_attendance_query, (employee_id,), fetch_one=True)
        
        if not existing_attendance:
             raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You have not timed in today."
            )
            
        if existing_attendance["time_out_status"] in ("APPROVED", "WAITING_FOR_APPROVAL"):
             raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You have already timed out today."
            )
            
        # --- STEP 1: GEOFENCE GPS CHECK ---
        is_within_range, distance = verify_geofence(latitude, longitude)
        if not is_within_range:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Verification failed: You are out of range ({distance:.1f}m away from the office geofence)."
            )
            
        # --- STEP 2: DATABASE RETRIEVAL ---
        query = "SELECT face_embedding, is_active FROM employees WHERE employee_id = %s"
        employee = DatabaseConnector.execute_query(query, (employee_id,), fetch_one=True)
        
        if not employee or not employee["is_active"]:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Employee profile is inactive or not found."
            )
            
        if not employee["face_embedding"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No face template enrolled for this employee."
            )
            
        stored_embedding = json.loads(employee["face_embedding"])
        
        # --- STEP 3: SAVE TEMPORARY VERIFICATION PHOTO ---
        file_path = await StorageManager.save_verification_image(employee_id, image)
        absolute_file_path = os.path.join(Config.BASE_DIR, file_path)
        
        # --- STEP 4: ARCFACE FACE MATCHING ---
        is_matched, similarity, message = FaceEngine.verify_face(absolute_file_path, stored_embedding)
        
        timestamp_str = DateTime_to_ISO()
        
        if is_matched:
            attendance_status = "APPROVED"
            msg = "Time Out successful. Face verified."
            
            if similarity >= Config.ADAPTATION_THRESHOLD:
                new_embedding = FaceEngine.extract_embedding(absolute_file_path)
                if new_embedding:
                    update_query = "UPDATE employees SET face_embedding = %s WHERE employee_id = %s"
                    DatabaseConnector.execute_query(update_query, (json.dumps(new_embedding), employee_id))
        else:
            if similarity >= 60.0:
                attendance_status = "WAITING_FOR_APPROVAL"
                msg = "Face verification borderline. Time Out logged for manual review."
            else:
                attendance_status = "REJECTED"
                msg = "Face verification failed. Embedding mismatch."
                
        # Write attendance log in MySQL
        log_query = """
            UPDATE attendance 
            SET time_out_time = NOW(), time_out_status = %s, time_out_image_path = %s, 
                time_out_similarity_score = %s, time_out_latitude = %s, time_out_longitude = %s,
                time_out_distance_meters = %s
            WHERE id = %s
        """
        DatabaseConnector.execute_query(
            log_query, 
            (attendance_status, file_path, similarity, latitude, longitude, distance, existing_attendance["id"])
        )
        
        # Select the today's attendance record to return the exact times from the database
        time_query = """
            SELECT time_in_time, time_out_time FROM attendance 
            WHERE employee_id = %s AND DATE(time_in_time) = CURDATE()
            ORDER BY id DESC LIMIT 1
        """
        times = DatabaseConnector.execute_query(time_query, (employee_id,), fetch_one=True)
        time_in_time_str = None
        time_out_time_str = None
        if times:
            if times["time_in_time"]:
                time_in_time_str = times["time_in_time"].strftime('%I:%M %p')
            if times["time_out_time"]:
                time_out_time_str = times["time_out_time"].strftime('%I:%M %p')
                
        return VerificationResponse(
            success=attendance_status in ("APPROVED", "WAITING_FOR_APPROVAL"),
            confidence=similarity / 100.0,
            message=msg,
            timestamp=timestamp_str
        ).model_dump() | {
            "attendance_status": attendance_status,
            "time_in_time": time_in_time_str,
            "time_out_time": time_out_time_str
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in time-out route: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Time Out failed: {str(e)}"
        )

def DateTime_to_ISO() -> str:
    """Helper to get current time in ISO format"""
    return datetime.utcnow().isoformat() + "Z"
