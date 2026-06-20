import math
import logging
from app.database.config import Config

logger = logging.getLogger(__name__)

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance between two points on the Earth's surface 
    using the Haversine formula.
    
    Returns:
        float: Distance in meters.
    """
    # Earth's radius in meters
    R = 6371000.0
    
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = (math.sin(delta_phi / 2.0) ** 2.0) + \
        (math.cos(phi1) * math.cos(phi2) * (math.sin(delta_lambda / 2.0) ** 2.0))
        
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    
    distance = R * c
    return distance

def verify_geofence(user_lat: float, user_lon: float) -> tuple[bool, float]:
    """
    Check if the user is within the allowed geofence perimeter around the office coordinate.
    
    Returns:
        tuple: (is_within_range, distance_in_meters)
    """
    office_lat = Config.OFFICE_LATITUDE
    office_lon = Config.OFFICE_LONGITUDE
    allowed_radius = Config.GEOFENCE_RADIUS_METERS
    
    distance = calculate_distance(user_lat, user_lon, office_lat, office_lon)
    is_within = distance <= allowed_radius
    
    logger.info(f"Geofence audit: User coordinates ({user_lat}, {user_lon}) are {distance:.2f} meters "
                f"from Office ({office_lat}, {office_lon}). Allowed: {allowed_radius}m. Match: {is_within}")
                
    return is_within, distance
