#!/bin/bash
# Graph Algorithms Task Initialization Script

set -e  # Exit on error

echo "🚀 Initializing Minimum Weighted Subgraph Challenge..."

# Basic setup
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y bc jq curl > /dev/null 2>&1

# Load configuration
CONFIG_DIR="config"
TEMPLATE_DIR="template"

# Generate random parameters
RANDOM_SEED=$((RANDOM % 59 + 42))  # 42-100

echo "📊 Generated parameters:"
echo "   - Random seed: $RANDOM_SEED"

# Generate current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Call LLM for dynamic content (with fallbacks)
if [ ! -z "$LLM_API_URL" ] && [ ! -z "$LLM_API_KEY" ]; then
    echo "🤖 Generating dynamic content with LLM..."
    
    # Generate library name
    LIBRARY_NAME=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Generate a professional name for a graph algorithms library. Examples: GraphOptim, TreeSolver, PathFinder. Return only the name.",
            "max_tokens": 15,
            "temperature": 0.7
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs || echo "GraphOptim")
    
    # Generate algorithm approach
    ALGORITHM_APPROACH=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest a high-level algorithmic approach for finding minimum weight subtrees connecting three nodes. One technical sentence.",
            "max_tokens": 80,
            "temperature": 0.6
        }' | jq -r '.choices[0].text' | tr '\n' ' ' | xargs || echo "Find the union of paths from both sources to destination, optimizing for minimal edge overlap.")
    
    # Generate optimization technique
    OPTIMIZATION_TECHNIQUE=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest one optimization technique for multiple tree path queries. Examples: LCA preprocessing, dynamic programming. Return technique name only.",
            "max_tokens": 15,
            "temperature": 0.5
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs || echo "LCA preprocessing")
    
    # Generate key insight
    KEY_INSIGHT=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Provide one key insight for minimum weighted subtree problems on trees. Focus on structural properties. One sentence.",
            "max_tokens": 60,
            "temperature": 0.4
        }' | jq -r '.choices[0].text' | tr '\n' ' ' | xargs || echo "The optimal subtree consists of the union of unique paths from sources to destination, minimizing redundant edges.")
else
    echo "⚠️  LLM not available, using fallback content..."
    LIBRARY_NAME="GraphOptim"
    ALGORITHM_APPROACH="Find the union of paths from both sources to destination, optimizing for minimal edge overlap."
    OPTIMIZATION_TECHNIQUE="LCA preprocessing"
    KEY_INSIGHT="The optimal subtree consists of the union of unique paths from sources to destination, minimizing redundant edges."
fi

# Escape for sed
LIBRARY_NAME_ESCAPED=$(echo "$LIBRARY_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
ALGORITHM_APPROACH_ESCAPED=$(echo "$ALGORITHM_APPROACH" | sed 's/[[\.*^$()+?{|]/\\&/g')
OPTIMIZATION_TECHNIQUE_ESCAPED=$(echo "$OPTIMIZATION_TECHNIQUE" | sed 's/[[\.*^$()+?{|]/\\&/g')
KEY_INSIGHT_ESCAPED=$(echo "$KEY_INSIGHT" | sed 's/[[\.*^$()+?{|]/\\&/g')

echo "🏢 Library: $LIBRARY_NAME"

# Setup environment
echo "📦 Setting up environment..."
cp "$TEMPLATE_DIR/requirements.txt" requirements.txt

# Process templates
echo "📝 Processing templates..."

# Process README.md
sed -e "s/{{library_name}}/$LIBRARY_NAME_ESCAPED/g" \
    -e "s/{{algorithm_approach}}/$ALGORITHM_APPROACH_ESCAPED/g" \
    -e "s/{{optimization_technique}}/$OPTIMIZATION_TECHNIQUE_ESCAPED/g" \
    -e "s/{{key_insight}}/$KEY_INSIGHT_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

# Process starter_code.py
sed -e "s/{{library_name}}/$LIBRARY_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    -e "s/{{random_seed}}/$RANDOM_SEED/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > solution.py

# Create test runner
cat > test_solution.py << 'EOF'
#!/usr/bin/env python3
"""
Test runner for the minimum weighted subgraph problem
"""

from solution import minimumWeight

def run_tests():
    """Run comprehensive tests on the solution."""
    print("🧪 Running comprehensive tests...")
    
    # Test cases
    test_cases = [
        {
            "name": "Example 1",
            "edges": [[0,1,2],[1,2,3],[1,3,5],[1,4,4],[2,5,6]],
            "queries": [[2,3,4],[0,2,5]],
            "expected": [12, 11]
        },
        {
            "name": "Example 2", 
            "edges": [[1,0,8],[0,2,7]],
            "queries": [[0,1,2]],
            "expected": [15]
        },
        {
            "name": "Simple Triangle",
            "edges": [[0,1,1],[1,2,1]],
            "queries": [[0,1,2]],
            "expected": [2]
        }
    ]
    
    all_passed = True
    
    for i, test in enumerate(test_cases):
        print(f"\nTest {i+1}: {test['name']}")
        try:
            result = minimumWeight(test["edges"], test["queries"])
            expected = test["expected"]
            
            print(f"  Expected: {expected}")
            print(f"  Got:      {result}")
            
            if result == expected:
                print(f"  ✅ PASSED")
            else:
                print(f"  ❌ FAILED")
                all_passed = False
                
        except Exception as e:
            print(f"  ❌ ERROR: {e}")
            all_passed = False
    
    print(f"\n{'✅ All tests passed!' if all_passed else '❌ Some tests failed!'}")
    return all_passed

if __name__ == "__main__":
    run_tests()
EOF

chmod +x test_solution.py

# Create submission metadata
cat > .submission_metadata.json << EOF
{
    "task_id": "ALGO-GRAPH-$(date +%s)",
    "generation_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "parameters": {
        "random_seed": $RANDOM_SEED,
        "library_name": "$LIBRARY_NAME"
    },
    "problem_info": {
        "source": "LeetCode 3553",
        "type": "tree_optimization",
        "difficulty": "hard"
    }
}
EOF

# Clean up templates
rm -rf "$TEMPLATE_DIR"
rm -rf "$CONFIG_DIR"

echo ""
echo "✅ Minimum Weighted Subgraph challenge initialized!"
echo ""
echo "📋 Next steps:"
echo "   1. Read the problem description in README.md"
echo "   2. Implement your solution in solution.py"
echo "   3. Test your solution: python test_solution.py"
echo "   4. Run development tests: python solution.py"
echo "   5. Submit when ready: ./scripts/submit.sh"
echo ""
echo "🧮 Graph algorithms challenge starts now! Good luck! 🌳"