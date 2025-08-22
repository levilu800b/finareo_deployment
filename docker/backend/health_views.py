# Health check views for Docker containers
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.cache import never_cache
from django.db import connection
from django.core.cache import cache
import logging

logger = logging.getLogger(__name__)

@csrf_exempt
@never_cache
def simple_health_check(request):
    """Simple health check that just returns OK"""
    return HttpResponse("OK", content_type="text/plain")

@csrf_exempt
@never_cache
def health_check(request):
    """Comprehensive health check for Docker container"""
    health_status = {
        "status": "healthy",
        "timestamp": "",
        "checks": {
            "database": "unknown",
            "cache": "unknown"
        }
    }
    
    # Check database connection
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        health_status["checks"]["database"] = "healthy"
    except Exception as e:
        health_status["checks"]["database"] = "unhealthy"
        health_status["status"] = "unhealthy"
        logger.error(f"Database health check failed: {e}")
    
    # Check cache connection
    try:
        cache.set("health_check", "test", 10)
        cache.get("health_check")
        health_status["checks"]["cache"] = "healthy"
    except Exception as e:
        health_status["checks"]["cache"] = "unhealthy"
        health_status["status"] = "degraded"
        logger.warning(f"Cache health check failed: {e}")
    
    from django.utils import timezone
    health_status["timestamp"] = timezone.now().isoformat()
    
    status_code = 200 if health_status["status"] in ["healthy", "degraded"] else 503
    return JsonResponse(health_status, status=status_code)

@csrf_exempt
@never_cache
def readiness_check(request):
    """Readiness check for Kubernetes/ECS deployment"""
    try:
        # Check if database is ready
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        
        return JsonResponse({
            "status": "ready",
            "timestamp": "",
        })
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        return JsonResponse({
            "status": "not ready",
            "error": str(e),
            "timestamp": "",
        }, status=503)
