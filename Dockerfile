# Stage 1: Install dependencies
FROM python:3.11-alpine AS builder

# Install build dependencies (needed for compiling some Python packages)
RUN apk add --no-cache gcc musl-dev libffi-dev

WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Stage 2: Final lightweight image
FROM python:3.11-alpine

WORKDIR /app
# Copy installed dependencies
COPY --from=builder /root/.local /root/.local
COPY app.py .

# Ensure local binaries are in PATH
ENV PATH=/root/.local/bin:$PATH

EXPOSE 5000
CMD ["python", "app.py"]

