#!/bin/bash
# Insult Detection Task Initialization Script

set -e  # Exit on error

echo "🚀 Initializing Social Media Insult Detection Challenge..."

# Basic setup
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y bc jq curl unzip python3-pip > /dev/null 2>&1

# Load configuration
CONFIG_DIR="config"
TEMPLATE_DIR="template"

# Generate random parameters
RANDOM_SEED=$((RANDOM % 59 + 42))

echo "📊 Generated parameters:"
echo "   - Random seed: $RANDOM_SEED"

# Generate current date
CURRENT_DATE=$(date +%Y-%m-%d)

# LLM content generation (with fallbacks)
if [ ! -z "$LLM_API_URL" ] && [ ! -z "$LLM_API_KEY" ]; then
    echo "🤖 Generating dynamic content with LLM..."
    
    PLATFORM_NAME=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Generate a realistic social media content moderation platform name. Examples: SafeSpace, CommentGuard, ToxicityShield, CleanChat. Return only the platform name, nothing else.",
            "max_tokens": 15,
            "temperature": 0.8
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs 2>/dev/null || echo "SafeSpace")
    
    SCENARIO_PROMPT="Write a 2-3 sentence business scenario about how $PLATFORM_NAME helps social media companies automatically detect insulting comments to maintain healthy online communities. Include specific benefits like user safety and moderation efficiency."
    COMPANY_SCENARIO=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"prompt\": \"$SCENARIO_PROMPT\",
            \"max_tokens\": 120,
            \"temperature\": 0.6
        }" | jq -r '.choices[0].text' | tr '\n' ' ' | xargs 2>/dev/null || echo "Default scenario")
    
    MODEL_APPROACH=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest a machine learning approach for text toxicity detection. Examples: Logistic Regression with TF-IDF, LSTM with word embeddings, Ensemble of SVM and Random Forest. Return only the approach name.",
            "max_tokens": 20,
            "temperature": 0.5
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs 2>/dev/null || echo "Logistic Regression with TF-IDF")
    
    FEATURE_TECHNIQUE=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest one advanced feature engineering technique for toxicity detection. Examples: sentiment polarity scoring, profanity pattern matching, character-level n-grams. Return only the technique name.",
            "max_tokens": 15,
            "temperature": 0.4
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs 2>/dev/null || echo "sentiment polarity scoring")
else
    echo "⚠️  LLM not available, using fallback content..."
    PLATFORM_NAME="SafeSpace"
    COMPANY_SCENARIO="$PLATFORM_NAME empowers social media platforms to automatically detect insulting comments before they harm community members. The system analyzes text patterns, context, and linguistic cues to identify toxic behavior while preserving healthy discourse, reducing moderation workload by 80%."
    MODEL_APPROACH="Logistic Regression with TF-IDF"
    FEATURE_TECHNIQUE="sentiment polarity scoring"
fi

