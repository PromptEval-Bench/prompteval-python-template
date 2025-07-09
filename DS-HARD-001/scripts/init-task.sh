#!/bin/bash
# Generic Task Initialization Engine

set -e
set -o pipefail

# --- 1. Setup Environment and Paths ---
echo "🚀 Initializing Task Environment..."
cd "$(dirname "$0")/.." # Ensure execution from project root

# Install necessary tools quietly
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y jq curl > /dev/null 2>&1

CONFIG_DIR="config"
TEMPLATE_DIR="template"

# --- 2. Load Configurations ---
PARAMS_JSON=$(cat "$CONFIG_DIR/dynamic_params.json")
META_JSON=$(cat "$CONFIG_DIR/task_metadata.json")

# --- 3. Generate Rule-Based Parameters ---
echo "📊 Generating Rule-Based Parameters..."
declare -A rule_params
for key in $(echo "$PARAMS_JSON" | jq -r '.rule_based_params | keys[]'); do
    min=$(echo "$PARAMS_JSON" | jq -r ".rule_based_params.$key.min")
    max=$(echo "$PARAMS_JSON" | jq -r ".rule_based_params.$key.max")
    rule_params[$key]=$((RANDOM % (max - min + 1) + min))
    echo "   - $key: ${rule_params[$key]}"
done

# --- 4. Generate System Parameters ---
declare -A system_params
for key in $(echo "$PARAMS_JSON" | jq -r '.system_params | keys[]'); do
    format=$(echo "$PARAMS_JSON" | jq -r ".system_params.$key.format")
    system_params[$key]=$(date +"$format")
    echo "   - $key: ${system_params[$key]}"
done

# --- 5. Generate LLM-Driven Variations ---
echo "🤖 Generating LLM-Driven Content..."
declare -A llm_params

# Helper function for LLM calls
call_llm() {
    local prompt="$1"
    local max_tokens="$2"
    local temperature="$3"
    local fallback="$4"
    if [ -z "$LLM_API_URL" ] || [ -z "$LLM_API_KEY" ]; then echo "$fallback"; return; fi
    local response
    response=$(curl -s -X POST "$LLM_API_URL" \
        -H "Authorization: Bearer $LLM_API_KEY" -H "Content-Type: application/json" \
        -d "{\"model\": \"gpt-4o-mini\", \"prompt\": \"$prompt\", \"max_tokens\": $max_tokens, \"temperature\": $temperature}" | jq -r '.choices[0].text' | tr -d '\n' | xargs)
    echo "${response:-$fallback}"
}

# Process LLM variations in order, allowing later prompts to use earlier results
for key in $(echo "$PARAMS_JSON" | jq -r '.llm_variations | keys[]'); do
    prompt=$(echo "$PARAMS_JSON" | jq -r ".llm_variations.$key.prompt")
    max_tokens=$(echo "$PARAMS_JSON" | jq -r ".llm_variations.$key.max_tokens")
    temperature=$(echo "$PARAMS_JSON" | jq -r ".llm_variations.$key.temperature")
    
    # Substitute variables in prompt
    for var_key in "${!llm_params[@]}"; do
        prompt="${prompt//\{$var_key\}/${llm_params[$var_key]}}"
    done

    echo "   - Generating '$key'..."
    llm_params[$key]=$(call_llm "$prompt" "$max_tokens" "$temperature" "Default $key")
    echo "     ...Done: ${llm_params[$key]}"
done

# --- 6. Data Generation ---
echo "🔧 Generating large-scale transaction data..."
TRANSACTION_VALUES_JSON=$(python3 -c "import json, random; print(json.dumps([random.randint(1, ${rule_params[max_transaction_value]}) for _ in range(${rule_params[transaction_count]})]))")

# Create task_data.json for the user
cat > task_data.json << EOF
{
  "company_name": "${llm_params[company_name]}",
  "transaction_values": $TRANSACTION_VALUES_JSON,
  "window_size": ${rule_params[window_size]},
  "top_segments": ${rule_params[top_segments]}
}
EOF

# --- 7. Create Backend-Facing Solution Key ---
echo "🔑 Generating backend solution key..."
BASE_TASK_ID=$(echo $META_JSON | jq -r .task_id)
cat > .solution_key.json << EOF
{
  "taskId": "${BASE_TASK_ID}-$(date +%s)",
  "base_task_id": "$BASE_TASK_ID",
  "ground_truth_params": {
    "nums": $TRANSACTION_VALUES_JSON,
    "k": ${rule_params[window_size]},
    "x": ${rule_params[top_segments]}
  },
  "evaluation_interfaces": {
    "main_function_to_test": "${llm_params[function_name]}"
  }
}
EOF
echo "✅ Generated all necessary data and key files."

# --- 8. Template Processing ---
echo "📝 Processing templates with dynamic content..."
# Start with the template file content
template_content=$(cat "$TEMPLATE_DIR/README.md.template")
# Combine all parameter maps for substitution
declare -A all_params
all_params=( "${rule_params[@]}" "${system_params[@]}" "${llm_params[@]}" )
# Loop and substitute
for key in "${!all_params[@]}"; do
    template_content="${template_content//\{\{$key\}\}/${all_params[$key]}}"
done
echo "$template_content" > README.md

# Process starter code template
starter_code_content=$(cat "$TEMPLATE_DIR/starter_code.py.template")
for key in "${!all_params[@]}"; do
    starter_code_content="${starter_code_content//\{\{$key\}\}/${all_params[$key]}}"
done
echo "$starter_code_content" > solution.py

# --- 9. Finalization ---
cp "$TEMPLATE_DIR/requirements.txt" .
chmod +x scripts/submit.sh
# Clean up config and template directories
rm -rf "$TEMPLATE_DIR"
rm -rf "$CONFIG_DIR"

echo ""
echo "✅ Task Environment Initialized Successfully!"
echo ""
echo "--- NEXT STEPS ---"
echo "1. Read the project brief in README.md"
echo "2. Implement the '${llm_params[function_name]}' function in solution.py"
echo "3. Test your implementation locally by running: python3 solution.py"
echo "4. Submit your final algorithm using: ./scripts/submit.sh"
echo "--------------------"