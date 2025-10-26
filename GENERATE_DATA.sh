#!/bin/bash
#
# Quick script to generate 10 gameplay sessions for data analysis
#
# Usage:
#   ./GENERATE_DATA.sh
#
# Output:
#   ~/Documents/GameplayLogs/session_*.json (10 files)
#
# Time:
#   ~5-10 minutes
#

set -e

echo "🎮 DunGen Play Data Generation"
echo "================================"
echo ""
echo "This will generate 10 complete adventure playthroughs with:"
echo "  - Random character classes and races"
echo "  - Random quest types"
echo "  - Full narrative logging"
echo ""
echo "Estimated time: 5-10 minutes"
echo "Output: ~/Documents/GameplayLogs/"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Check if simulator is running
echo "📱 Checking for running simulator..."
if ! xcrun simctl list devices | grep -q "Booted"; then
    echo "⚠️  No simulator is running."
    echo ""
    echo "Please start a simulator manually:"
    echo "  1. Open Xcode"
    echo "  2. Go to Xcode > Open Developer Tool > Simulator"
    echo "  3. Choose any iPhone simulator (iPhone 14 Pro or later recommended)"
    echo ""
    echo "Or run from command line:"
    echo "  open -a Simulator"
    echo ""
    read -p "Press Enter once simulator is running..."
    echo ""

    # Check again
    if ! xcrun simctl list devices | grep -q "Booted"; then
        echo "❌ Still no simulator running. Exiting."
        exit 1
    fi
fi

# Show which simulator is running
BOOTED_DEVICE=$(xcrun simctl list devices | grep "Booted" | head -1 | sed 's/^ *//' | cut -d '(' -f 1 | sed 's/ *$//')
echo "✅ Using simulator: $BOOTED_DEVICE"
echo ""

# Run the test
echo "🧪 Running test: testGenerate10Adventures"
echo ""

xcodebuild test \
    -scheme DunGen \
    -destination 'platform=iOS Simulator,name=$BOOTED_DEVICE,OS=latest' \
    -only-testing:DunGenTests/PlayDataGenerationExample/testGenerate10Adventures \
    2>&1 | grep -E "(Starting|Completed|Result|Adventures:|✅|📊)"

echo ""
echo "✅ Data generation complete!"
echo ""
echo "📂 View output files:"
echo "   open ~/Documents/GameplayLogs/"
echo ""
echo "📊 Count sessions:"
echo "   ls ~/Documents/GameplayLogs/ | wc -l"
echo ""
echo "🔍 Analyze data:"
echo "   See PLAY_DATA_GENERATION.md for analysis techniques"
echo ""
