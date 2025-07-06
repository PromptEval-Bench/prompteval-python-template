#!/bin/bash
# Algorithm Challenge Submission Script

set -e  # Exit on error

echo "📤 Preparing to submit your solution..."

# Check if required files exist
required_files=("solution.py")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Error: $file not found!"
        echo "Please implement your solution first."
        exit 1
    fi
done

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

# Run basic validation
echo "🔍 Validating solution..."
python3 << 'EOF'
import sys
import importlib.util

try:
    # Import the solution
    spec = importlib.util.spec_from_file_location("solution", "solution.py")
    solution = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(solution)
    
    # Check if minimumWeight function exists
    if not hasattr(solution, 'minimumWeight'):
        print("❌ Error: minimumWeight function not found in solution.py")
        sys.exit(1)
    
    # Test basic functionality
    edges = [[0,1,2],[1,2,3]]
    queries = [[0,1,2]]
    
    result = solution.minimumWeight(edges, queries)
    
    if not isinstance(result, list):
        print("❌ Error: minimumWeight should return a list")
        sys.exit(1)
    
    if len(result) != len(queries):
        print("❌ Error: Result length should match number of queries")
        sys.exit(1)
    
    print("✅ Basic validation passed")
    
except Exception as e:
    print(f"❌ Error validating solution: {e}")
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo "Please fix the issues and try again."
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
cp .submission_metadata.json "$SUBMISSION_DIR/"

# Copy additional files if they exist
for file in test_solution.py *.py; do
    if [ -f "$file" ] && [ "$file" != "solution.py" ]; then
        cp "$file" "$SUBMISSION_DIR/" 2>/dev/null || true
    fi
done

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
    "task_type": "graph_algorithms",
    "files_included": ["solution.py"]
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
    echo "Your graph algorithm solution has been submitted for evaluation."
    echo "The algorithms community thanks you for your contribution! 🌳"
else
    echo "❌ Submission failed!"
    echo "HTTP Status: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    echo ""
    echo "Please check your solution and try again."
    echo "If the problem persists, contact the development team."
    exit 1
fi