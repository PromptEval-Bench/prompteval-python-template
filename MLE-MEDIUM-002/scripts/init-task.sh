#!/bin/bash
# Author Identification Task Initialization Script with Kaggle Data Download

set -e  # Exit on error

echo "🚀 Initializing Author Identification Challenge..."

# Basic setup
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y bc jq curl unzip python3-pip > /dev/null 2>&1

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
            "prompt": "Generate a name for a literary text analysis platform. Examples: LitAnalyzer, TextScribe, AuthorIQ. Return only the name.",
            "max_tokens": 15,
            "temperature": 0.7
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs 2>/dev/null || echo "LitAnalyzer")
    
    # Generate scenario
    SCENARIO_PROMPT="Write a 2-3 sentence scenario about how $LIBRARY_NAME is used by literary scholars to identify authors using machine learning."
    USE_CASE_SCENARIO=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"prompt\": \"$SCENARIO_PROMPT\",
            \"max_tokens\": 120,
            \"temperature\": 0.6
        }" | jq -r '.choices[0].text' | tr '\n' ' ' | xargs 2>/dev/null || echo "Default scenario")
    
    # Generate approach
    MODEL_APPROACH=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest a machine learning approach for text classification. Examples: TF-IDF with SVM, neural networks. Return approach name only.",
            "max_tokens": 15,
            "temperature": 0.5
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs 2>/dev/null || echo "TF-IDF with SVM")
    
    # Generate feature engineering
    FEATURE_ENGINEERING=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest one text feature engineering technique. Examples: n-gram analysis, stylometric. One term only.",
            "max_tokens": 10,
            "temperature": 0.4
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs 2>/dev/null || echo "stylometric")
else
    echo "⚠️  LLM not available, using fallback content..."
    LIBRARY_NAME="LitAnalyzer"
    USE_CASE_SCENARIO="Literary scholars use $LIBRARY_NAME to analyze writing styles and identify authors of disputed or anonymous texts. The platform employs machine learning to detect subtle patterns in vocabulary, syntax, and stylistic choices that are unique to each writer."
    MODEL_APPROACH="TF-IDF with SVM"
    FEATURE_ENGINEERING="stylometric"
fi

