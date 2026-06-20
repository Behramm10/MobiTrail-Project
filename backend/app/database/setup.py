import logging
import bcrypt
from app.database.connection import DatabaseConnector

logger = logging.getLogger(__name__)

def setup_database():
    """Create all database tables required for the attendance system"""
    logger.info("Initializing database tables...")
    
    # 1. Ensure database exists
    DatabaseConnector.create_database_if_not_exists()
    
    # 2. Setup connection
    connection = DatabaseConnector.get_connection()
    if not connection:
        logger.error("✗ Database setup aborted: No connection.")
        return False
        
    try:
        with DatabaseConnector.get_cursor() as cursor:
            # 3. Create employees table
            logger.info("Creating 'employees' table...")
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS employees (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    employee_id VARCHAR(50) UNIQUE NOT NULL,
                    name VARCHAR(100) NOT NULL,
                    email VARCHAR(100) UNIQUE NOT NULL,
                    face_embedding JSON NULL, -- JSON list containing the float numbers
                    enrollment_image_path VARCHAR(255) NULL,
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    INDEX idx_employee_id (employee_id),
                    INDEX idx_active (is_active)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            # 4. Create attendance table
            logger.info("Creating 'attendance' table...")
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS attendance (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    employee_id VARCHAR(50) NOT NULL,
                    time_in_time DATETIME DEFAULT CURRENT_TIMESTAMP,
                    time_in_status ENUM('APPROVED', 'REJECTED', 'WAITING_FOR_APPROVAL') DEFAULT 'APPROVED',
                    time_out_time DATETIME NULL,
                    time_out_status ENUM('APPROVED', 'REJECTED', 'WAITING_FOR_APPROVAL') NULL,
                    time_in_image_path VARCHAR(255) NULL,
                    time_out_image_path VARCHAR(255) NULL,
                    time_in_similarity_score DECIMAL(5,2) NULL,
                    time_out_similarity_score DECIMAL(5,2) NULL,
                    time_in_latitude DECIMAL(9,6) NULL,
                    time_in_longitude DECIMAL(9,6) NULL,
                    time_out_latitude DECIMAL(9,6) NULL,
                    time_out_longitude DECIMAL(9,6) NULL,
                    time_in_distance_meters DECIMAL(10,2) NULL,
                    time_out_distance_meters DECIMAL(10,2) NULL,
                    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
                    INDEX idx_employee_id (employee_id),
                    INDEX idx_time_in (time_in_time),
                    INDEX idx_time_in_status (time_in_status)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            # 5. Create admins table
            logger.info("Creating 'admins' table...")
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS admins (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(50) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            logger.info("✓ All database tables verified/created successfully.")
            
        # 6. Seed default admin if missing
        seed_admin_user()
        return True
    except Exception as e:
        logger.error(f"✗ Database setup failed: {e}")
        return False

def seed_admin_user():
    """Seeds a default admin user for dashboard authentication"""
    try:
        # Check if admin already exists
        check_query = "SELECT id FROM admins WHERE username = %s"
        admin = DatabaseConnector.execute_query(check_query, ("admin",), fetch_one=True)
        
        if not admin:
            logger.info("Seeding default admin user...")
            # Default password is "admin123"
            hashed_pw = bcrypt.hashpw("admin123".encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
            insert_query = "INSERT INTO admins (username, password_hash) VALUES (%s, %s)"
            DatabaseConnector.execute_query(insert_query, ("admin", hashed_pw))
            logger.info("✓ Default admin seeded successfully. Username: admin, Password: admin123")
        else:
            logger.info("✓ Admin account already exists.")
    except Exception as e:
        logger.error(f"✗ Failed to seed admin user: {e}")

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    setup_database()
