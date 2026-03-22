#!/bin/bash

# --- 1. CONFIGURATION ---
COMFYUI_PATH="/workspace/ComfyUI"

# Get your tokens from: https://civitai.com/user/settings and https://huggingface.co/settings/tokens
CIVITAI_TOKEN="$CIVITAI_TOKEN"
HF_TOKEN="$HF_TOKEN"

echo "### Starting Master Provisioning ###"

# --- 2. INSTALL CUSTOM NODES ---
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

# Install all node dependencies at once
find "$COMFYUI_PATH/custom_nodes" -name "requirements.txt" -exec pip install --no-cache-dir -r {} \;

# --- 3. DOWNLOAD MODELS ---

# Function for Civitai (Handles Auth and Filenames)
download_civitai() {
    # Usage: download_civitai "URL" "FOLDER_PATH" "FILENAME"
    wget --header="Authorization: Bearer $CIVITAI_TOKEN" -O "$2/$3" "$1"
}

# Function for Hugging Face
download_hf() {
    # Usage: download_hf "URL" "FOLDER_PATH" "FILENAME"
    wget --header="Authorization: Bearer $HF_TOKEN" -O "$2/$3" "$1"
}

#echo "Downloading Models..."

# Examples (Replace with your actual favorites):
# Download a Checkpoint from Civitai (Example: Juggernaut XL)
#download_civitai "https://civitai.com/api/download/models/357609" "$COMFYUI_PATH/models/checkpoints" "juggernaut_xl.safetensors"

# Download a LoRA from Civitai (Example: Detail Slider)
#download_civitai "https://civitai.com/api/download/models/135867" "$COMFYUI_PATH/models/loras" "more_details.safetensors"

# Download from Hugging Face (Example: Flux/SDXL VAE)
#download_hf "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors" "$COMFYUI_PATH/models/vae" "sdxl_vae.safetensors"

echo "### Setup Complete! ###"
