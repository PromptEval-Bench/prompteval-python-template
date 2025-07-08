#!/bin/bash
# Submission script for the pydicom codify bug fix task (SWE-HARD-001)

set -e # Exit immediately if a command exits with a non-zero status.

echo "📦 Preparing to submit your fix for pydicom issue #1674..."

# --- 1. Verification ---
# Check that the file the user is meant to edit exists.
if [ ! -f "codify.py" ]; then
    echo "❌ Error: 'codify.py' not found!"
    echo "   Please ensure you have saved your changes to the correct file."
    exit 1
fi

# Check that the task metadata file exists. This is crucial for the backend.
if [ ! -f ".solution_key.json" ]; then
    echo "❌ Error: Task metadata file (.solution_key.json) not found."
    echo "   The workspace may be corrupted. Please contact an administrator."
    exit 1
fi

# Check for essential environment variables provided by the framework.
if [ -z "$SUBMISSION_API_URL" ] || [ -z "$SUBMISSION_API_KEY" ]; then
    echo "❌ Error: Submission API credentials are not configured in this environment."
    echo "   Please ensure you are running within the provided Codespace."
    exit 1
fi

# --- 2. Packaging ---
# Get user info from git config, with a fallback.
GITHUB_USER=${GITHUB_USER:-"anonymous"}
# Extract the unique task ID from the metadata file.
TASK_ID=$(jq -r .taskId .solution_key.json)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

SUBMISSION_ID="sub_${TASK_ID}_${GITHUB_USER}_${TIMESTAMP}"
PACKAGE_NAME="${SUBMISSION_ID}.zip"

echo "   - Submission ID: ${SUBMISSION_ID}"
echo "   - Creating submission package: ${PACKAGE_NAME}"

# Create a temporary directory for clean packaging.
TEMP_DIR=$(mktemp -d)
SUBMISSION_DIR="$TEMP_DIR/$SUBMISSION_ID"
mkdir -p "$SUBMISSION_DIR"

# Copy the essential files for evaluation into the submission directory.
cp codify.py "$SUBMISSION_DIR/"          # The user's modified code.
cp .solution_key.json "$SUBMISSION_DIR/" # The file identifying the task.

# Create a metadata file about this specific submission.
cat > "$SUBMISSION_DIR/submission_info.json" << EOF
{
    "submission_id": "$SUBMISSION_ID",
    "task_id": "$TASK_ID",
    "user": {
        "github_user": "$GITHUB_USER"
    },
    "submitted_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "tool_versions": {
        "python": "$(python3 --version 2>&1)",
        "pydicom": "$(pip show pydicom | grep Version | awk '{print $2}')"
    }
}
EOF

# Create the zip archive quietly.
(cd "$TEMP_DIR" && zip -qr "$PACKAGE_NAME" "$SUBMISSION_ID")
# Move the final zip file to the current directory.
mv "$TEMP_DIR/$PACKAGE_NAME" .

# --- 3. Submission ---
echo "🚀 Uploading your solution to the evaluation server..."

# Use curl to POST the file to the backend API.
# The -w "\n%{http_code}" trick appends the HTTP status code to the output.
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $SUBMISSION_API_KEY" \
    -H "X-User-ID: $GITHUB_USER" \
    -F "file=@$PACKAGE_NAME" \
    -F "task_id=$TASK_ID" \
    "$SUBMISSION_API_URL/submit")

# Extract the HTTP status code and the response body.
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | head -n-1)

# --- 4. Cleanup and Result ---
# Clean up the temporary directory and the local zip file.
rm -rf "$TEMP_DIR"
rm -f "$PACKAGE_NAME"

# Check the server's response code.
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "✅ Submission successful (HTTP Status: $HTTP_CODE)."
    echo ""
    echo "--- Server Response ---"
    # Pretty-print the JSON response if jq is available, otherwise just print it.
    echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    echo "-----------------------"
    echo "Your fix for pydicom-1674 has been submitted for automated evaluation."
else
    echo "❌ Submission failed (HTTP Status: $HTTP_CODE)."
    echo ""
    echo "--- Server Response ---"
    echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    echo "-----------------------"
    echo "Please review the error and try again. If the issue persists, contact an administrator."
    exit 1
fi