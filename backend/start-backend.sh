#!/bin/bash
# Voice Agent Backend — Start the Spring Boot sync server
# Tries docker-compose first, falls back to Maven.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

API_PORT=8080

echo "==> Starting Voice Agent Backend..."

# Option 1: Docker Compose
if command -v docker &>/dev/null && command -v docker-compose &>/dev/null; then
    echo "    Using Docker Compose..."

    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d
        echo ""
        echo "==> Backend started via Docker Compose"
        echo "    API URL: http://localhost:$API_PORT"
        exit 0
    else
        echo "    docker-compose.yml not found, falling back to Maven..."
    fi
elif command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
    echo "    Using Docker Compose (v2 plugin)..."

    if [ -f "docker-compose.yml" ]; then
        docker compose up -d
        echo ""
        echo "==> Backend started via Docker Compose"
        echo "    API URL: http://localhost:$API_PORT"
        exit 0
    else
        echo "    docker-compose.yml not found, falling back to Maven..."
    fi
fi

# Option 2: Maven
if command -v mvn &>/dev/null; then
    echo "    Using Maven (mvn spring-boot:run)..."

    # Check for Java
    if ! command -v java &>/dev/null; then
        echo "    ERROR: Java is required but not installed."
        echo "    Install Java: brew install openjdk@21"
        exit 1
    fi

    echo "    Starting Spring Boot application..."
    mvn spring-boot:run &
    MVN_PID=$!

    echo ""
    echo "==> Backend starting via Maven (PID: $MVN_PID)"
    echo "    API URL: http://localhost:$API_PORT"
    echo "    Logs: check terminal output"
    exit 0
fi

# Neither available
echo "    ERROR: Neither Docker nor Maven found."
echo ""
echo "    To run the backend, install one of:"
echo "      - Docker: https://www.docker.com/products/docker-desktop/"
echo "      - Maven + Java: brew install maven openjdk@21"
exit 1
