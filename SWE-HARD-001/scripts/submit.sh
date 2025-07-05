#!/bin/bash
# Solution Submission Script

set -e  # Exit on error

echo "📤 Preparing to submit your solution..."

# Check if required files exist
if [ ! -f "solution.py" ]; then
    echo "❌ Error: solution.py not found!"
    echo "Please implement your solution in solution.py"
    exit 1
fi

if [ ! -f ".submission_metadata.json" ]; then
    echo "❌ Error: Task metadata not found!"
    echo "This might not be a valid task workspace."
    exit 1
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
SUBMISSION_ID="submission_${TIMESTAMP}_${RANDOM}"
PACKAGE_NAME="${SUBMISSION_ID}.zip"

echo "📦 Creating submission package..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
SUBMISSION_DIR="$TEMP_DIR/$SUBMISSION_ID"
mkdir -p "$SUBMISSION_DIR"

# Copy solution files
cp solution.py "$SUBMISSION_DIR/"
cp input_data.json "$SUBMISSION_DIR/"
cp .submission_metadata.json "$SUBMISSION_DIR/"
cp .task_metadata.json "$SUBMISSION_DIR/" 2>/dev/null || true

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
    }
}
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
    echo "Your solution has been submitted for evaluation."
    echo "You will receive feedback once processing is complete."
else
    echo "❌ Submission failed!"
    echo "HTTP Status: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    echo ""
    echo "Please check your solution and try again."
    echo "If the problem persists, contact support."
    exit 1
fi