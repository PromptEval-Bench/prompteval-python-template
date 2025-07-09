#!/bin/bash
# User Mention Analytics Engine Initialization Script

set -e # Exit on error

echo "🚀 Initializing User Mention Analytics Challenge..."

# --- 1. Basic Setup ---
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y jq curl bc > /dev/null 2>&1
TEMPLATE_DIR="templates"

# --- 2. Rule-Based Parameter Generation ---
EMPLOYEE_COUNT=$((RANDOM % 41 + 10))       # 10-50 users
EVENT_COUNT=$((RANDOM % 61 + 20))        # 20-80 events
MAX_TIMESTAMP=$((RANDOM % 901 + 100))      # 100-1000
OFFLINE_DURATION=60
CURRENT_DATE=$(date +%Y-%m-%d)

echo "📊 Generated Task Parameters:"
echo "   - Employees: $EMPLOYEE_COUNT"
echo "   - Events: $EVENT_COUNT"
echo "   - Max Timestamp: $MAX_TIMESTAMP"

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
COMPANY_NAME=$(call_llm "Generate a name for a tech company." 20 0.8 "Innovate Corp")
PLATFORM_NAME=$(call_llm "Generate a name for a team chat app." 15 0.7 "SyncUp")
FUNCTION_NAME=$(call_llm "Create a Python function name for processing mention events." 15 0.6 "process_mention_events")

echo "🏢 Company: $COMPANY_NAME"
echo "🔧 Function: $FUNCTION_NAME"

# --- 4. Event Generation (using Python for complex logic) ---
echo "🔧 Generating a valid, sorted event log..."
# Python is better suited for generating a logically consistent event sequence
EVENT_DATA_JSON=$(python3 << EOF
import json
import random

EMPLOYEE_COUNT = $EMPLOYEE_COUNT
EVENT_COUNT = $EVENT_COUNT
MAX_TIMESTAMP = $MAX_TIMESTAMP
OFFLINE_DURATION = $OFFLINE_DURATION

events = []
# Tracks when a user comes back online. 0 means they are online.
user_online_again_at = [0] * EMPLOYEE_COUNT
current_timestamp = 0

for _ in range(EVENT_COUNT):
    current_timestamp += random.randint(1, MAX_TIMESTAMP // EVENT_COUNT + 1)
    
    # Decide event type
    if random.random() < 0.75: # 75% chance of MESSAGE
        event_type = "MESSAGE"
        
        # Generate mentions_string
        mention_type = random.choice(["ID", "ID", "ID", "ALL", "HERE"])
        if mention_type == "ID":
            num_mentions = random.randint(1, 5)
            mentions = [f"id{random.randint(0, EMPLOYEE_COUNT - 1)}" for _ in range(num_mentions)]
            payload = " ".join(mentions)
        elif mention_type == "ALL":
            payload = "ALL"
        else: # HERE
            payload = "HERE"
        
        events.append([event_type, str(current_timestamp), payload])
        
    else: # 25% chance of OFFLINE
        event_type = "OFFLINE"
        
        # Find users who are currently online
        online_users = [i for i, t in enumerate(user_online_again_at) if t <= current_timestamp]
        
        if online_users:
            user_to_go_offline = random.choice(online_users)
            user_online_again_at[user_to_go_offline] = current_timestamp + OFFLINE_DURATION
            events.append([event_type, str(current_timestamp), str(user_to_go_offline)])

# Ensure events are sorted by timestamp (though they are generated mostly in order)
events.sort(key=lambda x: int(x[1]))

task_data = {
    "numberOfUsers": EMPLOYEE_COUNT,
    "events": events
}
print(json.dumps(task_data))
EOF
)

# --- 5. Create Backend-Facing Solution Key ---
echo "🔑 Generating backend solution key..."
cat > .solution_key.json << EOF
{
  "taskId": "SWE-MEDIUM-001-$(date +%s)",
  "base_task_id": "SWE-MEDIUM-001",
  "ground_truth_params": $EVENT_DATA_JSON,
  "evaluation_interfaces": {
    "main_function_to_test": "$FUNCTION_NAME"
  }
}
EOF
# Create task_data.json for the user
echo "$EVENT_DATA_JSON" > task_data.json
echo "✅ Generated event log and solution key."

# --- 6. Template Processing ---
echo "📝 Processing templates..."
escape_sed() { echo "$1" | sed -e 's/[\/&]/\\&/g'; }
COMPANY_NAME_ESCAPED=$(escape_sed "$COMPANY_NAME")
PLATFORM_NAME_ESCAPED=$(escape_sed "$PLATFORM_NAME")
FUNCTION_NAME_ESCAPED=$(escape_sed "$FUNCTION_NAME")

sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{platform_name}}/$PLATFORM_NAME_ESCAPED/g" \
    -e "s/{{function_name}}/$FUNCTION_NAME_ESCAPED/g" \
    -e "s/{{employee_count}}/$EMPLOYEE_COUNT/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{platform_name}}/$PLATFORM_NAME_ESCAPED/g" \
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
echo "✅ User Mention Analytics Challenge Initialized!"
echo ""
echo "--- NEXT STEPS ---"
echo "1. Read the task description in README.md"
echo "2. Implement the '$FUNCTION_NAME' function in solution.py"
echo "3. Test your implementation by running: python solution.py"
echo "4. Submit your final code using: ./scripts/submit.sh"
echo "--------------------"