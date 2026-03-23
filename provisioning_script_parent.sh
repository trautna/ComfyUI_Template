#!/bin/bash

# --- 0. SELF-HEALING (Fix Windows Line Endings) ---
# This ensures that even if saved as CRLF, the script converts itself to LF
sed -i 's/\r$//' "$0"

# --- 1. CONFIGURATION ---
COMFYUI_PATH="/workspace/ComfyUI"
SYNOLOGY_DOWNLOAD_DIR="$COMFYUI_PATH/models/synology"

# Get your tokens from Vast.ai Env Vars
# Ensure these are actually set in your Vast.ai "Environment Variables" section
CIVITAI_TOKEN="${CIVITAI_TOKEN}"
HF_TOKEN="${HF_TOKEN}"
SYNOLOGY_URL="${SYNOLOGY_URL}"
SYNOLOGY_PASS="${SYNOLOGY_PASS}"

echo "### Starting Master Provisioning ###"

# Ensure tools are available
apt-get update && apt-get install -y unzip curl jq

# --- 2. DOWNLOAD FUNCTIONS ---

download_synology() {
    echo "Connecting to Synology..."

    if [ -z "$SYNOLOGY_URL" ] || [ -z "$SYNOLOGY_PASS" ]; then
        echo "Skipping Synology: URL or Password not set."
        return 1
    fi

    mkdir -p "$SYNOLOGY_DOWNLOAD_DIR"

    # Extract ID (works for both DDNS and QuickConnect links)
    SHARING_ID=$(echo "$SYNOLOGY_URL" | grep -oE '[^/]+$')
    BASE_URL=$(echo "$SYNOLOGY_URL" | cut -d'/' -f1-3)
    API_URL="$BASE_URL/sharing/api/shared_link.cgi"
    COOKIE_FILE="/tmp/syno_cookie.txt"

    # Authenticate via API
    echo "Authenticating..."
    curl -s -c "$COOKIE_FILE" -X POST \
         -d "api=SYNO.Sharing.AppInstance" \
         -d "method=verify_password" \
         -d "version=1" \
         -d "sharing_id=$SHARING_ID" \
         -d "password=$SYNOLOGY_PASS" \
         "$API_URL" > /dev/null

    # Get Info using JQ for reliability
    INFO_JSON=$(curl -s -b "$COOKIE_FILE" "$API_URL?api=SYNO.Sharing.AppInstance&method=get_info&version=1&sharing_id=$SHARING_ID")

    # Extract filename and folder status
    ORIGINAL_NAME=$(echo "$INFO_JSON" | jq -r '.data.filename // empty')
    IS_FOLDER=$(echo "$INFO_JSON" | jq -r '.data.is_folder // false')

    if [ -z "$ORIGINAL_NAME" ]; then
        echo "Error: Access denied. Check your Synology Password or Link."
        return 1
    fi

    if [ "$IS_FOLDER" = "true" ]; then
        echo "Downloading FOLDER: $ORIGINAL_NAME"
        TEMP_ZIP="/tmp/syno_folder.zip"
        curl -L -b "$COOKIE_FILE" -o "$TEMP_ZIP" "$API_URL?api=SYNO.Sharing.AppInstance&method=download&version=1&sharing_id=$SHARING_ID"
        unzip -q -o "$TEMP_ZIP" -d "$SYNOLOGY_DOWNLOAD_DIR"
        rm "$TEMP_ZIP"
    else
        echo "Downloading FILE: $ORIGINAL_NAME"
        curl -L -b "$COOKIE_FILE" -o "$SYNOLOGY_DOWNLOAD_DIR/$ORIGINAL_NAME" \
             "$API_URL?api=SYNO.Sharing.AppInstance&method=download&version=1&sharing_id=$SHARING_ID"
    fi

    rm "$COOKIE_FILE"
    echo "Synology Download Finished."
}

# --- 3. INSTALL CUSTOM NODES ---
echo "Installing Custom Nodes..."
nodes=(
    "https://github.com/ltdrdata/ComfyUI-Manager.git"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
	  "https://github.com/rgthree/rgthree-comfy.git"
	  "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
	  "https://github.com/crystian/ComfyUI-Crystools.git"
	  "https://github.com/un-seen/comfyui-tensorops.git"
    "https://github.com/slahiri/ComfyUI-Workflow-Models-Downloader.git"
    "https://github.com/MoonGoblinDev/Civicomfy.git"
)

mkdir -p "$COMFYUI_PATH/custom_nodes"
cd "$COMFYUI_PATH/custom_nodes"
for repo in "${nodes[@]}"; do
    git clone "$repo" 2>/dev/null || (cd $(basename "$repo" .git) && git pull)
done

# Install dependencies for all nodes
pip install deepdiff surrealist tavily-python onnxruntime-gpu
find "$COMFYUI_PATH/custom_nodes" -name "requirements.txt" -exec pip install --no-cache-dir -r {} \;

# --- 4. EXECUTE ---
download_synology

echo "### Setup Complete! ###"