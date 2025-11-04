FROM python:3.9-slim

# Install MySQL client dependencies
RUN apt-get update && apt-get install -y \
    default-libmysqlclient-dev \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Python MySQL connector
RUN pip install mysqlclient

# Create working directory
WORKDIR /app

# Copy the script
COPY generate_feed.py .

# Set Python to unbuffered mode for real-time output
ENV PYTHONUNBUFFERED=1

# Run the script with unbuffered flag
CMD ["python", "-u", "generate_feed.py"]