#!/bin/bash

# --- 1. CONFIGURATION ---
COMFYUI_PATH="/workspace/ComfyUI"
SYNOLOGY_DOWNLOAD_DIR="$COMFYUI_PATH/synology_downloads"

# Get your tokens from Vast.ai Env Vars
CIVITAI_TOKEN="$CIVITAI_TOKEN"
HF_TOKEN="$HF_TOKEN"
SYNOLOGY_URL="$SYNOLOGY_URL"
SYNOLOGY_PASS="$SYNOLOGY_PASS"

echo "### Starting Master Provisioning ###"

# Ensure unzip is available for Synology folder handling
apt-get update && apt-get install -y unzip

# --- 2. DOWNLOAD FUNCTIONS ---

# Function for Synology (Handles Files/Folders/Auth)
download_synology() {
    echo "Running Synology Download..."

    if [ -z "$SYNOLOGY_URL" ] || [ -z "$SYNOLOGY_PASS" ]; then
        echo "Skipping Synology: URL or Password not set."
        return 1
    fi

    mkdir -p "$SYNOLOGY_DOWNLOAD_DIR"

    SHARING_ID=$(echo "$SYNOLOGY_URL" | grep -oE '[^/]+$')
    BASE_URL=$(echo "$SYNOLOGY_URL" | cut -d'/' -f1-3)
    COOKIE_FILE="/tmp/syno_cookie.txt"
    API_URL="$BASE_URL/sharing/api/shared_link.cgi"

    # Authenticate
    curl -s -c "$COOKIE_FILE" -X POST \
         -d "sharing_id=$SHARING_ID" \
         -d "password=$SYNOLOGY_PASS" \
         "$API_URL/verify_password" > /dev/null

    # Get Metadata (to find out if it's a file or folder and get the name)
    INFO_JSON=$(curl -s -b "$COOKIE_FILE" "$API_URL/get_info?sharing_id=$SHARING_ID")
    IS_FOLDER=$(echo "$INFO_JSON" | grep -o '"is_folder":true')
    ORIGINAL_NAME=$(echo "$INFO_JSON" | grep -oP '"filename":"\K[^"]+')

    if [ -z "$ORIGINAL_NAME" ]; then
        echo "Error: Could not access Synology link. check password."
        return 1
    fi

    if [ -n "$IS_FOLDER" ]; then
        echo "Downloading FOLDER: $ORIGINAL_NAME"
        TEMP_ZIP="/tmp/syno_folder.zip"
        curl -L -b "$COOKIE_FILE" -o "$TEMP_ZIP" "$API_URL/download?sharing_id=$SHARING_ID"
        unzip -q -o "$TEMP_ZIP" -d "$SYNOLOGY_DOWNLOAD_DIR"
        rm "$TEMP_ZIP"
    else
        echo "Downloading FILE: $ORIGINAL_NAME"
        curl -L -b "$COOKIE_FILE" -o "$SYNOLOGY_DOWNLOAD_DIR/$ORIGINAL_NAME" \
             "$API_URL/download?sharing_id=$SHARING_ID"
    fi

    rm "$COOKIE_FILE"
}

# Function for Civitai
download_civitai() {
    wget -q --show-progress --header="Authorization: Bearer $CIVITAI_TOKEN" -O "$2/$3" "$1"
}

# Function for Hugging Face
download_hf() {
    wget -q --show-progress --header="Authorization: Bearer $HF_TOKEN" -O "$2/$3" "$1"
}

# --- 3. INSTALL CUSTOM NODES ---
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

cd "$COMFYUI_PATH/custom_nodes"
for repo in "${nodes[@]}"; do
    git clone "$repo"
done

# Install all node dependencies
find "$COMFYUI_PATH/custom_nodes" -name "requirements.txt" -exec pip install --no-cache-dir -r {} \;

# --- 4. EXECUTE DOWNLOADS ---

echo "Running Synology Download..."
download_synology

# Civitai/HF Examples (Uncomment as needed)
# download_civitai "https://civitai.com/api/download/models/357609" "$COMFYUI_PATH/models/checkpoints" "juggernaut_xl.safetensors"
# download_hf "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors" "$COMFYUI_PATH/models/vae" "sdxl_vae.safetensors"

echo "### Setup Complete! ###"