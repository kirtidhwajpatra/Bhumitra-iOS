# Use Python 3.12 slim bookworm as base
FROM python:3.12-slim-bookworm

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PORT=8080

# Set working directory
WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright browser (Chromium only to keep image size smaller)
RUN playwright install chromium
RUN playwright install-deps chromium

# Copy application code
COPY . .

# Expose port
EXPOSE 8080

# Start the application using Gunicorn with Uvicorn workers
CMD gunicorn main:app \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:$PORT \
    --timeout 120