# Escape for sed
PLATFORM_NAME_ESCAPED=$(echo "$PLATFORM_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
COMPANY_SCENARIO_ESCAPED=$(echo "$COMPANY_SCENARIO" | sed 's/[[\.*^$()+?{|]/\\&/g')
MODEL_APPROACH_ESCAPED=$(echo "$MODEL_APPROACH" | sed 's/[[\.*^$()+?{|]/\\&/g')
FEATURE_TECHNIQUE_ESCAPED=$(echo "$FEATURE_TECHNIQUE" | sed 's/[[\.*^$()+?{|]/\\&/g')

echo "🛡️ Platform: $PLATFORM_NAME"

# Setup Python environment
echo "📦 Setting up Python environment..."
pip install -r template/requirements.txt > /dev/null 2>&1

# Check Kaggle credentials
echo "🔑 Checking Kaggle credentials..."
if [ -z "$KAGGLE_USERNAME" ] || [ -z "$KAGGLE_KEY" ]; then
    echo "❌ FAILED: Kaggle credentials not found!"
    echo ""
    echo "Required environment variables:"
    echo "   - KAGGLE_USERNAME: Your Kaggle username"
    echo "   - KAGGLE_KEY: Your Kaggle API key"
    exit 1
fi

echo "   ✅ Found Kaggle credentials"

# Setup Kaggle credentials temporarily
mkdir -p ~/.kaggle
echo "{\"username\":\"$KAGGLE_USERNAME\",\"key\":\"$KAGGLE_KEY\"}" > ~/.kaggle/kaggle.json
chmod 600 ~/.kaggle/kaggle.json

# Download dataset
echo "📊 Downloading dataset from Kaggle..."
mkdir -p data/raw data/public data/private

if kaggle competitions download -c detecting-insults-in-social-commentary -p data/raw/ 2>/dev/null; then
    echo "   ✅ Successfully downloaded from Kaggle"
    
    cd data/raw
    if [ -f "detecting-insults-in-social-commentary.zip" ]; then
        unzip -q detecting-insults-in-social-commentary.zip
        rm detecting-insults-in-social-commentary.zip
    fi
    cd ../..
else
    rm -f ~/.kaggle/kaggle.json
    rmdir ~/.kaggle 2>/dev/null || true
    echo "❌ FAILED: Could not download data from Kaggle!"
    exit 1
fi

# Clean up credentials
rm -f ~/.kaggle/kaggle.json
rmdir ~/.kaggle 2>/dev/null || true

# Prepare data using the prepare.py script
echo "   🔄 Preparing train/test split..."
if ! python3 scripts/prepare.py data/raw data/public data/private; then
    echo "❌ FAILED: Could not prepare dataset!"
    exit 1
fi

# Copy files to working directory
cp data/public/train.csv ./
cp data/public/test.csv ./
cp data/public/sample_submission.csv ./

# Process templates
echo "📝 Processing templates..."

sed -e "s/{{platform_name}}/$PLATFORM_NAME_ESCAPED/g" \
    -e "s/{{company_scenario}}/$COMPANY_SCENARIO_ESCAPED/g" \
    -e "s/{{model_approach}}/$MODEL_APPROACH_ESCAPED/g" \
    -e "s/{{feature_technique}}/$FEATURE_TECHNIQUE_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

sed -e "s/{{platform_name}}/$PLATFORM_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    -e "s/{{random_seed}}/$RANDOM_SEED/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > starter_code.py

# Create exploration script
cat > explore_data.py << 'EOF'
#!/usr/bin/env python3
import pandas as pd
import numpy as np

def explore_dataset():
    print("🔍 Insult Detection Dataset Explorer")
    print("=" * 60)
    
    try:
        train_df = pd.read_csv('train.csv')
        test_df = pd.read_csv('test.csv')
        
        print(f"📁 Data Shape:")
        print(f"   Training: {train_df.shape}")
        print(f"   Test: {test_df.shape}")
        
        print(f"\n📊 Class Distribution:")
        class_counts = train_df['Insult'].value_counts()
        for class_val, count in class_counts.items():
            label = "Insulting" if class_val == 1 else "Neutral"
            percentage = count / len(train_df) * 100
            print(f"   {label} ({class_val}): {count:,} ({percentage:.1f}%)")
        
        print(f"\n📝 Comment Statistics:")
        train_df['comment_length'] = train_df['Comment'].str.len()
        train_df['word_count'] = train_df['Comment'].str.split().str.len()
        
        print(f"   Average comment length: {train_df['comment_length'].mean():.1f} characters")
        print(f"   Average word count: {train_df['word_count'].mean():.1f} words")
        
        print(f"\n📖 Sample Comments:")
        print("Neutral comments:")
        for comment in train_df[train_df['Insult'] == 0]['Comment'].head(2):
            print(f"   • {comment[:80]}...")
        
        print("Insulting comments:")
        for comment in train_df[train_df['Insult'] == 1]['Comment'].head(2):
            print(f"   • {comment[:80]}...")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    
    print(f"\n🎯 Your Task:")
    print(f"   Predict insulting comment probability (AUC metric)")
    print(f"   Focus on insults directed at conversation participants")

if __name__ == "__main__":
    explore_dataset()
EOF

chmod +x explore_data.py

# Create metadata files
cat > .submission_metadata.json << EOF
{
    "task_id": "NLP-MODERATE-003-$(date +%s)",
    "generation_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "parameters": {
        "random_seed": $RANDOM_SEED,
        "platform_name": "$PLATFORM_NAME"
    },
    "dataset_info": {
        "task_type": "binary_classification",
        "metric": "auc",
        "source": "kaggle_detecting_insults_in_social_commentary"
    }
}
EOF

cp "$CONFIG_DIR/task_metadata.json" .task_metadata.json

# Cleanup
rm -rf "$CONFIG_DIR" "$TEMPLATE_DIR"

echo ""
echo "✅ Insult Detection challenge initialized successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Explore the dataset: python explore_data.py"
echo "   2. Read the challenge description in README.md"
echo "   3. Run the starter code: python starter_code.py"
echo "   4. Build your toxicity detection model"
echo "   5. Submit with: ./scripts/submit.sh"
echo ""
echo "🛡️ Help build safer online communities! Good luck!"