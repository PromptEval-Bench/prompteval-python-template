#!/bin/bash
# Universal Solution Submission Script

set -e # Exit on error

echo "📤 Preparing submission package..."

# --- Verification ---
if [ ! -f "submission.csv" ]; then
    echo "❌ Error: submission.csv not found. Please run your model to generate it first."
    exit 1
fi
if [ ! -f "starter_code.py" ]; then
    echo "❌ Error: starter_code.py not found. This file contains your model implementation."
    exit 1
fi

if [ -z "$SUBMISSION_API_URL" ] || [ -z "$SUBMISSION_API_KEY" ]; then
    echo "❌ Error: Submission API credentials are not configured in this environment."
    exit 1
fi

# --- Packaging ---
GITHUB_USER=${GITHUB_USER:-"anonymous"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TASK_ID="MLE-EASY-001" # Can be read from a metadata file if needed
SUBMISSION_ID="sub_${TASK_ID}_${GITHUB_USER}_${TIMESTAMP}"
PACKAGE_NAME="${SUBMISSION_ID}.zip"

echo "📦 Creating submission package: ${PACKAGE_NAME}"
zip -q "$PACKAGE_NAME" submission.csv starter_code.py README.md

# --- Submission ---
echo "🚀 Submitting to evaluation server: $SUBMISSION_API_URL"
# The rest of the submission logic from your previous examples would go here...
echo "✅ (Simulated) Submission successful."
echo "   Your package '$PACKAGE_NAME' is ready."

# --- Cleanup ---
rm -f "$PACKAGE_NAME"