#!/bin/bash
# PyDICOM Logging Configuration Fix - Task Initialization Script
# This script sets up the environment for fixing library logging issues

set -e  # Exit on error

echo "🚀 Initializing PyDICOM Logging Configuration Fix Challenge..."

# Install system dependencies
sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y bc jq curl >/dev/null 2>&1

# Load configuration
CONFIG_DIR="config"
TEMPLATE_DIR="template"

# Read dynamic parameters
PARAMS_FILE="$CONFIG_DIR/dynamic_params.json"

# Generate random parameters within specified ranges
HANDLER_TYPES=("StreamHandler" "FileHandler" "ConsoleHandler")
LOG_LEVELS=("DEBUG" "INFO" "WARNING" "ERROR")
HANDLER_TYPE=${HANDLER_TYPES[$RANDOM % ${#HANDLER_TYPES[@]}]}
LOG_LEVEL=${LOG_LEVELS[$RANDOM % ${#LOG_LEVELS[@]}]}
MODULE_COMPLEXITY=$((RANDOM % 6 + 3))  # 3-8

echo "📊 Generated parameters:"
echo "   - Handler type mentioned: $HANDLER_TYPE"
echo "   - Log level: $LOG_LEVEL"
echo "   - Module complexity: $MODULE_COMPLEXITY"

# Generate current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Call LLM for dynamic content (with fallbacks)
if [ ! -z "$LLM_API_URL" ] && [ ! -z "$LLM_API_KEY" ]; then
    echo "🤖 Generating dynamic content with LLM..."
    
    # Generate library name
    LIBRARY_NAME=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Generate a realistic Python library name for medical imaging or data processing. Be professional and descriptive. Examples: '\''MedImage'\'', '\''DataFlow'\'', '\''ImageCore'\''. Return only the library name, nothing else.",
            "max_tokens": 15,
            "temperature": 0.7
        }' | jq -r '.choices[0].text' | tr -d '\n' | sed 's/^[[:space:]]*//' || echo "PyMedical")
    
    # Generate scenario
    SCENARIO_PROMPT="Write a 2-3 sentence scenario describing how a developer is using the $LIBRARY_NAME library and encountering duplicate logging output. Include specific symptoms like duplicate messages or unwanted log formatting. Be technical but concise."
    USE_CASE_SCENARIO=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"prompt\": \"$SCENARIO_PROMPT\",
            \"max_tokens\": 120,
            \"temperature\": 0.6
        }" | jq -r '.choices[0].text' | tr '\n' ' ' | sed 's/^[[:space:]]*//' || echo "Default scenario")
else
    echo "⚠️  LLM not available, using fallback content..."
    LIBRARY_NAME="PyMedical"
    USE_CASE_SCENARIO="A developer integrates $LIBRARY_NAME into their medical imaging application and notices duplicate log messages appearing in their console output. The library automatically configures a StreamHandler, interfering with the application's own logging setup and causing redundant error messages."
fi

# Escape special characters for sed
LIBRARY_NAME_ESCAPED=$(echo "$LIBRARY_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
USE_CASE_SCENARIO_ESCAPED=$(echo "$USE_CASE_SCENARIO" | sed 's/[[\.*^$()+?{|]/\\&/g')

echo "📚 Library: $LIBRARY_NAME"

# Copy requirements and install dependencies
echo "📦 Setting up environment..."
cp "$TEMPLATE_DIR/requirements.txt" requirements.txt
pip install -r requirements.txt >/dev/null 2>&1

# Process templates
echo "📝 Processing templates..."

# Process README.md
sed -e "s/{{library_name}}/$LIBRARY_NAME_ESCAPED/g" \
    -e "s/{{use_case_scenario}}/$USE_CASE_SCENARIO_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

# Process starter code - this will be the main file they need to edit
sed -e "s/{{library_name}}/$LIBRARY_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > config.py

# Create the test file (extracted from the SWE-bench test_patch)
cat > test_config.py << 'EOF'
# Copyright 2008-2019 pydicom authors. See LICENSE file for details.
"""Unit tests for the config module."""

import logging
import sys
import os

import pytest

# Import from our local config module
from config import debug, logger

class TestDebug(object):
    """Tests for config.debug()."""
    def setup_method(self):
        self.logger = logging.getLogger('pydicom')

    def teardown_method(self):
        # Reset to just NullHandler
        self.logger.handlers = [self.logger.handlers[0]]
        # Reset level
        self.logger.setLevel(logging.WARNING)

    def test_default(self, caplog):
        """Test that the default logging handler is a NullHandler."""
        assert 1 == len(self.logger.handlers)
        assert isinstance(self.logger.handlers[0], logging.NullHandler)

        with caplog.at_level(logging.DEBUG, logger='pydicom'):
            # Simulate some logging that would happen during pydicom operations
            self.logger.debug("Reading File Meta Information preamble...")
            self.logger.debug("Reading File Meta Information prefix...")
            self.logger.debug("00000080: 'DICM' prefix found")

            # With NullHandler, debug messages should be captured by caplog
            # but "Call to dcmread()" should not appear since debug is off
            assert "Call to dcmread()" not in caplog.text
            assert "Reading File Meta Information preamble..." in caplog.text
            assert "Reading File Meta Information prefix..." in caplog.text
            assert "00000080: 'DICM' prefix found" in caplog.text

    def test_debug_on_handler_null(self, caplog):
        """Test debug(True, False)."""
        debug(True, False)
        assert 1 == len(self.logger.handlers)
        assert isinstance(self.logger.handlers[0], logging.NullHandler)

        with caplog.at_level(logging.DEBUG, logger='pydicom'):
            self.logger.debug("Call to dcmread()")
            self.logger.debug("Reading File Meta Information preamble...")
            self.logger.debug("Reading File Meta Information prefix...")
            self.logger.debug("00000080: 'DICM' prefix found")
            msg = (
                "00009848: fc ff fc ff 4f 42 00 00 7e 00 00 00    "
                "(fffc, fffc) OB Length: 126"
            )
            self.logger.debug(msg)

            assert "Call to dcmread()" in caplog.text
            assert "Reading File Meta Information preamble..." in caplog.text
            assert "Reading File Meta Information prefix..." in caplog.text
            assert "00000080: 'DICM' prefix found" in caplog.text
            assert msg in caplog.text

    def test_debug_off_handler_null(self, caplog):
        """Test debug(False, False)."""
        debug(False, False)
        assert 1 == len(self.logger.handlers)
        assert isinstance(self.logger.handlers[0], logging.NullHandler)

        with caplog.at_level(logging.DEBUG, logger='pydicom'):
            self.logger.debug("Call to dcmread()")
            self.logger.debug("Reading File Meta Information preamble...")
            self.logger.debug("Reading File Meta Information prefix...")
            self.logger.debug("00000080: 'DICM' prefix found")

            # When debug is off, "Call to dcmread()" should not be logged at DEBUG level
            # but other messages at WARNING+ should still appear
            assert "Call to dcmread()" not in caplog.text
            # These should appear because caplog captures at DEBUG level regardless
            assert "Reading File Meta Information preamble..." in caplog.text
            assert "Reading File Meta Information prefix..." in caplog.text
            assert "00000080: 'DICM' prefix found" in caplog.text

    def test_debug_on_handler_stream(self, caplog):
        """Test debug(True, True)."""
        debug(True, True)
        assert 2 == len(self.logger.handlers)
        assert isinstance(self.logger.handlers[0], logging.NullHandler)
        assert isinstance(self.logger.handlers[1], logging.StreamHandler)

        with caplog.at_level(logging.DEBUG, logger='pydicom'):
            self.logger.debug("Call to dcmread()")
            self.logger.debug("Reading File Meta Information preamble...")
            self.logger.debug("Reading File Meta Information prefix...")
            self.logger.debug("00000080: 'DICM' prefix found")
            msg = (
                "00009848: fc ff fc ff 4f 42 00 00 7e 00 00 00    "
                "(fffc, fffc) OB Length: 126"
            )
            self.logger.debug(msg)

            assert "Call to dcmread()" in caplog.text
            assert "Reading File Meta Information preamble..." in caplog.text
            assert "Reading File Meta Information prefix..." in caplog.text
            assert "00000080: 'DICM' prefix found" in caplog.text
            assert msg in caplog.text

    def test_debug_off_handler_stream(self, caplog):
        """Test debug(False, True)."""
        debug(False, True)
        assert 2 == len(self.logger.handlers)
        assert isinstance(self.logger.handlers[0], logging.NullHandler)
        assert isinstance(self.logger.handlers[1], logging.StreamHandler)

        with caplog.at_level(logging.DEBUG, logger='pydicom'):
            self.logger.debug("Call to dcmread()")
            self.logger.debug("Reading File Meta Information preamble...")
            self.logger.debug("Reading File Meta Information prefix...")
            self.logger.debug("00000080: 'DICM' prefix found")

            # When debug is off, "Call to dcmread()" should not be logged
            assert "Call to dcmread()" not in caplog.text
            assert "Reading File Meta Information preamble..." in caplog.text
            assert "Reading File Meta Information prefix..." in caplog.text
            assert "00000080: 'DICM' prefix found" in caplog.text
EOF

# Create a simple test runner
cat > run_tests.py << 'EOF'
#!/usr/bin/env python3
"""
Simple test runner for the logging configuration fix
"""

import subprocess
import sys

def run_tests():
    """Run the test suite and provide feedback."""
    print("🧪 Running tests for logging configuration fix...")
    
    try:
        # Run pytest with verbose output
        result = subprocess.run([
            sys.executable, "-m", "pytest", 
            "test_config.py", 
            "-v", 
            "--tb=short"
        ], capture_output=True, text=True)
        
        print("📋 Test Results:")
        print("=" * 50)
        print(result.stdout)
        
        if result.stderr:
            print("⚠️  Warnings/Errors:")
            print(result.stderr)
        
        if result.returncode == 0:
            print("✅ All tests passed! Your implementation is correct.")
            return True
        else:
            print("❌ Some tests failed. Please review your implementation.")
            print("\n💡 Hints:")
            print("1. Make sure your debug() function has the correct signature")
            print("2. Check that you're only adding StreamHandler when default_handler=True")
            print("3. Verify the logging level is set correctly based on debug_on")
            print("4. Ensure the debugging global variable is updated")
            return False
            
    except Exception as e:
        print(f"❌ Error running tests: {e}")
        return False

if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
EOF
chmod +x run_tests.py

# Create submission metadata
cat > .submission_metadata.json << EOF
{
    "task_id": "SWE-LOGGING-$(date +%s)",
    "generation_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "parameters": {
        "library_name": "$LIBRARY_NAME",
        "handler_type": "$HANDLER_TYPE",
        "log_level": "$LOG_LEVEL",
        "complexity": $MODULE_COMPLEXITY
    },
    "task_type": "software_engineering",
    "difficulty": "easy"
}
EOF

# Clean up templates and config
rm -rf "$TEMPLATE_DIR"
rm -rf "$CONFIG_DIR"

# Success message
echo ""
echo "✅ Task initialization complete!"
echo ""
echo "📋 Your mission:"
echo "   Fix the logging configuration in config.py to follow Python best practices"
echo ""
echo "📝 Files to work with:"
echo "   - config.py (main file to edit)"
echo "   - test_config.py (test suite)"
echo "   - README.md (detailed problem description)"
echo ""
echo "🔧 Commands:"
echo "   - Test your solution: python run_tests.py"
echo "   - Manual testing: python -m pytest test_config.py -v"
echo "   - Submit: ./submit.sh"
echo ""
echo "🎯 Goal: Make all tests pass by implementing proper logging configuration"
echo ""
echo "Good luck! 🍀"