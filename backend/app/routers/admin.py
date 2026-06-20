import os
import logging
from typing import Optional
from datetime import datetime
import csv
import io
from fastapi import APIRouter, Request, HTTPException, status, Form, Depends
from fastapi.responses import HTMLResponse, RedirectResponse, StreamingResponse
from fastapi.templating import Jinja2Templates

from app.database.config import Config
from app.database.connection import DatabaseConnector

logger = logging.getLogger(__name__)

# Create Router
router = APIRouter(prefix="/admin", tags=["Web Admin Panel"])

# Initialize templates directory
templates_path = os.path.join(Config.BASE_DIR, "templates")
templates = Jinja2Templates(directory=templates_path)

@router.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request, date: Optional[str] = None):
    """Render the main attendance log dashboard"""
    try:
        # Default to today's date if not provided
        if not date:
            date = datetime.now().strftime('%Y-%m-%d')
            
        # Fetch attendance logs linked with employee profiles for the selected date
        query = """
            SELECT 
                a.id as attendance_id,
                a.employee_id,
                e.name,
                a.time_in_time,
                a.time_in_status,
                a.time_out_time,
                a.time_out_status,
                a.time_in_similarity_score,
                a.time_out_similarity_score,
                a.time_in_latitude,
                a.time_in_longitude,
                a.time_out_latitude,
                a.time_out_longitude,
                a.time_in_distance_meters,
                a.time_out_distance_meters
            FROM attendance a
            JOIN employees e ON a.employee_id = e.employee_id
            WHERE DATE(a.time_in_time) = %s
            ORDER BY a.time_in_time DESC
        """
        logs = DatabaseConnector.execute_query(query, (date,), fetch=True)
        
        # Calculate summary metrics
        total = len(logs)
        approved = sum(1 for log in logs if log["time_in_status"] == "APPROVED" or log["time_out_status"] == "APPROVED")
        pending = sum(1 for log in logs if log["time_in_status"] == "WAITING_FOR_APPROVAL" or log["time_out_status"] == "WAITING_FOR_APPROVAL")
        rejected = sum(1 for log in logs if log["time_in_status"] == "REJECTED" or log["time_out_status"] == "REJECTED")
        
        return templates.TemplateResponse(
            "dashboard.html", 
            {
                "request": request, 
                "logs": logs, 
                "total": total,
                "approved": approved, 
                "pending": pending, 
                "rejected": rejected,
                "selected_date": date,
                "office_lat": Config.OFFICE_LATITUDE,
                "office_lon": Config.OFFICE_LONGITUDE
            }
        )
    except Exception as e:
        logger.error(f"Error rendering admin dashboard: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to load dashboard: {str(e)}"
        )

@router.get("/export-csv")
async def export_csv(date: Optional[str] = None):
    """Export attendance logs for a selected date to a CSV file"""
    try:
        if not date:
            date = datetime.now().strftime('%Y-%m-%d')
            
        query = """
            SELECT 
                a.employee_id,
                e.name,
                a.time_in_time,
                a.time_in_status,
                a.time_out_time,
                a.time_out_status,
                a.time_in_similarity_score,
                a.time_out_similarity_score,
                a.time_in_distance_meters,
                a.time_out_distance_meters
            FROM attendance a
            JOIN employees e ON a.employee_id = e.employee_id
            WHERE DATE(a.time_in_time) = %s
            ORDER BY a.time_in_time DESC
        """
        records = DatabaseConnector.execute_query(query, (date,), fetch=True)
        
        # Create CSV in-memory stream
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Write header
        writer.writerow([
            "Employee ID", 
            "Name", 
            "Time In", 
            "Time In Status", 
            "Time Out", 
            "Time Out Status", 
            "Match Score (In / Out)", 
            "Distance to Office (In / Out)"
        ])
        
        for row in records:
            time_in_str = row["time_in_time"].strftime('%I:%M:%S %p') if row["time_in_time"] else "-"
            time_out_str = row["time_out_time"].strftime('%I:%M:%S %p') if row["time_out_time"] else "-"
            
            # Match scores
            in_score = f"{row['time_in_similarity_score']}%" if row["time_in_similarity_score"] else "-"
            out_score = f"{row['time_out_similarity_score']}%" if row["time_out_similarity_score"] else "-"
            match_score = f"In: {in_score} / Out: {out_score}"
            
            # Distances
            in_dist = f"{row['time_in_distance_meters']:.2f}m" if row["time_in_distance_meters"] is not None else "-"
            out_dist = f"{row['time_out_distance_meters']:.2f}m" if row["time_out_distance_meters"] is not None else "-"
            distance_str = f"In: {in_dist} / Out: {out_dist}"
            
            writer.writerow([
                row["employee_id"],
                row["name"],
                time_in_str,
                row["time_in_status"],
                time_out_str,
                row["time_out_status"] or "-",
                match_score,
                distance_str
            ])
            
        output.seek(0)
        headers = {
            'Content-Disposition': f'attachment; filename="attendance_{date}.csv"'
        }
        return StreamingResponse(output, media_type="text/csv", headers=headers)
    except Exception as e:
        logger.error(f"Error exporting CSV: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Export failed: {str(e)}"
        )

@router.get("/audit/{attendance_id}", response_class=HTMLResponse)
async def audit_photo(request: Request, attendance_id: int):
    """Display 3-column photos comparison for a specific check-in record"""
    try:
        query = """
            SELECT 
                a.id as attendance_id,
                a.employee_id,
                e.name,
                e.enrollment_image_path,
                a.time_in_image_path,
                a.time_out_image_path,
                a.time_in_status,
                a.time_out_status,
                a.time_in_similarity_score,
                a.time_out_similarity_score,
                a.time_in_time,
                a.time_out_time
            FROM attendance a
            JOIN employees e ON a.employee_id = e.employee_id
            WHERE a.id = %s
        """
        record = DatabaseConnector.execute_query(query, (attendance_id,), fetch_one=True)
        
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attendance log record not found."
            )
            
        return templates.TemplateResponse(
            "audit.html",
            {
                "request": request,
                "record": record
            }
        )
    except Exception as e:
        logger.error(f"Error rendering audit page: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to load audit view: {str(e)}"
        )

@router.post("/audit/{attendance_id}/approve")
async def approve_audit(attendance_id: int):
    """Manually approve and override a check-in status from WAITING_FOR_APPROVAL to APPROVED"""
    try:
        # Check if record exists
        query = "SELECT time_in_status, time_out_status, employee_id FROM attendance WHERE id = %s"
        record = DatabaseConnector.execute_query(query, (attendance_id,), fetch_one=True)
        
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attendance log record not found."
            )
            
        # Update whichever status is WAITING_FOR_APPROVAL
        if record["time_in_status"] == "WAITING_FOR_APPROVAL":
            update_query = "UPDATE attendance SET time_in_status = 'APPROVED' WHERE id = %s"
            DatabaseConnector.execute_query(update_query, (attendance_id,))
        elif record["time_out_status"] == "WAITING_FOR_APPROVAL":
            update_query = "UPDATE attendance SET time_out_status = 'APPROVED' WHERE id = %s"
            DatabaseConnector.execute_query(update_query, (attendance_id,))
        
        logger.info(f"✓ Admin manually approved attendance for Employee ID: {record['employee_id']} "
                    f"(Record ID: {attendance_id})")
                    
        return RedirectResponse(url="/admin/dashboard", status_code=status.HTTP_303_SEE_OTHER)
    except Exception as e:
        logger.error(f"Error approving attendance audit: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Action failed: {str(e)}"
        )
