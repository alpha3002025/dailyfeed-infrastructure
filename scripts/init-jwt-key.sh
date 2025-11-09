#!/bin/bash

# Wrapper script to run JWT key initialization
# This ensures Python dependencies are installed and the script runs correctly using venv
#
# Usage:
#   ./init-jwt-key.sh [environment]
#
# Examples:
#   ./init-jwt-key.sh          # Uses local.env (default)
#   ./init-jwt-key.sh local    # Uses local.env
#   ./init-jwt-key.sh dev      # Uses dev.env
#   ./init-jwt-key.sh prod     # Uses prod.env

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/init-jwt-key.py"
VENV_DIR="${SCRIPT_DIR}/.venv"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
CONFIG_DIR="${SCRIPT_DIR}/config"

# Determine environment (default: local)
ENVIRONMENT="${1:-local}"

echo "🔑 JWT Key Initialization Wrapper"
echo "   Environment: ${ENVIRONMENT}"
echo ""

# Load environment configuration
CONFIG_FILE="${CONFIG_DIR}/${ENVIRONMENT}.env"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ Error: Configuration file not found: ${CONFIG_FILE}"
    echo ""
    echo "Available options:"
    echo "  1. For local environment: File already exists (config/local.env)"
    echo "  2. For dev environment: Copy config/dev.env.example to config/dev.env and update it"
    echo "  3. For prod environment: Copy config/prod.env.example to config/prod.env and update it"
    echo ""
    echo "Example:"
    echo "  cp ${CONFIG_DIR}/dev.env.example ${CONFIG_DIR}/dev.env"
    echo "  # Edit dev.env with your actual RDS credentials"
    echo "  ./init-jwt-key.sh dev"
    echo ""
    exit 1
fi

echo "📝 Loading configuration from: ${CONFIG_FILE}"
set -a  # Automatically export all variables
source "${CONFIG_FILE}"
set +a
echo "   ✅ Configuration loaded"
echo ""

# Validate required variables
REQUIRED_VARS=("MYSQL_HOST" "MYSQL_PORT" "MYSQL_USERNAME" "MYSQL_PASSWORD" "MYSQL_SCHEMA")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("${var}")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Error: Missing required environment variables in ${CONFIG_FILE}:"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - ${var}"
    done
    echo ""
    exit 1
fi

echo "🔗 Database Configuration:"
echo "   Host: ${MYSQL_HOST}:${MYSQL_PORT}"
echo "   Database: ${MYSQL_SCHEMA}"
echo "   User: ${MYSQL_USERNAME}"
echo ""

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is not installed"
    echo "   Please install Python 3 to continue"
    exit 1
fi

echo "✅ Found Python: $(python3 --version)"
echo ""

# Setup virtual environment
if [ ! -d "${VENV_DIR}" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv "${VENV_DIR}" || {
        echo "❌ Failed to create virtual environment"
        echo "   Please ensure python3-venv is installed"
        exit 1
    }
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi
echo ""

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source "${VENV_DIR}/bin/activate" || {
    echo "❌ Failed to activate virtual environment"
    exit 1
}
echo "✅ Virtual environment activated"
echo ""

# Install/upgrade pip
echo "📦 Ensuring pip is up to date..."
pip install --upgrade pip --quiet
echo ""

# Install dependencies
echo "📦 Installing Python dependencies..."
if [ -f "${REQUIREMENTS_FILE}" ]; then
    pip install -r "${REQUIREMENTS_FILE}" --quiet || {
        echo "❌ Failed to install dependencies"
        deactivate
        exit 1
    }
    echo "✅ Dependencies installed successfully"
else
    echo "⚠️  requirements.txt not found, installing pymysql directly..."
    pip install pymysql --quiet || {
        echo "❌ Failed to install pymysql"
        deactivate
        exit 1
    }
    echo "✅ pymysql installed successfully"
fi
echo ""

# Make the Python script executable
chmod +x "${PYTHON_SCRIPT}"

# Export environment variables if not already set
export MYSQL_HOST="${MYSQL_HOST:-localhost}"
export MYSQL_PORT="${MYSQL_PORT:-23306}"
export MYSQL_USERNAME="${MYSQL_USERNAME:-dailyfeed}"
export MYSQL_PASSWORD="${MYSQL_PASSWORD:-hitEnter###}"
export MYSQL_SCHEMA="${MYSQL_SCHEMA:-dailyfeed}"
export JWT_KEY_ROTATION_HOURS="${JWT_KEY_ROTATION_HOURS:-24}"
export JWT_KEY_GRACE_PERIOD_HOURS="${JWT_KEY_GRACE_PERIOD_HOURS:-48}"

# Run the Python script
echo "🚀 Running JWT key initialization..."
echo ""
python3 "${PYTHON_SCRIPT}"
EXIT_CODE=$?

# Deactivate virtual environment
deactivate

exit $EXIT_CODE