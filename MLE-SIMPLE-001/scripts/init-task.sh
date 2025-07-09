#!/bin/bash
# Data Stream Buffer Cleanup Initialization Script

set -e # Exit on error

echo "🚀 Initializing Data Stream Cleanup Challenge..."

# --- 1. Basic Setup ---
TEMPLATE_DIR="templates"

# --- 2. Rule-Based Parameter Generation ---
DATA_STREAM_LENGTH=$((RANDOM % 41 + 10))  # 10-50
MAX_DATA_VALUE=$((RANDOM % 41 + 10))      # 10-50
CURRENT_DATE=$(date +%Y-%m-%d)

echo "📊 Generated Task Parameters:"
echo "   - Initial Buffer Size: $DATA_STREAM_LENGTH"
echo "   - Max Data ID Value: $MAX_DATA_VALUE"

# --- 3. LLM-Driven Content Generation ---
call_llm() {
    local prompt="$1" max_tokens="$2" temp="$3" fallback="$4"
    if [ -z "$LLM_API_URL" ] || [ -z "$LLM_API_KEY" ]; then echo "$fallback"; return; fi
    local response
    response=$(curl -s -X POST "$LLM_API_URL" \
        -H "Authorization: Bearer $LLM_API_KEY" -H "Content-Type: application/json" \
        -d "{\"model\": \"gpt-4o-mini\", \"prompt\": \"$prompt\", \"max_tokens\": $max_tokens, \"temperature\": $temp}" | jq -r '.choices[0].text' | tr -d '\n' | xargs)
    echo "${response:-$fallback}"
}

echo "🤖 Generating dynamic narrative content..."
COMPANY_NAME=$(call_llm "Generate a name for a data processing company." 20 0.8 "Streamline Data")
DEVICE_NAME=$(call_llm "Generate a name for a networked sensor." 20 0.7 "Smart Meter v3")
FUNCTION_NAME=$(call_llm "Create a Python function name for calculating buffer cleanup operations." 15 0.6 "get_min_discard_ops")

echo "🏢 Company: $COMPANY_NAME"
echo "🔧 Function: $FUNCTION_NAME"

# --- 4. Data Generation ---
echo "🔧 Generating initial data buffer state..."
# Use Python to generate the random array `nums`
BUFFER_DATA_JSON=$(python3 -c "import json, random; print(json.dumps({'nums': [random.randint(1, $MAX_DATA_VALUE) for _ in range($DATA_STREAM_LENGTH)]}))")

# --- 5. Create Backend-Facing Solution Key & User-Facing Data ---
echo "🔑 Generating solution key and user data file..."
# The backend needs the same data to verify the solution.
cat > .solution_key.json << EOF
{
  "taskId": "SDE-EASY-002-$(date +%s)",
  "base_task_id": "SDE-EASY-002",
  "ground_truth_params": $BUFFER_DATA_JSON,
  "evaluation_interfaces": {
    "main_function_to_test": "$FUNCTION_NAME"
  }
}
EOF
# The user gets the same data in their task file.
echo "$BUFFER_DATA_JSON" > task_data.json
echo "✅ Generated data buffer and solution key."

# --- 6. Template Processing ---
echo "📝 Processing templates..."
escape_sed() { echo "$1" | sed -e 's/[\/&]/\\&/g'; }
COMPANY_NAME_ESCAPED=$(escape_sed "$COMPANY_NAME")
DEVICE_NAME_ESCAPED=$(escape_sed "$DEVICE_NAME")
FUNCTION_NAME_ESCAPED=$(escape_sed "$FUNCTION_NAME")

sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{device_name}}/$DEVICE_NAME_ESCAPED/g" \
    -e "s/{{function_name}}/$FUNCTION_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{device_name}}/$DEVICE_NAME_ESCAPED/g" \
    -e "s/{{function_name}}/$FUNCTION_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > solution.py

# --- 7. Finalization ---
cp "$TEMPLATE_DIR/requirements.txt" .
mkdir -p scripts
cp "$TEMPLATE_DIR/submit.sh" scripts/
chmod +x scripts/submit.sh
rm -rf "$TEMPLATE_DIR"

echo ""
echo "✅ Data Stream Cleanup Challenge Initialized!"
echo ""
echo "--- NEXT STEPS ---"
echo "1. Read the task description in README.md"
echo "2. Implement the '$FUNCTION_NAME' function in solution.py"
echo "3. Test your implementation by running: python solution.py"
echo "4. Submit your final code using: ./scripts/submit.sh"
echo "--------------------"