# Escape for sed
LIBRARY_NAME_ESCAPED=$(echo "$LIBRARY_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
USE_CASE_SCENARIO_ESCAPED=$(echo "$USE_CASE_SCENARIO" | sed 's/[[\.*^$()+?{|]/\\&/g')
MODEL_APPROACH_ESCAPED=$(echo "$MODEL_APPROACH" | sed 's/[[\.*^$()+?{|]/\\&/g')
FEATURE_ENGINEERING_ESCAPED=$(echo "$FEATURE_ENGINEERING" | sed 's/[[\.*^$()+?{|]/\\&/g')

echo "📚 Library: $LIBRARY_NAME"

# Setup Python environment
echo "📦 Setting up Python environment..."
pip install pandas numpy scikit-learn kaggle > /dev/null 2>&1

# Check for Kaggle credentials from environment variables/secrets
echo "🔑 Checking Kaggle credentials..."
if [ -z "$KAGGLE_USERNAME" ] || [ -z "$KAGGLE_KEY" ]; then
    echo "❌ FAILED: Kaggle credentials not found!"
    echo ""
    echo "Required environment variables:"
    echo "   - KAGGLE_USERNAME: Your Kaggle username"
    echo "   - KAGGLE_KEY: Your Kaggle API key"
    echo ""
    echo "To set up Kaggle credentials:"
    echo "   1. Create account at kaggle.com"
    echo "   2. Go to Account > API > Create New API Token"
    echo "   3. Set the environment variables in your secrets/config"
    echo ""
    exit 1
fi

echo "   ✅ Found Kaggle credentials in environment variables"

# Setup Kaggle credentials temporarily
mkdir -p ~/.kaggle
echo "{\"username\":\"$KAGGLE_USERNAME\",\"key\":\"$KAGGLE_KEY\"}" > ~/.kaggle/kaggle.json
chmod 600 ~/.kaggle/kaggle.json

# Download and prepare dataset
echo "📊 Downloading dataset from Kaggle..."

# Create data directories
mkdir -p data/raw data/public data/private

# Download competition data
if kaggle competitions download -c spooky-author-identification -p data/raw/ 2>/dev/null; then
    echo "   ✅ Successfully downloaded from Kaggle"
    
    # Extract downloaded files
    cd data/raw
    if [ -f "spooky-author-identification.zip" ]; then
        unzip -q spooky-author-identification.zip
        rm spooky-author-identification.zip
    fi
    
    # Also extract train.zip if it exists
    if [ -f "train.zip" ]; then
        unzip -q train.zip
    fi
    cd ../..
    
else
    # Clean up credentials and exit
    rm -f ~/.kaggle/kaggle.json
    rmdir ~/.kaggle 2>/dev/null || true
    
    echo "❌ FAILED: Could not download data from Kaggle!"
    echo ""
    echo "Possible causes:"
    echo "   - Invalid Kaggle credentials"
    echo "   - Network connectivity issues"
    echo "   - Competition may not be accessible"
    echo "   - Rate limiting from Kaggle API"
    echo ""
    echo "Please verify:"
    echo "   1. Your Kaggle credentials are correct"
    echo "   2. You have internet access"
    echo "   3. The competition 'spooky-author-identification' is available"
    echo ""
    exit 1
fi

# Clean up Kaggle credentials immediately after successful use
echo "   🧹 Cleaning up temporary credentials..."
rm -f ~/.kaggle/kaggle.json
rmdir ~/.kaggle 2>/dev/null || true

# Run data preparation
echo "   🔄 Preparing train/test split..."

# Create a standalone prepare script
cat > prepare_data.py << 'EOF'
#!/usr/bin/env python3
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.model_selection import train_test_split

def prepare_data():
    """Prepare the dataset for the competition"""
    
    # Paths
    raw_path = Path("data/raw")
    public_path = Path("data/public")
    private_path = Path("data/private")
    
    # Create directories
    public_path.mkdir(exist_ok=True)
    private_path.mkdir(exist_ok=True)
    
    # Read the original training data
    train_file = raw_path / "train.csv"
    if not train_file.exists():
        print(f"Error: {train_file} not found!")
        return False
    
    df = pd.read_csv(train_file)
    print(f"Loaded {len(df)} samples")
    
    # Create train/test split
    train_df, test_df = train_test_split(df, test_size=0.1, random_state=42, stratify=df['author'])
    
    # Remove labels from test set
    test_without_labels = test_df[['id', 'text']].copy()
    
    # Create sample submission
    sample_submission = pd.DataFrame({
        'id': test_df['id'],
        'EAP': 0.403493538995863,
        'HPL': 0.287808366106543,
        'MWS': 0.308698094897594
    })
    
    # Create ground truth for private evaluation
    test_labels = test_df[['id', 'author']].copy()
    # Convert to one-hot format
    test_labels_onehot = pd.get_dummies(test_labels.set_index('id')['author']).reset_index()
    # Reorder columns to match submission format
    test_labels_onehot = test_labels_onehot[['id', 'EAP', 'HPL', 'MWS']].fillna(0).astype(int)
    
    # Save files
    train_df.to_csv(public_path / "train.csv", index=False)
    test_without_labels.to_csv(public_path / "test.csv", index=False)
    sample_submission.to_csv(public_path / "sample_submission.csv", index=False)
    test_labels_onehot.to_csv(private_path / "test.csv", index=False)
    
    print(f"✅ Data prepared:")
    print(f"   Training samples: {len(train_df)}")
    print(f"   Test samples: {len(test_df)}")
    print(f"   Files created in data/public/ and data/private/")
    
    return True

if __name__ == "__main__":
    prepare_data()
EOF

if ! python3 prepare_data.py; then
    echo "❌ FAILED: Could not prepare dataset!"
    exit 1
fi

# Copy prepared data to working directory
if [ -f "data/public/train.csv" ]; then
    cp data/public/train.csv ./
    cp data/public/test.csv ./
    cp data/public/sample_submission.csv ./
    echo "   ✅ Dataset files copied to working directory"
else
    echo "❌ FAILED: Dataset preparation incomplete!"
    exit 1
fi

# Clean up temporary files
rm -f prepare_data.py

# Process templates
echo "📝 Processing templates..."

# Process README.md
sed -e "s/{{library_name}}/$LIBRARY_NAME_ESCAPED/g" \
    -e "s/{{use_case_scenario}}/$USE_CASE_SCENARIO_ESCAPED/g" \
    -e "s/{{model_approach}}/$MODEL_APPROACH_ESCAPED/g" \
    -e "s/{{feature_engineering}}/$FEATURE_ENGINEERING_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

# Process starter_code.py
sed -e "s/{{library_name}}/$LIBRARY_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    -e "s/{{random_seed}}/$RANDOM_SEED/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > starter_code.py

# Create data exploration helper
cat > explore_data.py << 'EOF'
#!/usr/bin/env python3
"""
Quick data exploration script for the author identification dataset
"""

import pandas as pd
import numpy as np

def explore_dataset():
    print("🔍 Author Identification Dataset Explorer")
    print("=" * 60)
    
    # Load data
    try:
        train_df = pd.read_csv('train.csv')
        test_df = pd.read_csv('test.csv')
        
        print(f"📁 Data Shape:")
        print(f"   Training: {train_df.shape}")
        print(f"   Test: {test_df.shape}")
        
        # Author distribution
        if 'author' in train_df.columns:
            print(f"\n👥 Author Distribution:")
            author_counts = train_df['author'].value_counts()
            for author, count in author_counts.items():
                percentage = count / len(train_df) * 100
                print(f"   {author}: {count} ({percentage:.1f}%)")
        
        # Text statistics
        if 'text' in train_df.columns:
            train_df['text_length'] = train_df['text'].str.len()
            train_df['word_count'] = train_df['text'].str.split().str.len()
            
            print(f"\n📊 Text Statistics:")
            print(f"   Average text length: {train_df['text_length'].mean():.1f} characters")
            print(f"   Average word count: {train_df['word_count'].mean():.1f} words")
            
            # By author
            if 'author' in train_df.columns:
                print(f"\n📝 Text Stats by Author:")
                for author in train_df['author'].unique():
                    author_data = train_df[train_df['author'] == author]
                    avg_len = author_data['text_length'].mean()
                    avg_words = author_data['word_count'].mean()
                    print(f"   {author}: {avg_len:.1f} chars, {avg_words:.1f} words")
        
        # Sample texts
        print(f"\n📖 Sample Texts:")
        if len(train_df) > 0:
            for i, (_, row) in enumerate(train_df.head(3).iterrows()):
                text_preview = row['text'][:100] + "..." if len(row['text']) > 100 else row['text']
                author = row.get('author', 'Unknown')
                print(f"   {author}: {text_preview}")
        
    except FileNotFoundError as e:
        print(f"❌ Data file not found: {e}")
    except Exception as e:
        print(f"❌ Error loading data: {e}")
    
    print(f"\n🎯 Your Task:")
    print(f"   Predict probabilities for three authors: EAP, HPL, MWS")
    print(f"   Use text features and NLP techniques")
    print(f"   Optimize for logarithmic loss")

if __name__ == "__main__":
    explore_dataset()
EOF

chmod +x explore_data.py

# Create submission metadata
cat > .submission_metadata.json << EOF
{
    "task_id": "NLP-AUTHOR-$(date +%s)",
    "generation_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "parameters": {
        "random_seed": $RANDOM_SEED,
        "library_name": "$LIBRARY_NAME"
    },
    "dataset_info": {
        "task_type": "text_classification",
        "classes": ["EAP", "HPL", "MWS"],
        "metric": "multi_class_log_loss",
        "source": "kaggle_spooky_author_identification"
    }
}
EOF

# Clean up configuration files
echo "🧹 Cleaning up configuration files..."
rm -rf "$CONFIG_DIR"
rm -rf "$TEMPLATE_DIR"

echo ""
echo "✅ Author Identification challenge initialized successfully!"
echo ""
echo "📊 Using real Kaggle competition data"
echo "📋 Next steps:"
echo "   1. Explore the dataset: python explore_data.py"
echo "   2. Read the problem description in README.md"  
echo "   3. Run the starter code: python starter_code.py"
echo "   4. Build your NLP model"
echo "   5. Submit with: ./scripts/submit.sh"
echo ""
echo "📚 Literary analysis meets machine learning! Good luck! ✍️"