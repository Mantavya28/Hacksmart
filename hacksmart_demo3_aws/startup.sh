#!/bin/bash
# Startup script for HackSmart Streamlit Application
# This script performs pre-flight checks before starting the application

set -e

echo "🚀 Starting HackSmart Streamlit Application..."

# Check if required data files exist
echo "📋 Checking for required data files..."
required_files=(
    "delhi_boundary.geojson"
    "delhi_pois.geojson"
    "hacksmart_frontend.xlsx"
    "full_dataset.csv"
    "demand.csv"
    "topology.csv"
    "stations.csv"
    "stations.json"
)

missing_files=0
for file in "${required_files[@]}"; do
    if [ ! -f "/app/$file" ]; then
        echo "❌ Missing required file: $file"
        missing_files=$((missing_files + 1))
    else
        echo "✅ Found: $file"
    fi
done

if [ $missing_files -gt 0 ]; then
    echo "⚠️  Warning: $missing_files required file(s) missing. Application may not function correctly."
fi

# Check Python version
echo "🐍 Python version: $(python --version)"

# Check Streamlit installation
echo "📊 Streamlit version: $(streamlit --version)"

# Set production configurations
export STREAMLIT_SERVER_PORT=${STREAMLIT_SERVER_PORT:-8501}
export STREAMLIT_SERVER_ADDRESS=${STREAMLIT_SERVER_ADDRESS:-0.0.0.0}
export STREAMLIT_SERVER_HEADLESS=${STREAMLIT_SERVER_HEADLESS:-true}
export STREAMLIT_BROWSER_GATHER_USAGE_STATS=${STREAMLIT_BROWSER_GATHER_USAGE_STATS:-false}

echo "🌐 Server will listen on $STREAMLIT_SERVER_ADDRESS:$STREAMLIT_SERVER_PORT"

# Start Streamlit
echo "🎬 Launching Streamlit application..."
exec streamlit run app.py \
    --server.port=$STREAMLIT_SERVER_PORT \
    --server.address=$STREAMLIT_SERVER_ADDRESS \
    --server.headless=$STREAMLIT_SERVER_HEADLESS \
    --browser.gatherUsageStats=$STREAMLIT_BROWSER_GATHER_USAGE_STATS
