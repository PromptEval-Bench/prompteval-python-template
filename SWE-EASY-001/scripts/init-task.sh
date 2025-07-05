#!/bin/bash
# Employee ID Validation System Initialization Script

set -e  # Exit on error

echo "🚀 Initializing Employee ID Validation Challenge..."

# Basic setup
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y bc jq curl > /dev/null 2>&1

# Load configuration
CONFIG_DIR="config"
TEMPLATE_DIR="template"

# Generate random parameters
ARRAY_LENGTH=$((RANDOM % 21 + 5))        # 5-25 employees
MAX_EMPLOYEE_ID=$((RANDOM % 900 + 100))  # 100-999
MAX_ARRAY_LENGTH=$((RANDOM % 51 + 50))   # 50-100
VALIDATION_THRESHOLD=$((RANDOM % 5 + 1)) # 1-5
VALID_SOLUTION_PROB=$(echo "scale=2; ($RANDOM % 51 + 30) / 100" | bc)  # 0.30-0.80

echo "📊 Generated parameters:"
echo "   - Employees: $ARRAY_LENGTH"  
echo "   - Max ID: $MAX_EMPLOYEE_ID"
echo "   - Solution probability: $VALID_SOLUTION_PROB"

# Generate current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Call LLM for dynamic content (with fallbacks)
if [ ! -z "$LLM_API_URL" ] && [ ! -z "$LLM_API_KEY" ]; then
    echo "🤖 Generating dynamic content with LLM..."
    
    # Generate company name
    COMPANY_NAME=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Generate a realistic company name related to security or employee management. Return only the name.",
            "max_tokens": 20,
            "temperature": 0.8
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs || echo "SecureID Systems")
    
    # Generate function name
    FUNCTION_NAME=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo", 
            "prompt": "Create a function name for finding index where digit sum equals index. Examples: find_validation_index, locate_matching_index. Return only function name.",
            "max_tokens": 15,
            "temperature": 0.6
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs || echo "find_digit_sum_index")
    
    # Generate scenario
    SCENARIO_PROMPT="Write a 2-3 sentence scenario about $COMPANY_NAME implementing a new employee ID validation system for $ARRAY_LENGTH employees."
    COMPANY_SCENARIO=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"prompt\": \"$SCENARIO_PROMPT\",
            \"max_tokens\": 120,
            \"temperature\": 0.7
        }" | jq -r '.choices[0].text' | tr '\n' ' ' | xargs || echo "Default scenario")
    
    # Generate security level
    SECURITY_LEVEL=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Generate a security level name (e.g., Enhanced, Level-2, Tier-A). Return only the level.",
            "max_tokens": 10,
            "temperature": 0.5
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs || echo "Standard")
else
    echo "⚠️  LLM not available, using fallback content..."
    COMPANY_NAME="SecureID Systems"
    FUNCTION_NAME="find_digit_sum_index"
    SECURITY_LEVEL="Enhanced"
    COMPANY_SCENARIO="$COMPANY_NAME is implementing a new digital employee ID validation system across all $ARRAY_LENGTH employees. The security protocol requires mathematical verification to ensure system integrity."
fi

