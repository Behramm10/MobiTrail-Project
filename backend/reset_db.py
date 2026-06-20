import os
import sys
import logging

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app.database.connection import DatabaseConnector
from app.database.setup import setup_database

logging.basicConfig(level=logging.INFO)

def reset_attendance_table():
    try:
        with DatabaseConnector.get_cursor() as cursor:
            cursor.execute("DROP TABLE IF EXISTS attendance")
            logging.info("Dropped attendance table.")
        setup_database()
        logging.info("Database setup completed.")
    except Exception as e:
        logging.error(f"Error: {e}")

if __name__ == "__main__":
    reset_attendance_table()
