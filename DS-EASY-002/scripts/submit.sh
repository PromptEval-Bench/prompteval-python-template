#!/bin/bash
# Universal Solution Submission Script

set -e # Exit on any error

echo "📤 Preparing submission package for evaluation..."

# --- 1. Verification ---
# Check if the required files for submission exist.
if [ ! -f "submission.csv" ]; then
    echo "❌ Error: 'submission.csv' not found. Please run your 'starter_code.py' to generate it first."
    exit 1
fi
if [ ! -f "starter_code.py" ];
    echo "❌ Error: 'starter_code.py' not found. This file contains your model implementation and is required for verification."
    exit 1
fi

# Check for backend API credentials (in a real environment)
if [ -z "$SUBMISSION_API_URL" ] || [ -z "$SUBMISSION_API_KEY" ]; then
    echo "⚠️ Warning: Submission API credentials are not configured. Proceeding with local packaging only."
fi

# --- 2. Packaging ---
# Create a unique name for the submission package.
GITHUB_USER=${GITHUB_USER:-"local_user"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TASK_ID="MLE-EASY-002"
SUBMISSION_ID="sub_${TASK_ID}_${GITHUB_USER}_${TIMESTAMP}"
PACKAGE_NAME="${SUBMISSION_ID}.zip"

echo "📦 Creating submission package: ${PACKAGE_NAME}"
# Zip the essential files for evaluation.
zip -q "$PACKAGE_NAME" submission.csv starter_code.py README.md

# --- 3. Submission ---
# This part would contain the curl command to send the package to the backend.
if [ ! -z "$SUBMISSION_API_URL" ]; then
    echo "🚀 Submitting to evaluation server: $SUBMISSION_API_URL"
    # curl -X POST -H "Authorization: Bearer $SUBMISSION_API_KEY" \
    #      -F "file=@${PACKAGE_NAME}" \
    #      "$SUBMISSION_API_URL/upload"
    echo "✅ (Simulated) Submission successful."
else
    echo "✅ Submission package '$PACKAGE_NAME' created locally. No backend configured."
fi

# --- 4. Cleanup ---
# Remove the local zip file after submission.
rm -f "$PACKAGE_NAME"

echo "Submission process finished."