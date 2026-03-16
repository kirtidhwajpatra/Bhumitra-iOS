"""
MyBhoomi - Bhulekh RoR Backend Service
Entry Point
"""
from app import create_app

app = create_app()

if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.environ.get("PORT", 8000))
    # Production: reload=False, log_level="info"
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False, log_level="info")
