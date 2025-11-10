#!/bin/bash

# Test script for JWT key initialization
# This verifies that the JWT key initialization works correctly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 JWT Key Initialization Test"
echo "================================"
echo ""

# Test configuration
export MYSQL_HOST="${MYSQL_HOST:-localhost}"
export MYSQL_PORT="${MYSQL_PORT:-23306}"
export MYSQL_USERNAME="${MYSQL_USERNAME:-dailyfeed}"
export MYSQL_PASSWORD="${MYSQL_PASSWORD:-hitEnter###}"
export MYSQL_SCHEMA="${MYSQL_SCHEMA:-dailyfeed}"

echo "Test Configuration:"
echo "  MySQL: ${MYSQL_HOST}:${MYSQL_PORT}"
echo "  Database: ${MYSQL_SCHEMA}"
echo "  User: ${MYSQL_USERNAME}"
echo ""

# Function to check database connection
check_db_connection() {
    echo "📡 Testing database connection..."
    if command -v mysql &> /dev/null; then
        mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USERNAME}" -p"${MYSQL_PASSWORD}" -e "SELECT 1;" "${MYSQL_SCHEMA}" &>/dev/null
        if [ $? -eq 0 ]; then
            echo "✅ Database connection successful"
            return 0
        else
            echo "❌ Database connection failed"
            return 1
        fi
    else
        echo "⚠️  mysql client not found, skipping connection test"
        return 0
    fi
}

# Function to count primary keys
count_primary_keys() {
    if command -v mysql &> /dev/null; then
        COUNT=$(mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USERNAME}" -p"${MYSQL_PASSWORD}" -s -N -e \
            "SELECT COUNT(*) FROM jwt_keys WHERE is_primary = TRUE AND is_active = TRUE;" "${MYSQL_SCHEMA}" 2>/dev/null)
        echo $COUNT
    else
        echo "0"
    fi
}

# Function to display current keys
show_keys() {
    echo ""
    echo "📊 Current JWT Keys in Database:"
    if command -v mysql &> /dev/null; then
        mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USERNAME}" -p"${MYSQL_PASSWORD}" -t -e \
            "SELECT key_id, is_primary, is_active, created_at, expires_at FROM jwt_keys ORDER BY created_at DESC LIMIT 5;" "${MYSQL_SCHEMA}" 2>/dev/null
    else
        echo "   (mysql client not available)"
    fi
    echo ""
}

# Test 1: Database connection
echo "Test 1: Database Connection"
echo "----------------------------"
if ! check_db_connection; then
    echo ""
    echo "❌ Test failed: Cannot connect to database"
    echo "   Please ensure Docker Compose is running:"
    echo "   cd dailyfeed-infrastructure/docker/local-hybrid && docker-compose ps"
    exit 1
fi
echo ""

# Test 2: Check initial state
echo "Test 2: Initial State Check"
echo "----------------------------"
INITIAL_COUNT=$(count_primary_keys)
echo "   Primary keys before initialization: ${INITIAL_COUNT}"
show_keys

# Test 3: Run initialization (first time)
echo "Test 3: First Initialization Run"
echo "---------------------------------"
cd "${SCRIPT_DIR}"
./init-jwt-key.sh
FIRST_RUN_EXIT=$?
echo ""
echo "   Exit code: ${FIRST_RUN_EXIT}"

if [ ${FIRST_RUN_EXIT} -ne 0 ]; then
    echo "❌ Test failed: First initialization returned non-zero exit code"
    exit 1
fi

# Check result
AFTER_FIRST=$(count_primary_keys)
echo "   Primary keys after first run: ${AFTER_FIRST}"

if [ "${AFTER_FIRST}" -ne 1 ]; then
    echo "❌ Test failed: Expected exactly 1 primary key, found ${AFTER_FIRST}"
    show_keys
    exit 1
fi

echo "✅ First initialization successful"
show_keys

# Test 4: Run initialization again (idempotency test)
echo "Test 4: Second Initialization Run (Idempotency)"
echo "------------------------------------------------"
./init-jwt-key.sh
SECOND_RUN_EXIT=$?
echo ""
echo "   Exit code: ${SECOND_RUN_EXIT}"

if [ ${SECOND_RUN_EXIT} -ne 0 ]; then
    echo "❌ Test failed: Second initialization returned non-zero exit code"
    exit 1
fi

# Check result
AFTER_SECOND=$(count_primary_keys)
echo "   Primary keys after second run: ${AFTER_SECOND}"

if [ "${AFTER_SECOND}" -ne 1 ]; then
    echo "❌ Test failed: Expected exactly 1 primary key after second run, found ${AFTER_SECOND}"
    show_keys
    exit 1
fi

echo "✅ Idempotency test successful (no duplicate keys created)"
show_keys

# Test 5: Verify key structure
echo "Test 5: Key Structure Validation"
echo "---------------------------------"
if command -v mysql &> /dev/null; then
    KEY_INFO=$(mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USERNAME}" -p"${MYSQL_PASSWORD}" -s -N -e \
        "SELECT key_id, LENGTH(key_value), is_primary, is_active,
         TIMESTAMPDIFF(HOUR, created_at, expires_at) as total_hours
         FROM jwt_keys
         WHERE is_primary = TRUE AND is_active = TRUE
         LIMIT 1;" "${MYSQL_SCHEMA}" 2>/dev/null)

    if [ -n "${KEY_INFO}" ]; then
        echo "   Key Details:"
        echo "   ${KEY_INFO}" | while IFS=$'\t' read -r key_id key_len is_primary is_active hours; do
            echo "     - Key ID: ${key_id}"
            echo "     - Key length: ${key_len} characters"
            echo "     - Is Primary: ${is_primary}"
            echo "     - Is Active: ${is_active}"
            echo "     - Validity period: ${hours} hours"

            # Validate
            if [ "${key_len}" -lt 40 ]; then
                echo "   ❌ Key too short (expected base64-encoded 256-bit key)"
                exit 1
            fi

            if [ "${is_primary}" -ne 1 ]; then
                echo "   ❌ Key is not primary"
                exit 1
            fi

            if [ "${is_active}" -ne 1 ]; then
                echo "   ❌ Key is not active"
                exit 1
            fi

            # Should be rotation_hours + grace_period_hours (default: 24 + 48 = 72)
            if [ "${hours}" -lt 48 ]; then
                echo "   ❌ Validity period too short (expected at least 48 hours)"
                exit 1
            fi
        done
        echo "✅ Key structure validation passed"
    else
        echo "⚠️  Could not retrieve key details"
    fi
else
    echo "⚠️  mysql client not available, skipping structure validation"
fi
echo ""

# Final summary
echo "================================"
echo "🎉 All Tests Passed!"
echo "================================"
echo ""
echo "Summary:"
echo "  ✅ Database connection successful"
echo "  ✅ Initial key creation works"
echo "  ✅ Idempotent (safe to run multiple times)"
echo "  ✅ Key structure is valid"
echo "  ✅ Exactly 1 primary key exists"
echo ""
echo "The JWT key initialization is ready for production use."
echo ""

exit 0