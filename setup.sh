#!/bin/bash

# --- Functions ---

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
    echo "       for CAMP Short-Read QC"
    echo ""
    echo "   🔥 Let's get everything set up properly!"
    echo ""
    echo "===================================================="
    echo ""

}

# Check to see if the base CAMP environment has already been installed 
find_install_camp_env() {
    if conda env list | awk '{print $1}' | grep -xq "camp"; then 
        echo "✅ The main CAMP environment is already installed in $DEFAULT_CONDA_ENV_DIR."
    else
        echo "🚀 Installing the main CAMP environment in $DEFAULT_CONDA_ENV_DIR/..."
        conda create --prefix "$DEFAULT_CONDA_ENV_DIR/camp" -c conda-forge -c bioconda biopython blast bowtie2 bumpversion click click-default-group cookiecutter jupyter matplotlib numpy pandas samtools scikit-learn scipy seaborn snakemake=7.32.4 umap-learn upsetplot
        echo "✅ The main CAMP environment has been installed successfully!"
    fi
}

# Check to see if the required conda environments have already been installed 
find_install_conda_env() {
    if conda env list | grep -q "$DEFAULT_CONDA_ENV_DIR/$1"; then
        echo "✅ The $1 environment is already installed in $DEFAULT_CONDA_ENV_DIR."
    else
        echo "🚀 Installing $1 in $DEFAULT_CONDA_ENV_DIR/$1..."
        conda create --prefix $DEFAULT_CONDA_ENV_DIR/$1 -c conda-forge -c bioconda $1
        echo "✅ $1 installed successfully!"
    fi
}

# Ask user if each database is already installed or needs to be installed
ask_database() {
    local DB_NAME="$1"
    local DB_VAR_NAME="$2"
    local DB_PATH=""

    echo "🛠️  Checking for $DB_NAME database..."

    while true; do
        read -p "❓ Do you already have the $DB_NAME database installed? (y/n): " RESPONSE
        case "$RESPONSE" in
            [Yy]* )
                while true; do
                    read -p "📂 Enter the path to your existing $DB_NAME database (eg. /path/to/database_storage): " DB_PATH
                    if [[ -d "$DB_PATH" || -f "$DB_PATH" ]]; then
                        DATABASE_PATHS[$DB_VAR_NAME]="$DB_PATH"
                        echo "✅ $DB_NAME path set to: $DB_PATH"
                        return  # Exit the function immediately after successful input
                    else
                        echo "⚠️ The provided path does not exist or is empty. Please check and try again."
                        read -p "Do you want to re-enter the path (r) or install $DB_NAME instead (i)? (r/i): " RETRY
                        if [[ "$RETRY" == "i" ]]; then
                            break  # Exit outer loop to start installation
                        fi
                    fi
                done
                ;;
            [Nn]* )
                break # Exit outer loop to start installation
                ;; 
            * ) echo "⚠️ Please enter 'y(es)' or 'n(o)'.";;
        esac
    done
    read -p "📂 Enter the directory where you want to install $DB_NAME: " DB_PATH
    install_database "$DB_NAME" "$DB_VAR_NAME" "$DB_PATH"
}

# Install databases in the specified directory
install_database() {
    local DB_NAME="$1"
    local DB_VAR_NAME="$2"
    local INSTALL_DIR="$3"
    local FINAL_DB_PATH="$INSTALL_DIR/${DB_SUBDIRS[$DB_VAR_NAME]}"

    echo "🚀 Installing $DB_NAME database in: $FINAL_DB_PATH"	

    case "$DB_VAR_NAME" in
        "DATABASE_1_PATH")
            wget -c https://repository1.com/database_1.tar.gz -P $INSTALL_DIR
            mkdir -p $FINAL_DB_PATH
	        tar -xzf "$INSTALL_DIR/database_1.tar.gz" -C "$FINAL_DB_PATH"
            echo "✅ Database 1 installed successfully!"
            ;;
        "DATABASE_2_PATH")
            wget https://repository2.com/database_2.tar.gz -P $INSTALL_DIR
	        mkdir -p $FINAL_DB_PATH
            tar -xzf "$INSTALL_DIR/database_2.tar.gz" -C "$FINAL_DB_PATH"
            echo "✅ Database 2 installed successfully!"
            ;;
        *)
            echo "⚠️ Unknown database: $DB_NAME"
            ;;
    esac

    DATABASE_PATHS[$DB_VAR_NAME]="$FINAL_DB_PATH"
}

# --- Initialize setup ---

show_welcome