# Escape for sed
COMPANY_NAME_ESCAPED=$(echo "$COMPANY_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
COMPANY_SCENARIO_ESCAPED=$(echo "$COMPANY_SCENARIO" | sed 's/[[\.*^$()+?{|]/\\&/g')
FUNCTION_NAME_ESCAPED=$(echo "$FUNCTION_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
SECURITY_LEVEL_ESCAPED=$(echo "$SECURITY_LEVEL" | sed 's/[[\.*^$()+?{|]/\\&/g')

echo "🏢 Company: $COMPANY_NAME"
echo "🔧 Function: $FUNCTION_NAME"

# Setup environment
echo "📦 Setting up environment..."
cp "$TEMPLATE_DIR/requirements.txt" requirements.txt
pip install -r requirements.txt > /dev/null 2>&1

# Generate employee data
echo "🔧 Generating employee data..."

python3 << EOF
import json
import random

# Parameters
array_length = $ARRAY_LENGTH
max_id = $MAX_EMPLOYEE_ID
valid_prob = $VALID_SOLUTION_PROB

# Generate employee IDs
employee_ids = []

# Strategy: occasionally place numbers that satisfy the condition
for i in range(array_length):
    if random.random() < valid_prob and i > 0:
        # Try to create a valid number for this index
        # We need sum of digits = i
        if i <= 9:
            employee_ids.append(i)
        elif i <= 18:
            # Use two digits that sum to i
            first_digit = random.randint(1, min(9, i-1))
            second_digit = i - first_digit
            if second_digit <= 9:
                employee_ids.append(first_digit * 10 + second_digit)
            else:
                employee_ids.append(random.randint(1, max_id))
        else:
            # For larger sums, create multi-digit numbers
            digits_needed = []
            remaining = i
            while remaining > 0 and len(digits_needed) < 3:
                digit = min(9, remaining)
                digits_needed.append(digit)
                remaining -= digit
            
            if remaining == 0:
                # Create number from digits
                number = 0
                for d in digits_needed:
                    number = number * 10 + d
                if number <= max_id:
                    employee_ids.append(number)
                else:
                    employee_ids.append(random.randint(1, max_id))
            else:
                employee_ids.append(random.randint(1, max_id))
    else:
        employee_ids.append(random.randint(1, max_id))

# Create a sample array for display (first few elements)
sample_array = ", ".join(map(str, employee_ids[:min(5, len(employee_ids))]))
if len(employee_ids) > 5:
    sample_array += ", ..."

# Save employee data
data = {
    "employee_ids": employee_ids,
    "company_name": "$COMPANY_NAME",
    "validation_threshold": $VALIDATION_THRESHOLD
}

with open('employee_data.json', 'w') as f:
    json.dump(data, f, indent=2)

# Calculate if solution exists
solution_exists = False
solution_index = -1
for i, emp_id in enumerate(employee_ids):
    digit_sum = sum(int(digit) for digit in str(emp_id))
    if digit_sum == i:
        solution_exists = True
        solution_index = i
        break

# Save metadata
metadata = {
    "array_length": array_length,
    "max_employee_id": max_id,
    "solution_exists": solution_exists,
    "solution_index": solution_index,
    "sample_array": sample_array
}

with open('.task_metadata.json', 'w') as f:
    json.dump(metadata, f, indent=2)

print(f"✅ Generated {array_length} employee IDs")
print(f"   - Solution exists: {solution_exists}")
if solution_exists:
    print(f"   - Solution at index: {solution_index}")
EOF

# Get generated metadata
SAMPLE_ARRAY=$(jq -r '.sample_array' .task_metadata.json)

# Process templates
echo "📝 Processing templates..."

# Process README.md
sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{company_scenario}}/$COMPANY_SCENARIO_ESCAPED/g" \
    -e "s/{{array_length}}/$ARRAY_LENGTH/g" \
    -e "s/{{max_array_length}}/$MAX_ARRAY_LENGTH/g" \
    -e "s/{{max_employee_id}}/$MAX_EMPLOYEE_ID/g" \
    -e "s/{{validation_threshold}}/$VALIDATION_THRESHOLD/g" \
    -e "s/{{function_name}}/$FUNCTION_NAME_ESCAPED/g" \
    -e "s/{{security_level}}/$SECURITY_LEVEL_ESCAPED/g" \
    -e "s/{{sample_array}}/$SAMPLE_ARRAY/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

# Process starter code
sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{function_name}}/$FUNCTION_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > solution.py

# Create test file
cat > test_solution.py << EOF
#!/usr/bin/env python3
"""
Test suite for Employee ID Validation System
"""

import json
from solution import ${FUNCTION_NAME}, calculate_digit_sum, load_employee_data, validate_solution


def test_digit_sum():
    """Test the digit sum calculation function."""
    print("🧪 Testing digit sum calculation...")
    
    test_cases = [
        (0, 0),
        (5, 5), 
        (10, 1),
        (123, 6),
        (999, 27)
    ]
    
    for number, expected in test_cases:
        result = calculate_digit_sum(number)
        assert result == expected, f"calculate_digit_sum({number}) = {result}, expected {expected}"
        print(f"   ✓ {number} -> {result}")
    
    print("✅ Digit sum tests passed!")


def test_main_function():
    """Test the main solution function."""
    print("🧪 Testing main solution function...")
    
    # Load actual data
    data = load_employee_data()
    employee_ids = data['employee_ids']
    
    print(f"📊 Testing with {len(employee_ids)} employee IDs")
    
    # Run solution
    result = ${FUNCTION_NAME}(employee_ids)
    print(f"   Result: {result}")
    
    # Validate solution
    is_valid = validate_solution(employee_ids, result)
    print(f"   Validation: {'✅ PASS' if is_valid else '❌ FAIL'}")
    
    # Additional test cases
    test_cases = [
        ([1, 3, 2], 2),      # Example 1
        ([1, 10, 11], 1),    # Example 2  
        ([1, 2, 3], -1),     # Example 3
        ([0], 0),            # Single element match
        ([5], -1),           # Single element no match
    ]
    
    for test_input, expected in test_cases:
        result = ${FUNCTION_NAME}(test_input)
        assert result == expected, f"Input {test_input}: got {result}, expected {expected}"
        print(f"   ✓ {test_input} -> {result}")
    
    print("✅ All tests passed!")


if __name__ == "__main__":
    test_digit_sum()
    print()
    test_main_function()
EOF
chmod +x test_solution.py

# Create submission metadata
cat > .submission_metadata.json << EOF
{
    "task_id": "DIGIT-SUM-$(date +%s)",
    "generation_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "parameters": {
        "array_length": $ARRAY_LENGTH,
        "max_employee_id": $MAX_EMPLOYEE_ID,
        "function_name": "$FUNCTION_NAME",
        "company": "$COMPANY_NAME"
    }
}
EOF

# Clean up templates
rm -rf "$TEMPLATE_DIR"
rm -rf "$CONFIG_DIR"

echo ""
echo "✅ Employee ID Validation System initialized!"
echo ""
echo "📋 Next steps:"
echo "   1. Read the problem description in README.md"
echo "   2. Review the employee data in employee_data.json"
echo "   3. Implement the $FUNCTION_NAME function in solution.py"
echo "   4. Test with: python test_solution.py"
echo "   5. Submit with: ./scripts/submit.sh"
echo ""
echo "🔒 Security clearance approved. Good luck! 🍀"