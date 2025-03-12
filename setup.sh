#!/bin/bash

show_welcome() {
    clear  # Clear the screen for a clean look

    echo ""
    sleep 0.2
    echo " _   _      _ _          ____    _    __  __ ____           _ "
    sleep 0.2
    echo "| | | | ___| | | ___    / ___|  / \  |  \/  |  _ \ ___ _ __| |"
    sleep 0.2
    echo "| |_| |/ _ \ | |/ _ \  | |     / _ \ | |\/| | |_) / _ \ '__| |"
    sleep 0.2
    echo "|  _  |  __/ | | (_) | | |___ / ___ \| |  | |  __/  __/ |  |_|"
    sleep 0.2
    echo "|_| |_|\___|_|_|\___/   \____/_/   \_\_|  |_|_|   \___|_|  (_)"
    sleep 0.5

echo ""
echo "🌲🏕️   WELCOME TO CAMP SETUP! 🏕️ 🌲"
echo "===================================================="
echo ""
echo "   🏕️   Configuring Databases & Conda Environments"
echo "       for CAMP short-read QC"
echo ""
echo "   🔥 Let's get everything set up properly!"
echo ""
echo "===================================================="
echo ""

}

show_welcome

# Set work_dir
DEFAULT_PATH=$PWD
read -p "Enter the working directory (Press Enter for default: $DEFAULT_PATH): " USER_WORK_DIR
SR_QC_WORK_DIR="$(realpath "${USER_WORK_DIR:-$PWD}")"
echo "Working directory set to: $SR_QC_WORK_DIR"
#echo "export ${SR_QC_WORK_DIR} >> ~/.bashrc" 

# Download databses and index 
download_and_index() {
    GENOME_NAME=$1
    DOWNLOAD_URL=$2
    FILE_NAME=$3
    INDEX_NAME=$4
    INSTALL_PATH=$5

    # Create a dedicated directory inside the provided install path
    GENOME_DIR="$INSTALL_PATH/${INDEX_NAME}_ref_genome"
    mkdir -p "$GENOME_DIR"

    echo "Downloading $GENOME_NAME reference genome to $GENOME_DIR..."
    wget -O "$GENOME_DIR/$FILE_NAME.gz" "$DOWNLOAD_URL" || { echo "❌ Failed to download $GENOME_NAME."; return; }

    echo "Extracting genome file..."
    gunzip "$GENOME_DIR/$FILE_NAME.gz" || { echo "❌ Failed to extract $GENOME_NAME."; return; }

    echo "Building Bowtie2 index in $GENOME_DIR..."
    bowtie2-build "$GENOME_DIR/$FILE_NAME" "$GENOME_DIR/hg38_ref" || { echo "❌ Failed to build index for $GENOME_NAME."; return; }

    echo "✅ $GENOME_NAME genome downloaded and indexed successfully in $GENOME_DIR!"

    # Save host reference path as a global variable
    HOST_REFERENCE_PATH="$GENOME_DIR/$INDEX_NAME"
}

# Ask user for selection
while true; do
    echo "Select the reference genome to download and index:"
    echo "1) Human (hg38)"
    echo "2) Mouse (GRCm39)"
    echo "3) Skip"

    read -p "Enter your choice (1/2/3): " choice

    case $choice in
        1)
            read -p "Enter the directory where the genome should be installed: " INSTALL_DIR
            DB_PATH="$INSTALL_DIR/hg38_ref"
            mkdir -p $DB_PATH
	    break
            ;;
	2)
	   read -p "Enter the directory where the genome should be installed: " INSTALL_DIR
            DB_PATH="$INSTALL_DIR/GRCm39"
            mkdir -p $DB_PATH
	    break
            ;;
        3)
            echo "Skipping download and indexing."
            read -p "Would you like to provide an alternative path for the database? (y/n): " alt_choice
            if [[ "$alt_choice" == "y" || "$alt_choice" == "Y" ]]; then
                read -p "Enter the alternative database path: " HOST_REFERENCE_PATH
            else
                HOST_REFERENCE_PATH=""
            fi
            break
            ;;
        *)
            echo "⚠️ Invalid choice! Please enter 1, 2, or 3."
            ;;
    esac
done

case $choice in
    1)
        download_and_index "Human (hg38)" \
            "http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz" \
            "hg38.fa" \
            "hg38_index" \
            "$DB_PATH"
        ;;
    2)
        download_and_index "Mouse (GRCm39)" \
            "http://ftp.ensembl.org/pub/release-108/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna.primary_assembly.fa.gz" \
            "GRCm39.fa" \
            "mouse_index" \
            "$DB_PATH"
        ;;
esac

# Install conda env: bbmap, multiqc 
cd $DEFAULT_PATH
DEFAULT_CONDA_ENV_DIR=$(conda info --base)/envs

# Function to check and install conda environments
check_and_install_env() {
    ENV_NAME=$1
    CONFIG_PATH=$2

    if conda env list | grep -q "$DEFAULT_CONDA_ENV_DIR/$ENV_NAME"; then
        echo "✅ Conda environment $ENV_NAME already exists."
    else
        echo "Installing Conda environment $ENV_NAME from $CONFIG_PATH..."
        CONDA_CHANNEL_PRIORITY=flexible conda env create -f "$CONFIG_PATH" || { echo "❌ Failed to install $ENV_NAME."; return; }
    fi
}

# Check and install MultiQC and BBMap environments
check_and_install_env "multiqc" "configs/conda/multiqc.yaml"
check_and_install_env "bbmap" "configs/conda/bbmap.yaml"


# Generate parameters.yaml
SCRIPT_DIR=$(pwd)
EXT_PATH="$SR_QC_WORK_DIR/workflow/ext"
PARAMS_FILE="test_data/parameters.yaml"

# Remove existing parameters.yaml if present
[ -f "$PARAMS_FILE" ] && rm "$PARAMS_FILE"
# Create new parameters.yaml file
echo "#'''Parameters'''#
ext: '$EXT_PATH'
conda_prefix: '$DEFAULT_CONDA_ENV_DIR'

# --- general --- #

minqual:    30


# --- filter_low_qual --- #

dedup:      False


# --- filter_adapters --- #

adapters: '$SCRIPT_DIR/workflow/ext/common_adapters.txt'


# --- filter_host_reads --- #

use_host_filter:         True
host_reference_database: '$HOST_REFERENCE_PATH'


# --- filter_seq_errors --- #

# Options (must choose one): 'bayeshammer', 'tadpole'
error_correction: 'tadpole'


# --- qc-option --- #

qc_dataviz: True" > "$PARAMS_FILE"

echo "✅ parameters.yaml file created successfully in test_data/"
