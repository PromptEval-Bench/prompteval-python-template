#!/bin/bash
# Pydicom Codify Bug Fix Task Initialization Script

set -e # Exit on error

echo "🚀 Initializing pydicom bug fix environment (pydicom-1674)..."

# --- 1. Setup Environment ---
echo "📦 Installing dependencies (pydicom)..."
pip install -q pydicom==2.3.0 numpy==1.22.4
TEMPLATE_DIR="templates"

# --- 2. Create Test Case DICOM File ---
echo "🔧 Generating a test DICOM file (test_case.dcm) with a sequence..."
python3 - <<'EOF'
import pydicom
from pydicom.dataset import Dataset, FileMetaDataset
from pydicom.sequence import Sequence

# Create file meta information
file_meta = FileMetaDataset()
file_meta.MediaStorageSOPClassUID = '1.2.840.10008.5.1.4.1.1.2' # CT Image Storage
file_meta.MediaStorageSOPInstanceUID = "1.2.3"
file_meta.ImplementationClassUID = "1.2.3.4"
file_meta.TransferSyntaxUID = pydicom.uid.ExplicitVRLittleEndian

# Create the main dataset
ds = Dataset()
ds.file_meta = file_meta
ds.PatientName = "Test^First"
ds.PatientID = "123456"

# Create a sequence
beam_sequence = Sequence()
ds.BeamSequence = beam_sequence

# Create and add first item to the sequence
item1 = Dataset()
item1.Manufacturer = "Pydicom"
item1.BeamNumber = 1
beam_sequence.append(item1)

# Create and add second item to the sequence
item2 = Dataset()
item2.Manufacturer = "TestCorp"
item2.BeamNumber = 2
beam_sequence.append(item2)

ds.is_little_endian = True
ds.is_implicit_VR = False

# Save the test file
ds.save_as("test_case.dcm", write_like_original=False)
print("   - test_case.dcm created successfully.")
EOF

# --- 3. Create Test Runner Script ---
echo "⚙️ Creating the automated test runner (test_runner.py)..."
cat > test_runner.py <<'EOF'
import sys
import os
import subprocess
import pydicom

# This is the file the user will edit
USER_CODIFY_MODULE = "codify"
TEST_DICOM_FILE = "test_case.dcm"
GENERATED_SCRIPT = "generated_script.py"
OUTPUT_DICOM_FILE = "output.dcm"

def run_test():
    """Runs the full test cycle for the codify bug fix."""
    print("--- Starting Test Run ---")
    
    # 1. Import the user's codify module
    try:
        import codify
        print("✅ Step 1: Successfully imported user's codify.py module.")
    except ImportError as e:
        print(f"❌ Step 1 FAILED: Could not import codify.py. Error: {e}")
        sys.exit(1)

    # 2. Generate python code from the test DICOM file
    try:
        print(f"⚙️ Step 2: Running codify on '{TEST_DICOM_FILE}'...")
        ds = pydicom.dcmread(TEST_DICOM_FILE)
        code_str = codify.code_file_from_dataset(ds)
        
        # Add a save_as line to the generated code
        save_line = f"\nds.save_as('{OUTPUT_DICOM_FILE}', write_like_original=False)"
        code_str += save_line
        
        with open(GENERATED_SCRIPT, "w") as f:
            f.write(code_str)
        print(f"   - Generated code written to '{GENERATED_SCRIPT}'.")
    except Exception as e:
        print(f"❌ Step 2 FAILED: codify.py script threw an exception. Error: {e}")
        sys.exit(1)

    # 3. Execute the generated script
    try:
        print(f"⚙️ Step 3: Executing '{GENERATED_SCRIPT}' to create output DICOM file...")
        result = subprocess.run([sys.executable, GENERATED_SCRIPT], capture_output=True, text=True, check=True)
        print(f"   - Script executed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"❌ Step 3 FAILED: The generated script failed to run.")
        print("--- STDOUT ---")
        print(e.stdout)
        print("--- STDERR ---")
        print(e.stderr)
        sys.exit(1)

    # 4. Validate the output file
    try:
        print(f"⚙️ Step 4: Validating the contents of '{OUTPUT_DICOM_FILE}'...")
        if not os.path.exists(OUTPUT_DICOM_FILE):
            print(f"❌ Step 4 FAILED: Output file '{OUTPUT_DICOM_FILE}' was not created.")
            sys.exit(1)
            
        output_ds = pydicom.dcmread(OUTPUT_DICOM_FILE)
        
        # The core of the test: Does the sequence exist and is it correct?
        assert 'BeamSequence' in output_ds, "BeamSequence tag is missing from the output file."
        print("   - BeamSequence tag found.")
        
        seq = output_ds.BeamSequence
        assert isinstance(seq, pydicom.sequence.Sequence), "BeamSequence is not a Sequence object."
        assert len(seq) == 2, f"Expected 2 items in BeamSequence, but found {len(seq)}."
        print("   - BeamSequence has the correct number of items (2).")

        assert seq[0].Manufacturer == "Pydicom", "First item's Manufacturer is incorrect."
        assert seq[1].BeamNumber == 2, "Second item's BeamNumber is incorrect."
        print("   - Sequence item data is correct.")

    except Exception as e:
        print(f"❌ Step 4 FAILED: Validation of output file failed. Error: {e}")
        sys.exit(1)

    print("\n✅ Test Passed! The fix appears to be working correctly.")
    print("--- Test Run Complete ---")

if __name__ == "__main__":
    run_test()
EOF
chmod +x test_runner.py
echo "   - test_runner.py created successfully."

# --- 4. Copy Templates and Finalize ---
echo "📝 Copying templates and scripts..."
# The starter code is named codify.py in the user's workspace
cp "$TEMPLATE_DIR/starter_code.py.template" codify.py
cp "$TEMPLATE_DIR/README.md.template" README.md
mkdir -p scripts
cp "$TEMPLATE_DIR/submit.sh" scripts/
chmod +x scripts/submit.sh

# Clean up
rm -rf "$TEMPLATE_DIR"

echo ""
echo "✅ Pydicom bug fix environment is ready."
echo ""
echo "--- YOUR TASK ---"
echo "1. Read the bug report and your mission in README.md."
echo "2. Edit and fix the logic in codify.py."
echo "3. Run 'python test_runner.py' to check your work."
echo "4. Once the test passes, submit with './scripts/submit.sh'."
echo "-----------------"