#!/bin/bash
# Solution Submission Script for PyDICOM Logging Fix

set -e  # Exit on error

echo "📤 Preparing to submit your logging configuration fix..."

# Check if required files exist
if [ ! -f "config.py" ]; then
    echo "❌ Error: config.py not found!"
    echo "Please implement your solution in config.py"
    exit 1
fi

if [ ! -f "test_config.py" ]; then
    echo "❌ Error: test_config.py not found!"
    echo "This might not be a valid task workspace."
    exit 1
fi

# Run tests before submission
echo "🧪 Running final tests before submission..."
python run_tests.py
TEST_RESULT=$?

if [ $TEST_RESULT -ne 0 ]; then
    echo ""
    echo "❌ Tests are failing! Please fix your implementation before submitting."
    echo "Run 'python run_tests.py' to see detailed test results."
    read -p "Do you want to submit anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Submission cancelled."
        exit 1
    fi
fi

# Check environment variables
if [ -z "$SUBMISSION_API_URL" ] || [ -z "$SUBMISSION_API_KEY" ]; then
    echo "❌ Error: Submission credentials not configured!"
    echo "Please ensure you're running in the correct environment."
    exit 1
fi

# Get GitHub username (if available)
GITHUB_USER=$(git config --get user.name 2>/dev/null || echo "anonymous")
GITHUB_EMAIL=$(git config --get user.email 2>/dev/null || echo "anonymous@example.com")

# Create submission package
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SUBMISSION_ID="swe_logging_${TIMESTAMP}_${RANDOM}"
PACKAGE_NAME="${SUBMISSION_ID}.zip"

echo "📦 Creating submission package..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
SUBMISSION_DIR="$TEMP_DIR/$SUBMISSION_ID"
mkdir -p "$SUBMISSION_DIR"

# Copy solution files
cp config.py "$SUBMISSION_DIR/"
cp test_config.py "$SUBMISSION_DIR/"
cp README.md "$SUBMISSION_DIR/"
cp .submission_metadata.json "$SUBMISSION_DIR/"

# Run a final validation and capture test output
echo "📊 Running final validation..."
python run_tests.py > "$SUBMISSION_DIR/test_results.txt" 2>&1 || true

# Add submission info
cat > "$SUBMISSION_DIR/submission_info.json" << EOF
{
    "submission_id": "$SUBMISSION_ID",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "user": {
        "github_username": "$GITHUB_USER",
        "github_email": "$GITHUB_EMAIL"
    },
    "environment": {
        "python_version": "$(python3 --version 2>&1)",
        "platform": "$(uname -s)"
    },
    "task_info": {
        "type": "software_engineering",
        "category": "logging_configuration",
        "difficulty": "easy",
        "language": "python"
    }
}
EOF

# Create a summary of changes
cat > "$SUBMISSION_DIR/solution_summary.md" << EOF
# Solution Summary

## Problem
Fixed PyDICOM library logging configuration to follow Python best practices.

## Key Changes Made
- Modified the debug() function to accept default_handler parameter
- Implemented conditional StreamHandler addition based on default_handler flag
- Maintained backward compatibility with existing debug functionality
- Ensured only NullHandler is added by default (library best practice)

## Files Modified
- config.py: Main configuration file with logging fixes

## Test Results
See test_results.txt for detailed test execution results.
EOF

# Create zip file
cd "$TEMP_DIR"
zip -r "$PACKAGE_NAME" "$SUBMISSION_ID" > /dev/null

# Submit to API
echo "🚀 Submitting to evaluation server..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $SUBMISSION_API_KEY" \
    -H "X-GitHub-User: $GITHUB_USER" \
    -F "file=@$PACKAGE_NAME" \
    -F "task_id=$(jq -r .task_id < $SUBMISSION_DIR/.submission_metadata.json)" \
    -F "user_id=$GITHUB_USER" \
    -F "task_type=software_engineering" \
    "$SUBMISSION_API_URL/submit")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | head -n-1)

# Clean up
rm -rf "$TEMP_DIR"

# Check response
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "✅ Submission successful!"
    echo ""
    echo "📋 Submission Details:"
    echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    echo ""
    echo "🎉 Your logging configuration fix has been submitted!"
    echo "You will receive feedback once the code review is complete."
    echo ""
    echo "📈 What was evaluated:"
    echo "   - Correct implementation of debug() function"
    echo "   - Proper use of NullHandler by default"
    echo "   - Conditional StreamHandler addition"
    echo "   - Python logging best practices compliance"
    echo "   - Test suite execution"
else
    echo "❌ Submission failed!"
    echo "HTTP Status: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    echo ""
    echo "Please check your solution and try again."
    echo "If the problem persists, contact support."
    exit 1
fi