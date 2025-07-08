#!/bin/bash
# Profit Optimization Engine Initialization Script

set -e # Exit immediately if a command exits with a non-zero status.

echo "🚀 Initializing Quantitative Strategy Challenge: Profit Optimization..."

# --- 1. Basic Setup ---
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y jq curl bc > /dev/null 2>&1
CONFIG_DIR="config"
TEMPLATE_DIR="templates"

# --- 2. Rule-Based Parameter Generation ---
ARRAY_LENGTH=$((RANDOM % 151 + 50))      # 50-200
M_MIN_LENGTH=$((RANDOM % 5 + 1))         # 1-5
# Ensure k is solvable: k <= floor(array_length / m_min_length)
MAX_K=$(echo "$ARRAY_LENGTH / $M_MIN_LENGTH" | bc)
if [ "$MAX_K" -lt 2 ]; then MAX_K=2; fi
if [ "$MAX_K" -gt 10 ]; then MAX_K=10; fi
K_SUBARRAYS=$((RANDOM % (MAX_K - 1) + 2)) # 2-MAX_K
PROFIT_MIN=-100
PROFIT_MAX=100
CURRENT_DATE=$(date +%Y-%m-%d)

echo "📊 Generated Task Parameters:"
echo "   - Forecast Period (days): $ARRAY_LENGTH"
echo "   - Project Batches (k): $K_SUBARRAYS"
echo "   - Min Duration (m): $M_MIN_LENGTH"

# --- 3. LLM-Driven Content Generation (with Fallbacks) ---
if [ ! -z "$LLM_API_URL" ] && [ ! -z "$LLM_API_KEY" ]; then
    echo "🤖 Generating dynamic narrative content with LLM..."
    # A helper function for LLM calls to reduce repetition
    call_llm() {
        local prompt="$1"
        local max_tokens="$2"
        local temperature="$3"
        local fallback="$4"
        local response
        response=$(curl -s -X POST "$LLM_API_URL" \
            -H "Authorization: Bearer $LLM_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"model\": \"gpt-4o-mini\", \"prompt\": \"$prompt\", \"max_tokens\": $max_tokens, \"temperature\": $temperature}" | jq -r '.choices[0].text' | tr -d '\n' | xargs)
        echo "${response:-$fallback}"
    }
    COMPANY_NAME=$(call_llm "Generate a realistic name for a quantitative finance firm. Return only the name." 20 0.8 "QuantEdge Capital")
    FUNCTION_NAME=$(call_llm "Create a Python function name for calculating max sum of k non-overlapping subarrays. Examples: maximize_portfolio_return, optimize_batch_selection. Return only the name." 15 0.6 "maximize_profit_schedule")
    DATA_UNIT=$(call_llm "Generate a unit for daily financial data. Examples: 'daily profit in thousands USD', 'projected daily returns'. Return only the unit name." 10 0.5 "projected daily returns")
    SCENARIO_PROMPT="You are a senior quantitative strategist at ${COMPANY_NAME}. Your team is analyzing a series of daily profit/loss projections to optimize investment strategies. The goal is to identify the best combination of project batches to maximize total return."
    SCENARIO_CONTEXT=$(call_llm "$SCENARIO_PROMPT" 150 0.7 "Default scenario: Your mission is to optimize profits.")
else
    echo "⚠️ LLM API credentials not found. Using fallback content."
    COMPANY_NAME="QuantEdge Capital"
    FUNCTION_NAME="maximize_profit_schedule"
    DATA_UNIT="projected daily returns"
    SCENARIO_CONTEXT="You are a senior quantitative strategist at ${COMPANY_NAME}. Your team is analyzing a series of daily profit/loss projections to optimize investment strategies. The goal is to identify the best combination of project batches to maximize total return."
fi

echo "🏢 Company: $COMPANY_NAME"
echo "🔧 Function: $FUNCTION_NAME"

# --- 4. Data Generation ---
echo "🔧 Generating profit projection data (nums array)..."
# Use Python to generate the random array `nums`
PROFIT_ARRAY_JSON=$(python3 -c "import json, random; print(json.dumps([random.randint($PROFIT_MIN, $PROFIT_MAX) for _ in range($ARRAY_LENGTH)]))")

# Create task_data.json for the user
cat > task_data.json << EOF
{
  "company_name": "$COMPANY_NAME",
  "nums": $PROFIT_ARRAY_JSON,
  "k": $K_SUBARRAYS,
  "m": $M_MIN_LENGTH
}
EOF

# --- 5. Create Backend-Facing Solution Key ---
# This file contains all dynamic parameters needed for the backend to evaluate the submission.
# The backend will use these parameters to run its own trusted solver and compare results.
echo "🔑 Generating backend solution key..."
cat > .solution_key.json << EOF
{
  "taskId": "SDE-HARD-001-$(date +%s)",
  "base_task_id": "SDE-HARD-001",
  "ground_truth_params": {
    "nums": $PROFIT_ARRAY_JSON,
    "k": $K_SUBARRAYS,
    "m": $M_MIN_LENGTH
  },
  "evaluation_interfaces": {
    "main_function_to_test": "$FUNCTION_NAME"
  }
}
EOF
echo "✅ Generated profit data and solution key."

# --- 6. Template Processing ---
echo "📝 Processing templates into final task files..."
# Escape variables for sed
escape_sed() {
    echo "$1" | sed -e 's/[\/&]/\\&/g'
}
COMPANY_NAME_ESCAPED=$(escape_sed "$COMPANY_NAME")
SCENARIO_CONTEXT_ESCAPED=$(escape_sed "$SCENARIO_CONTEXT")
FUNCTION_NAME_ESCAPED=$(escape_sed "$FUNCTION_NAME")
DATA_UNIT_ESCAPED=$(escape_sed "$DATA_UNIT")

# Process README.md
sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{scenario_context}}/$SCENARIO_CONTEXT_ESCAPED/g" \
    -e "s/{{k_subarrays}}/$K_SUBARRAYS/g" \
    -e "s/{{m_min_length}}/$M_MIN_LENGTH/g" \
    -e "s/{{function_name}}/$FUNCTION_NAME_ESCAPED/g" \
    -e "s/{{data_unit}}/$DATA_UNIT_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

# Process starter code
sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{function_name}}/$FUNCTION_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > solution.py

# --- 7. Finalization ---
# Copy other necessary scripts and config
cp "$TEMPLATE_DIR/requirements.txt" .
mkdir -p scripts
cp "$TEMPLATE_DIR/submit.sh" scripts/
chmod +x scripts/submit.sh

# Clean up template directory
rm -rf "$TEMPLATE_DIR"
rm -rf "$CONFIG_DIR" 2>/dev/null || true

echo ""
echo "✅ Quantitative Strategy Challenge Initialized!"
echo ""
echo "--- NEXT STEPS ---"
echo "1. Read the mission brief in README.md"
echo "2. Implement the '$FUNCTION_NAME' function in solution.py"
echo "3. Test your implementation by running: python solution.py"
echo "4. Submit your final algorithm using: ./scripts/submit.sh"
echo "--------------------"
echo ""
echo "Good luck, strategist."