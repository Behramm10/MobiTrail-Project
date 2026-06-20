import mysql.connector
from mysql.connector import pooling, Error
from contextlib import contextmanager
import logging
from app.database.config import Config

logger = logging.getLogger(__name__)

class DatabaseConnector:
    _connection_pool = None

    @classmethod
    def initialize_pool(cls):
        """Initialize the connection pool using config credentials"""
        try:
            if cls._connection_pool is None:
                cls._connection_pool = pooling.MySQLConnectionPool(
                    pool_name="mobitrail_pool",
                    pool_size=10,
                    pool_reset_session=True,
                    host=Config.DB_HOST,
                    port=Config.DB_PORT,
                    user=Config.DB_USER,
                    password=Config.DB_PASSWORD,
                    database=Config.DB_NAME,
                    charset="utf8mb4",
                    autocommit=False
                )
                logger.info(f"✓ Database pool initialized successfully on database: {Config.DB_NAME}")
                return True
        except Error as e:
            # If the database does not exist, connect without database parameter first
            if e.errno == 1049: # Unknown database
                logger.warning(f"Database '{Config.DB_NAME}' does not exist. Attempting to create database first...")
                if cls.create_database_if_not_exists():
                    # Retry pool initialization
                    cls._connection_pool = None
                    return cls.initialize_pool()
            logger.error(f"✗ Failed to initialize MySQL connection pool: {e}")
            return False

    @classmethod
    def create_database_if_not_exists(cls):
        """Connect directly to MySQL to create the database if it is missing"""
        try:
            connection = mysql.connector.connect(
                host=Config.DB_HOST,
                port=Config.DB_PORT,
                user=Config.DB_USER,
                password=Config.DB_PASSWORD
            )
            cursor = connection.cursor()
            cursor.execute(f"CREATE DATABASE IF NOT EXISTS {Config.DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
            cursor.close()
            connection.close()
            logger.info(f"✓ Database '{Config.DB_NAME}' verified/created successfully.")
            return True
        except Error as e:
            logger.error(f"✗ Error creating database: {e}")
            return False

    @classmethod
    def get_connection(cls):
        """Get a connection from the pool"""
        try:
            if cls._connection_pool is None:
                cls.initialize_pool()
            if cls._connection_pool:
                return cls._connection_pool.get_connection()
            return None
        except Error as e:
            logger.error(f"✗ Error getting connection from pool: {e}")
            return None

    @classmethod
    @contextmanager
    def get_cursor(cls, dictionary=True, buffered=True):
        """Context manager yielding a database cursor and handling transactions"""
        connection = cls.get_connection()
        if not connection:
            raise Exception("No database connection available")
        cursor = None
        try:
            cursor = connection.cursor(dictionary=dictionary, buffered=buffered)
            yield cursor
            connection.commit()
        except Error as e:
            connection.rollback()
            logger.error(f"✗ Database transaction error: {e}")
            raise
        finally:
            if cursor:
                cursor.close()
            if connection:
                connection.close()

    @classmethod
    def execute_query(cls, query, params=None, fetch=False, fetch_one=False):
        """Helper to execute SQL statements safely with connection management"""
        try:
            with cls.get_cursor() as cursor:
                cursor.execute(query, params or ())
                if fetch_one:
                    return cursor.fetchone()
                elif fetch:
                    return cursor.fetchall()
                else:
                    return cursor.rowcount
        except Exception as e:
            logger.error(f"Error executing query: {e}")
            return None if fetch or fetch_one else 0