# Set work_dir
MODULE_WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PATH=$PWD
read -p "Enter the working directory (Press Enter for default: $DEFAULT_PATH): " USER_WORK_DIR
SR_QC_WORK_DIR="$(realpath "${USER_WORK_DIR:-$PWD}")"
echo "Working directory set to: $SR_QC_WORK_DIR"
#echo "export ${SR_QC_WORK_DIR} >> ~/.bashrc" 

# --- Install conda environments ---

cd $MODULE_WORK_DIR
DEFAULT_CONDA_ENV_DIR=$(conda info --base)/envs

# Find or install...

# ...module environment
find_install_camp_env

# ...auxiliary environments
MODULE_PKGS=('fastp' 'adapterremoval' 'spades' 'bbmap' 'fastqc' 'multiqc') # Add any additional conda packages here
for m in "${MODULE_PKGS[@]}"; do
    find_install_conda_env "$m"
done

# --- Download databases ---

# Download databses and index 
download_and_index() {
    GENOME_NAME=$1
    DOWNLOAD_URL=$2
    FILE_NAME=$3
    INDEX_NAME=$4
    INSTALL_PATH=$5

    # Create a dedicated directory inside the provided install path
    GENOME_DIR="$INSTALL_PATH"
    mkdir -p "$GENOME_DIR"

    echo "Downloading $GENOME_NAME reference genome to $GENOME_DIR..."
    wget -O "$GENOME_DIR/$FILE_NAME.gz" "$DOWNLOAD_URL" || { echo "❌ Failed to download $GENOME_NAME."; return; }

    echo "Extracting genome file..."
    gunzip "$GENOME_DIR/$FILE_NAME.gz" || { echo "❌ Failed to extract $GENOME_NAME."; return; }

    conda activate camp
    echo "Building Bowtie2 index in $GENOME_DIR..."
    bowtie2-build "$GENOME_DIR/$FILE_NAME" "$GENOME_DIR/hg38_index" || { echo "❌ Failed to build index for $GENOME_NAME."; return; }
    conda deactivate
    
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
            HOST_FILTER='True'
	        break
            ;;
        2)
            read -p "Enter the directory where the genome should be installed: " INSTALL_DIR
            DB_PATH="$INSTALL_DIR/GRCm39"
            mkdir -p $DB_PATH
            HOST_FILTER='True'
            break
                ;;
        3)
            echo "Skipping download and indexing."
            read -p "Would you like to provide an alternative path for the database? (y/n): " alt_choice
            if [[ "$alt_choice" == "y" || "$alt_choice" == "Y" ]]; then
                read -p "Enter the alternative database path: " HOST_REFERENCE_PATH
                HOST_FILTER='True'
            else
                HOST_REFERENCE_PATH=""
                HOST_FILTER='False'
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

# --- Generate parameter configs ---

# Generate parameters.yaml
SCRIPT_DIR=$(pwd)
EXT_PATH="$SR_QC_WORK_DIR/workflow/ext"

PARAMS_FILE="$MODULE_WORK_DIR/test_data/parameters.yaml"
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

adapters: '$EXT_PATH/common_adapters.txt'


# --- filter_host_reads --- #

use_host_filter:         '$HOST_FILTER'
host_ref_genome:         '$HOST_REFERENCE_PATH'


# --- filter_seq_errors --- #

# Options (must choose one): 'bayeshammer', 'tadpole'
error_correction: 'tadpole'


# --- qc-option --- #

qc_dataviz: True" > "$PARAMS_FILE"

echo "✅ parameters.yaml file created successfully in test_data/"

PARAMS_FILE="$MODULE_WORK_DIR/configs/parameters.yaml"
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

adapters: '$EXT_PATH/common_adapters.txt'


# --- filter_host_reads --- #

use_host_filter:         '$HOST_FILTER'
host_ref_genome:         '$HOST_REFERENCE_PATH'


# --- filter_seq_errors --- #

# Options (must choose one): 'bayeshammer', 'tadpole'
error_correction: 'tadpole'


# --- qc-option --- #

qc_dataviz: True" > "$PARAMS_FILE"

echo "✅ parameters.yaml file created successfully in configs/"

# --- Generate test data input CSV ---

# Create test_data/samples.csv
INPUT_CSV="$MODULE_WORK_DIR/test_data/samples.csv" 

echo "🚀 Generating test_data/samples.csv in $INPUT_CSV ..."

cat <<EOL > "$INPUT_CSV"
sample_name,illumina_fwd,illumina_rev
uhgg,$MODULE_WORK_DIR/test_data/uhgg_1.fastq.gz,$MODULE_WORK_DIR/test_data/uhgg_2.fastq.gz

EOL

echo "✅ Test data input CSV created at: $INPUT_CSV"

echo "🎯 Setup complete! You can now test the workflow using \`python workflow/short-read-quality-control.py test\`"
