#!/usr/bin/env python3
"""
JWT Key Initializer for DailyFeed
Initializes a primary JWT key in the database before application startup
to prevent race conditions in multi-replica Kubernetes deployments.
"""

import sys
import os
import base64
import secrets
import hashlib
from datetime import datetime, timedelta
import pymysql
from pymysql.cursors import DictCursor
import time

# Configuration from environment variables
MYSQL_HOST = os.getenv('MYSQL_HOST', 'localhost')
MYSQL_PORT = int(os.getenv('MYSQL_PORT', '23306'))
MYSQL_USERNAME = os.getenv('MYSQL_USERNAME', 'dailyfeed')
MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', 'hitEnter###')
MYSQL_DATABASE = os.getenv('MYSQL_SCHEMA', 'dailyfeed')

# JWT Key configuration (matching Java application settings)
KEY_ROTATION_HOURS = int(os.getenv('JWT_KEY_ROTATION_HOURS', '24'))
GRACE_PERIOD_HOURS = int(os.getenv('JWT_KEY_GRACE_PERIOD_HOURS', '48'))

def generate_secret_key():
    """Generate a cryptographically secure 256-bit key for HS256"""
    # Generate 32 bytes (256 bits) for HS256
    random_bytes = secrets.token_bytes(32)
    # Base64 encode (matching Java's Base64.getEncoder().encodeToString())
    encoded_key = base64.b64encode(random_bytes).decode('utf-8')
    return encoded_key

def generate_key_id():
    """Generate a unique key ID using timestamp and random hash"""
    timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
    random_suffix = hashlib.sha256(secrets.token_bytes(16)).hexdigest()[:8]
    return f"key-{timestamp}-{random_suffix}"

def connect_to_database(max_retries=5, retry_delay=3):
    """Connect to MySQL database with retry logic"""
    for attempt in range(1, max_retries + 1):
        try:
            print(f"🔌 Connecting to MySQL at {MYSQL_HOST}:{MYSQL_PORT} (attempt {attempt}/{max_retries})...")
            connection = pymysql.connect(
                host=MYSQL_HOST,
                port=MYSQL_PORT,
                user=MYSQL_USERNAME,
                password=MYSQL_PASSWORD,
                database=MYSQL_DATABASE,
                charset='utf8mb4',
                cursorclass=DictCursor,
                autocommit=False
            )
            print("✅ Connected to MySQL successfully")
            return connection
        except pymysql.Error as e:
            print(f"⚠️  Connection attempt {attempt} failed: {e}")
            if attempt < max_retries:
                print(f"   Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                print(f"❌ Failed to connect after {max_retries} attempts")
                raise

def check_existing_primary_key(cursor):
    """Check if a primary key already exists"""
    query = """
        SELECT key_id, is_primary, is_active, created_at, expires_at
        FROM jwt_keys
        WHERE is_primary = TRUE AND is_active = TRUE
        ORDER BY created_at DESC
        LIMIT 1
    """
    cursor.execute(query)
    return cursor.fetchone()

def deactivate_all_primary_keys(cursor):
    """Deactivate all existing primary keys (safety measure)"""
    query = """
        UPDATE jwt_keys
        SET is_primary = FALSE
        WHERE is_primary = TRUE
    """
    affected_rows = cursor.execute(query)
    if affected_rows > 0:
        print(f"   Deactivated {affected_rows} existing primary key(s)")
    return affected_rows

def create_primary_key(cursor):
    """Create a new primary JWT key"""
    key_id = generate_key_id()
    key_value = generate_secret_key()
    created_at = datetime.now()
    expires_at = created_at + timedelta(hours=KEY_ROTATION_HOURS + GRACE_PERIOD_HOURS)

    query = """
        INSERT INTO jwt_keys (
            key_id,
            key_value,
            is_primary,
            is_active,
            created_at,
            expires_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s
        )
    """

    cursor.execute(query, (
        key_id,
        key_value,
        True,   # is_primary
        True,   # is_active
        created_at,
        expires_at
    ))

    return {
        'key_id': key_id,
        'created_at': created_at,
        'expires_at': expires_at
    }

def initialize_jwt_key():
    """Main function to initialize JWT key"""
    print("🔑 JWT Key Initialization Starting...")
    print(f"   Configuration:")
    print(f"   - Database: {MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DATABASE}")
    print(f"   - Key Rotation: {KEY_ROTATION_HOURS} hours")
    print(f"   - Grace Period: {GRACE_PERIOD_HOURS} hours")
    print()

    connection = None
    try:
        # Connect to database
        connection = connect_to_database()
        cursor = connection.cursor()

        # Check for existing primary key
        print("🔍 Checking for existing primary key...")
        existing_key = check_existing_primary_key(cursor)

        if existing_key:
            print(f"✅ Primary key already exists:")
            print(f"   - Key ID: {existing_key['key_id']}")
            print(f"   - Created: {existing_key['created_at']}")
            print(f"   - Expires: {existing_key['expires_at']}")
            print(f"   - Is Primary: {existing_key['is_primary']}")
            print(f"   - Is Active: {existing_key['is_active']}")
            print()
            print("ℹ️  No action needed. Existing key will be used.")
            return 0

        # No primary key exists - create new one
        print("⚠️  No primary key found. Creating new one...")
        print()

        # Safety: Deactivate any stale primary keys
        print("🔧 Safety check: Deactivating any stale primary keys...")
        deactivate_all_primary_keys(cursor)

        # Create new primary key
        print("🔑 Generating new primary JWT key...")
        new_key = create_primary_key(cursor)

        # Commit transaction
        connection.commit()

        print()
        print("✅ Primary JWT key created successfully!")
        print(f"   - Key ID: {new_key['key_id']}")
        print(f"   - Created: {new_key['created_at']}")
        print(f"   - Expires: {new_key['expires_at']}")
        print()
        print("🎉 JWT Key initialization complete!")

        return 0

    except pymysql.Error as e:
        print(f"❌ Database error: {e}")
        if connection:
            connection.rollback()
        return 1

    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        if connection:
            connection.rollback()
        return 1

    finally:
        if connection:
            connection.close()
            print("🔌 Database connection closed")

if __name__ == "__main__":
    try:
        exit_code = initialize_jwt_key()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\n⚠️  Interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        sys.exit(1)