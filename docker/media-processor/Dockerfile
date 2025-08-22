FROM python:3.13-slim

# Install system dependencies including FFmpeg
RUN apt-get update && apt-get install -y \
    ffmpeg \
    imagemagick \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies for media processing
RUN pip install --no-cache-dir \
    celery==5.3.* \
    redis==5.0.* \
    boto3==1.26.* \
    pillow==10.0.* \
    python-magic==0.4.* \
    moviepy==1.0.* \
    opencv-python-headless==4.8.*

# Create app directory
WORKDIR /app

# Create processing directories
RUN mkdir -p /tmp/processing /app/uploads

# Copy media processing scripts
COPY livelens_deployment/docker/media-processor/process_media.py /app/
COPY livelens_deployment/docker/media-processor/video_processor.py /app/
COPY livelens_deployment/docker/media-processor/image_processor.py /app/

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Default command
CMD ["python", "process_media.py"]
