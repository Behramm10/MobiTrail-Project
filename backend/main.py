import logging
import os
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse

from app.database.config import Config
from app.database.setup import setup_database
from app.routers import auth, admin
from app.utils.storage import StorageManager

# Configure logging format and level
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Construct FastAPI app
app = FastAPI(
    title=Config.APP_NAME,
    description="REST API services and Web Admin Portal for the MobiTrail facial recognition attendance system.",
    version=Config.VERSION
)

# Enable Cross-Origin Resource Sharing (CORS) for Flutter client connections
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, restrict to your Flutter client domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Startup event handler to verify database schema tables and storage directories
@app.on_event("startup")
def on_startup():
    logger.info("=" * 60)
    logger.info(f" Starting {Config.APP_NAME} v{Config.VERSION}...")
    logger.info("=" * 60)
    
    # 1. Initialize folders
    StorageManager.ensure_directories()
    
    # 2. Setup MySQL database tables and seed defaults
    db_setup_success = setup_database()
    if db_setup_success:
        logger.info("✓ Database setup completed successfully.")
    else:
        logger.error("✗ Database setup failed. Make sure MySQL server is running and configured correctly.")
        
    logger.info("=" * 60)

# Register endpoints routers
app.include_router(auth.router)
app.include_router(admin.router)

# Mount local upload folders as static directories so Web Dashboard can serve audit photos
# Example: http://localhost:8000/uploads/enrollments/emp_101/profile.jpg
if os.path.exists(Config.UPLOAD_FOLDER):
    app.mount("/uploads", StaticFiles(directory=Config.UPLOAD_FOLDER), name="uploads")
    logger.info(f"✓ Mounted static files path for uploads: {Config.UPLOAD_FOLDER}")

@app.get("/", include_in_schema=False)
async def root_redirect():
    """Redirect root page requests to the admin web dashboard"""
    return RedirectResponse(url="/admin/dashboard")

if __name__ == "__main__":
    import uvicorn
    # Start the ASGI development server
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
