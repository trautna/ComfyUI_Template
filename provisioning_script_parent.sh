#!/bin/bash

# --- 1. CONFIGURATION ---
COMFYUI_PATH="/workspace/ComfyUI"

# These will be pulled from your Vast.ai Environment Variables
CIVITAI_TOKEN="${CIVITAI_TOKEN}"
HF_TOKEN="${HF_TOKEN}"
SYNOLOGY_URL="${SYNOLOGY_URL}"
SYNOLOGY_PASS="${SYNOLOGY_PASS}"

echo "### Starting Master Provisioning ###"

# --- 2. DOWNLOAD FUNCTIONS ---

# Function for Synology Drive (Handles Shared Link + Password)
download_synology() {
    # Usage: download_synology "FOLDER_PATH" "FILENAME"
    local DEST_FOLDER=$1
    local FILENAME=$2

    if [ -z "$SYNOLOGY_URL" ] || [ -z "$SYNOLOGY_PASS" ]; then
        echo "Skipping Synology: URL or Password not set in Environment Variables."
        return 1
    fi

    echo "Authenticating with Synology..."
    SHARING_ID=$(echo "$SYNOLOGY_URL" | grep -oE '[^/]+$')
    BASE_URL=$(echo "$SYNOLOGY_URL" | cut -d'/' -f1-3)
    COOKIE_FILE="/tmp/syno_cookie.txt"

    # Login and save cookie
    curl -s -c "$COOKIE_FILE" -X POST \
         -d "sharing_id=$SHARING_ID" \
         -d "password=$SYNOLOGY_PASS" \
         "$BASE_URL/sharing/api/shared_link.cgi/verify_password" > /dev/null

    echo "Downloading $FILENAME from Synology..."
    curl -L -b "$COOKIE_FILE" \
         -o "$DEST_FOLDER/$FILENAME" \
         "$BASE_URL/sharing/api/shared_link.cgi/download?sharing_id=$SHARING_ID"

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

mkdir -p "$COMFYUI_PATH/custom_nodes"
cd "$COMFYUI_PATH/custom_nodes"
for repo in "${nodes[@]}"; do
    git clone "$repo"
done

# Install all node dependencies
find "$COMFYUI_PATH/custom_nodes" -name "requirements.txt" -exec pip install --no-cache-dir -r {} \;

# --- 4. EXECUTE DOWNLOADS ---

echo "Downloading Models..."

# Synology Example (Private Models/Workflows)
# Just provide the destination folder and the name you want to give the file
download_synology "$COMFYUI_PATH/models/checkpoints" "my_private_model.safetensors"

# Civitai/HF Examples (Uncomment as needed)
# download_civitai "https://civitai.com/api/download/models/357609" "$COMFYUI_PATH/models/checkpoints" "juggernaut_xl.safetensors"
# download_hf "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors" "$COMFYUI_PATH/models/vae" "sdxl_vae.safetensors"

echo "### Setup Complete! ###"