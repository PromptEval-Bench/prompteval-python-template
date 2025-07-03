#!/bin/bash
# Network Optimization Task Initialization Script
# This script generates a unique instance of the network optimization problem

set -e  # Exit on error

echo "🚀 Initializing Network Optimization Challenge..."

# Load configuration
CONFIG_DIR="config"
TEMPLATE_DIR="template"
RESOURCES_DIR="resources/data"

# Read dynamic parameters
PARAMS_FILE="$CONFIG_DIR/dynamic_params.json"

# Generate random parameters within specified ranges
NUM_NODES=$((RANDOM % 21 + 10))          # 10-30 nodes
EDGE_RATIO=$(echo "scale=1; ($RANDOM % 14 + 12) / 10" | bc)  # 1.2-2.5 ratio
NUM_EDGES=$(echo "($NUM_NODES * $EDGE_RATIO) / 1" | bc)
UPGRADE_BUDGET=$((RANDOM % 8 + 3))       # 3-10 upgrades
MANDATORY_RATIO=$(echo "scale=2; ($RANDOM % 21 + 10) / 100" | bc)  # 0.10-0.30

echo "📊 Generated parameters:"
echo "   - Nodes: $NUM_NODES"
echo "   - Edges: $NUM_EDGES"
echo "   - Budget: $UPGRADE_BUDGET"
echo "   - Mandatory ratio: $MANDATORY_RATIO"

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
            "prompt": "Generate a realistic technology company name. Return only the name.",
            "max_tokens": 20,
            "temperature": 0.8
        }' | jq -r '.choices[0].text' | tr -d '\n' || echo "TechFlow Systems")
    
    # Generate scenario
    SCENARIO_PROMPT="Write a 2-3 sentence business scenario for a company named $COMPANY_NAME that needs to optimize their network infrastructure connecting $NUM_NODES offices."
    COMPANY_SCENARIO=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"prompt\": \"$SCENARIO_PROMPT\",
            \"max_tokens\": 150,
            \"temperature\": 0.7
        }" | jq -r '.choices[0].text' | tr '\n' ' ' || echo "Default scenario")
else
    echo "⚠️  LLM not available, using fallback content..."
    COMPANY_NAME="GlobalTech Solutions"
    COMPANY_SCENARIO="$COMPANY_NAME is experiencing rapid expansion across multiple continents. With $NUM_NODES offices worldwide, optimizing the network infrastructure is critical for maintaining efficient communication and data transfer while controlling costs."
fi

# Escape special characters for sed
COMPANY_NAME_ESCAPED=$(echo "$COMPANY_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
COMPANY_SCENARIO_ESCAPED=$(echo "$COMPANY_SCENARIO" | sed 's/[[\.*^$()+?{|]/\\&/g')

echo "🏢 Company: $COMPANY_NAME"

# Copy requirements and install dependencies
echo "📦 Setting up environment..."
cp "$TEMPLATE_DIR/requirements.txt" requirements.txt
pip install -r requirements.txt

# Generate network topology
echo "🔧 Generating network topology..."

python3 << EOF
import json
import random
import networkx as nx

# Parameters
num_nodes = $NUM_NODES
num_edges = int($NUM_EDGES)
mandatory_ratio = $MANDATORY_RATIO

# Create nodes
nodes = list(range(num_nodes))

# Generate a connected graph
# Start with a random spanning tree to ensure connectivity
G = nx.Graph()
G.add_nodes_from(nodes)

# Create initial spanning tree
for i in range(1, num_nodes):
    parent = random.randint(0, i-1)
    G.add_edge(parent, i)

# Add additional edges
current_edges = num_nodes - 1
while current_edges < num_edges and current_edges < (num_nodes * (num_nodes - 1)) // 2:
    u, v = random.sample(nodes, 2)
    if not G.has_edge(u, v):
        G.add_edge(u, v)
        current_edges += 1

# Convert to edge list with attributes
edges = []
for u, v in G.edges():
    bandwidth = random.randint(1, 10) * 10  # 10-100 in steps of 10
    is_mandatory = 1 if random.random() < mandatory_ratio else 0
    edges.append([u, v, bandwidth, is_mandatory])

# Ensure at least some mandatory edges exist
mandatory_count = sum(1 for e in edges if e[3] == 1)
if mandatory_count == 0:
    # Make a few edges mandatory
    for i in range(min(3, len(edges))):
        edges[i][3] = 1

# Save the network data
data = {
    "nodes": nodes,
    "edges": edges,
    "budget": $UPGRADE_BUDGET
}

with open('input_data.json', 'w') as f:
    json.dump(data, f, indent=2)

# Save metadata for validation
metadata = {
    "num_nodes": num_nodes,
    "num_edges": len(edges),
    "num_mandatory": sum(1 for e in edges if e[3] == 1),
    "budget": $UPGRADE_BUDGET,
    "generation_seed": random.randint(1000, 9999)
}

with open('.task_metadata.json', 'w') as f:
    json.dump(metadata, f, indent=2)

print(f"✅ Generated network with {num_nodes} nodes and {len(edges)} edges")
print(f"   - Mandatory edges: {metadata['num_mandatory']}")
EOF

# Process templates
echo "📝 Processing templates..."

# Process README.md
sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{company_scenario}}/$COMPANY_SCENARIO_ESCAPED/g" \
    -e "s/{{num_nodes}}/$NUM_NODES/g" \
    -e "s/{{num_edges}}/$NUM_EDGES/g" \
    -e "s/{{upgrade_budget}}/$UPGRADE_BUDGET/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

