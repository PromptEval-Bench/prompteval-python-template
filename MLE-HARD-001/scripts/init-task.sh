#!/bin/bash
# Sensor Calibration Optimization Initialization Script

set -e # Exit on error

echo "🚀 Initializing Sensor Calibration Challenge..."

# --- 1. Basic Setup ---
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y jq curl bc > /dev/null 2>&1
TEMPLATE_DIR="templates"

# --- 2. Rule-Based Parameter Generation ---
SENSOR_COUNT=$((RANDOM % 9001 + 1000))       # 1000-10000
BATCH_SIZE=$((RANDOM % 91 + 10))            # 10-100
# Ensure k*x is possible
MAX_K=$(echo "$SENSOR_COUNT / $BATCH_SIZE" | bc)
if [ "$MAX_K" -lt 2 ]; then MAX_K=2; fi
if [ "$MAX_K" -gt 15 ]; then MAX_K=15; fi
NUM_BATCHES=$((RANDOM % (MAX_K - 1) + 2))    # 2-MAX_K
READING_MIN=-1000
READING_MAX=1000
CURRENT_DATE=$(date +%Y-%m-%d)

echo "📊 Generated Task Parameters:"
echo "   - Total Sensor Readings: $SENSOR_COUNT"
echo "   - Batch Size (x): $BATCH_SIZE"
echo "   - Batches to Calibrate (k): $NUM_BATCHES"

# --- 3. LLM-Driven Content Generation ---
# Helper function for cleaner LLM calls
call_llm() {
    local prompt="$1"
    local max_tokens="$2"
    local temperature="$3"
    local fallback="$4"
    if [ -z "$LLM_API_URL" ] || [ -z "$LLM_API_KEY" ]; then
        echo "$fallback"
        return
    fi
    local response
    response=$(curl -s -X POST "$LLM_API_URL" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"gpt-4o-mini\", \"prompt\": \"$prompt\", \"max_tokens\": $max_tokens, \"temperature\": $temperature}" | jq -r '.choices[0].text' | tr -d '\n' | xargs)
    echo "${response:-$fallback}"
}

echo "🤖 Generating dynamic narrative content..."
COMPANY_NAME=$(call_llm "Generate a name for a high-tech industrial automation company. Return only the name." 20 0.8 "Acuity Robotics")
FUNCTION_NAME=$(call_llm "Create a Python function name for minimizing sensor calibration cost. Examples: minimize_calibration_cost, optimize_sensor_alignment. Return only name." 15 0.6 "minimize_calibration_cost")
DATA_UNIT=$(call_llm "Generate a physical unit for a sensor reading. Examples: 'voltage (mV)', 'pressure (Pa)'. Return only unit name." 10 0.5 "voltage (mV)")
SCENARIO_PROMPT="You are a lead engineer at ${COMPANY_NAME}, a company specializing in industrial automation. A critical production line uses a large array of sensors, and their readings tend to drift. To ensure quality control, you must periodically recalibrate the sensors."
SCENARIO_CONTEXT=$(call_llm "$SCENARIO_PROMPT" 150 0.7 "Default scenario: Your mission is to optimize sensor calibration.")

echo "🏢 Company: $COMPANY_NAME"
echo "🔧 Function: $FUNCTION_NAME"

# --- 4. Data Generation ---
echo "🔧 Generating sensor reading data (nums array)..."
SENSOR_READINGS_JSON=$(python3 -c "import json, random; print(json.dumps([random.randint($READING_MIN, $READING_MAX) for _ in range($SENSOR_COUNT)]))")

# Create task_data.json for the user
cat > task_data.json << EOF
{
  "company_name": "$COMPANY_NAME",
  "nums": $SENSOR_READINGS_JSON,
  "x": $BATCH_SIZE,
  "k": $NUM_BATCHES
}
EOF

# --- 5. Create Backend-Facing Solution Key ---
echo "🔑 Generating backend solution key..."
cat > .solution_key.json << EOF
{
  "taskId": "MLE-HARD-001-$(date +%s)",
  "base_task_id": "MLE-HARD-001",
  "ground_truth_params": {
    "nums": $SENSOR_READINGS_JSON,
    "x": $BATCH_SIZE,
    "k": $NUM_BATCHES
  },
  "evaluation_interfaces": {
    "main_function_to_test": "$FUNCTION_NAME"
  }
}
EOF
echo "✅ Generated sensor data and solution key."

# --- 6. Template Processing ---
echo "📝 Processing templates..."
escape_sed() { echo "$1" | sed -e 's/[\/&]/\\&/g'; }
COMPANY_NAME_ESCAPED=$(escape_sed "$COMPANY_NAME")
SCENARIO_CONTEXT_ESCAPED=$(escape_sed "$SCENARIO_CONTEXT")
FUNCTION_NAME_ESCAPED=$(escape_sed "$FUNCTION_NAME")
DATA_UNIT_ESCAPED=$(escape_sed "$DATA_UNIT")

sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{scenario_context}}/$SCENARIO_CONTEXT_ESCAPED/g" \
    -e "s/{{num_batches_to_calibrate}}/$NUM_BATCHES/g" \
    -e "s/{{batch_size}}/$BATCH_SIZE/g" \
    -e "s/{{function_name}}/$FUNCTION_NAME_ESCAPED/g" \
    -e "s/{{data_unit}}/$DATA_UNIT_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
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
echo "✅ Sensor Calibration Challenge Initialized!"
echo ""
echo "--- NEXT STEPS ---"
echo "1. Read the mission brief in README.md"
echo "2. Implement the '$FUNCTION_NAME' function in solution.py"
echo "3. Test your implementation by running: python solution.py"
echo "4. Submit your final algorithm using: ./scripts/submit.sh"
echo "--------------------"