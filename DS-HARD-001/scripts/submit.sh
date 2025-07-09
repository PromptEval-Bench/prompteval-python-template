#!/bin/bash
# Universal Solution Submission Script

set -e # Exit on error

echo "📤 Preparing submission package..."

# --- Verification ---
if [ ! -f "solution.py" ]; then
    echo "❌ Error: solution.py not found. This is the required file for your solution."
    exit 1
fi

if [ ! -f ".solution_key.json" ]; then
    echo "❌ Error: .solution_key.json not found. The task environment may be corrupted."
    exit 1
fi

if [ -z "$SUBMISSION_API_URL" ] || [ -z "$SUBMISSION_API_KEY" ]; then
    echo "❌ Error: Submission API credentials (SUBMISSION_API_URL, SUBMISSION_API_KEY) are not configured in this environment."
    exit 1
fi

# --- Packaging ---
GITHUB_USER=${GITHUB_USER:-"anonymous"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TASK_ID=$(jq -r .taskId .solution_key.json)
SUBMISSION_ID="sub_${TASK_ID}_${GITHUB_USER}_${TIMESTAMP}"
PACKAGE_NAME="${SUBMISSION_ID}.zip"

echo "📦 Creating submission package: ${PACKAGE_NAME}"

TEMP_DIR=$(mktemp -d)
SUBMISSION_DIR="$TEMP_DIR/$SUBMISSION_ID"
mkdir -p "$SUBMISSION_DIR"

# Copy essential files for evaluation
cp solution.py "$SUBMISSION_DIR/"
cp .solution_key.json "$SUBMISSION_DIR/" # The most important file for the backend
cp task_data.json "$SUBMISSION_DIR/" # For reference

# Create submission metadata
cat > "$SUBMISSION_DIR/submission_info.json" << EOF
{
    "submission_id": "$SUBMISSION_ID",
    "task_id": "$TASK_ID",
    "user": {
        "github_user": "$GITHUB_USER"
    },
    "submitted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "tool_versions": {
        "python": "$(python3 --version 2>&1)",
        "bash": "$(bash --version | head -n1)"
    }
}
EOF

# Create the zip archive
(cd "$TEMP_DIR" && zip -r "$PACKAGE_NAME" "$SUBMISSION_ID" > /dev/null)
mv "$TEMP_DIR/$PACKAGE_NAME" .

# --- Submission ---
echo "🚀 Submitting to evaluation server: $SUBMISSION_API_URL"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $SUBMISSION_API_KEY" \
    -H "X-User-ID: $GITHUB_USER" \
    -F "file=@$PACKAGE_NAME" \
    -F "task_id=$TASK_ID" \
    "$SUBMISSION_API_URL/submit")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | head -n-1)

# --- Cleanup and Result ---
rm -f "$PACKAGE_NAME"
rm -rf "$TEMP_DIR"

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "✅ Submission successful (HTTP $HTTP_CODE)."
    echo "--- Server Response ---"
    echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    echo "-----------------------"
    echo "Your solution is now queued for evaluation."
else
    echo "❌ Submission failed (HTTP $HTTP_CODE)."
    echo "--- Server Response ---"
    echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    echo "-----------------------"
    echo "Please review the error and try again. If the issue persists, contact an administrator."
    exit 1
fi