# Process starter code
sed -e "s/{{company_name}}/$COMPANY_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > solution.py

# Create test file
cat > test_solution.py << 'EOF'
#!/usr/bin/env python3
"""
Basic test suite for network optimization solution
"""

import json
from solution import optimize_network, validate_solution, load_input_data


def test_solution():
    """Run basic tests on the solution."""
    print("🧪 Testing your solution...")
    
    # Load data
    data = load_input_data()
    nodes = data['nodes']
    edges = data['edges']
    budget = data['budget']
    
    print(f"📊 Network size: {len(nodes)} nodes, {len(edges)} edges")
    print(f"💰 Upgrade budget: {budget}")
    
    # Run solution
    try:
        result = optimize_network(nodes, edges, budget)
        print("✅ Solution executed successfully!")
        
        # Check structure
        assert 'selected_edges' in result, "Missing 'selected_edges' in result"
        assert 'minimum_bandwidth' in result, "Missing 'minimum_bandwidth' in result"
        
        # Check edge count
        selected = result['selected_edges']
        expected_edges = len(nodes) - 1
        assert len(selected) == expected_edges, f"Expected {expected_edges} edges, got {len(selected)}"
        
        # Count upgrades
        upgrades_used = sum(1 for e in selected if e.get('upgraded', False))
        assert upgrades_used <= budget, f"Used {upgrades_used} upgrades, budget is {budget}"
        
        # Validate spanning tree
        if validate_solution(nodes, selected):
            print("✅ Solution forms a valid spanning tree!")
        else:
            print("❌ Solution does not form a valid spanning tree!")
        
        print(f"\n📈 Results:")
        print(f"   - Minimum bandwidth: {result['minimum_bandwidth']}")
        print(f"   - Upgrades used: {upgrades_used}/{budget}")
        
    except Exception as e:
        print(f"❌ Error running solution: {e}")
        raise


if __name__ == "__main__":
    test_solution()
EOF
chmod +x test_solution.py

# Create submission metadata
cat > .submission_metadata.json << EOF
{
    "task_id": "NET-OPT-003-$(date +%s)",
    "generation_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "parameters": {
        "num_nodes": $NUM_NODES,
        "num_edges": $NUM_EDGES,
        "budget": $UPGRADE_BUDGET,
        "company": "$COMPANY_NAME"
    }
}
EOF

# Clean up templates
rm -rf "$TEMPLATE_DIR"
rm -rf "$CONFIG_DIR"

# Success message
echo ""
echo "✅ Task initialization complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Read the problem description in README.md"
echo "   2. Review the network data in input_data.json"
echo "   3. Implement your solution in solution.py"
echo "   4. Test with: python test_solution.py"
echo "   5. Submit with: ./submit.sh"
echo ""
echo "Good luck! 🍀"