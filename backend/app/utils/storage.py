import os
import shutil
from datetime import datetime
from fastapi import UploadFile
from app.database.config import Config
import logging

logger = logging.getLogger(__name__)

class StorageManager:
    @staticmethod
    def ensure_directories():
        """Ensure all upload directories exist"""
        os.makedirs(Config.UPLOAD_FOLDER, exist_ok=True)
        os.makedirs(Config.ENROLLMENT_FOLDER, exist_ok=True)
        os.makedirs(Config.VERIFICATION_FOLDER, exist_ok=True)

    @staticmethod
    async def save_enrollment_image(employee_id: str, file: UploadFile) -> str:
        """
        Save the enrollment profile image on disk under:
        uploads/enrollments/emp_<employee_id>/profile.jpg
        
        Returns:
            str: Relative file path for database storage.
        """
        StorageManager.ensure_directories()
        
        # Clean employee_id for folder naming
        clean_id = "".join(c for c in employee_id if c.isalnum() or c in ("-", "_")).lower()
        emp_folder = os.path.join(Config.ENROLLMENT_FOLDER, f"emp_{clean_id}")
        os.makedirs(emp_folder, exist_ok=True)
        
        # We always save as profile.jpg (overwriting previous enrollments if any)
        file_path = os.path.join(emp_folder, "profile.jpg")
        
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        logger.info(f"✓ Saved enrollment image: {file_path}")
        
        # Return path relative to the backend root folder
        return os.path.relpath(file_path, Config.BASE_DIR)

    @staticmethod
    async def save_verification_image(employee_id: str, file: UploadFile) -> str:
        """
        Save the verification check-in image on disk under:
        uploads/verifications/<yyyy-mm-dd>/emp_<employee_id>_<hhmmss>.jpg
        
        Returns:
            str: Relative file path for database storage.
        """
        StorageManager.ensure_directories()
        
        # Get current date and time
        now = datetime.now()
        date_str = now.strftime("%Y-%m-%d")
        time_str = now.strftime("%H%M%S")
        
        # Create daily folder
        daily_folder = os.path.join(Config.VERIFICATION_FOLDER, date_str)
        os.makedirs(daily_folder, exist_ok=True)
        
        # Format filename
        clean_id = "".join(c for c in employee_id if c.isalnum() or c in ("-", "_")).lower()
        filename = f"emp_{clean_id}_{time_str}.jpg"
        file_path = os.path.join(daily_folder, filename)
        
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        logger.info(f"✓ Saved verification image: {file_path}")
        
        return os.path.relpath(file_path, Config.BASE_DIR)
