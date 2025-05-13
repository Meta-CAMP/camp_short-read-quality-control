# Short-Read Quality Control

![Version](https://img.shields.io/badge/version-0.12.0-brightgreen)

<!-- [![Documentation Status](https://img.shields.io/readthedocs/camp_short-read-quality-control)](https://camp-documentation.readthedocs.io/en/latest/shortreadqc/index.html) -->

## Overview

This module is designed to function as both a standalone MAG short-read quality control pipeline as well as a component of the larger CAMP metagenome analysis pipeline. As such, it is both self-contained (ex. instructions included for the setup of a versioned environment, etc.), and seamlessly compatible with other CAMP modules (ex. ingests and spawns standardized input/output config files, etc.). 

There are two filtration steps in the module- i) for general poor quality (Phred scores, length, Ns, adapters, polyG/X) and ii) for host reads- followed by a sequencing error correction step. The properties of the QC-ed FastQs are summarized in aggregate by a MultiQC report. 

## Installation

### Install `conda`

If you don't already have `conda` handy, we recommend installing `miniforge`, which is a minimal conda installer that, by default, installs packages from open-source community-driven channels such as `conda-forge`.
```Bash
# If you don't already have conda on your system...
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
```

Run the following command to initialize Conda for your shell. This will configure your shell to recognize conda activate. 
```Bash
conda init
```

Restart your terminal or run:
```Bash
source ~/.bashrc  # For bash users
source ~/.zshrc   # For zsh users
```
### Setting up the Short-Read QC Module

1. Clone repo from [Github](<https://github.com/Meta-CAMP/camp_short-read-quality-control>).
```Bash
git clone https://github.com/Meta-CAMP/camp_short-read-quality-control
```

2. Automated setup by downloading and indexing host reference genome(s). In the `setup.sh` script, indexing is done using 20 threads. The user can modify this parameter based on the capacity of their machine.

This step also automatically updates `configs/parameters.yaml` and `test_data/parameters.yaml`, which are needed in running the module and the test respectively. 
```Bash
cd camp_short-read-quality-control/
source setup.sh
```

Alternatively, one can choose to manually download and index reference genomes and update the `host_reference_database` section in the respective `parameters.yaml`. 
For instance, the human reference genome (GRCh38) can be downloaded and indexed as follows:
```Bash
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/GCA_000001405.15_GRCh38_genomic.fna.gz
bowtie2-build --threads 20 GCA_000001405.15_GRCh38_genomic.fna.gz GCA_000001405.15_GRCh38_genomic
```
As of now, `setup.sh` provides two download options: human and mouse.

4. Make sure the installed pipeline works correctly. With 40 threads and a maximum of 150 GB allocated for a command (`tadpole`), the test dataset should finish in approximately 6 minutes.
```Bash
# Run tests on the included sample dataset
conda activate camp
python camp_short-read-quality-control/workflow/short-read-quality-control.py test
```

## Using the Module

**Input**: `/path/to/samples.csv` provided by the user.

**Output**: 1) An output config file summarizing the locations of the error-corrected FastQs, 2) summary statistics about the dataset after each error correction step indicating how many reads and/or bases were pruned, and 3) the MultiQC report summarizing the properties for the QC-ed FastQ. For more information, see the demo test output directory in `test_data/test_out`. 

- `/path/to/work/dir/short_read_qc/final_reports/samples.csv` for ingestion by the next module

- `/path/to/work/dir/short_read_qc/final_reports/read_stats.csv`

- Optional: `/path/to/work/dir/short_read_qc/final_reports/*_multiqc_report.html`, where `*` is 'pre' or 'post'-module

### Module Structure
```
└── workflow
    ├── Snakefile
    ├── short-read-quality-control.py
    ├── utils.py
    ├── __init__.py
    └── ext/
        └── scripts/
```
- `workflow/short-read-quality-control.py`: Click-based CLI that wraps the `snakemake` and other commands for clean management of parameters, resources, and environment variables.
- `workflow/Snakefile`: The `snakemake` pipeline. 
- `workflow/utils.py`: Sample ingestion and work directory setup functions, and other utility functions used in the pipeline and the CLI.
- `ext/`: External programs, scripts, and small auxiliary files that are not conda-compatible but used in the workflow.

### Running the Workflow

1. Make your own `samples.csv` based on the template in `configs/samples.csv`.
    - `ingest_samples` in `workflow/utils.py` expects Illumina reads in FastQ (may be gzipped) form 
    - `samples.csv` requires either absolute paths or paths relative to the directory that the module is being run in

2. Update the relevant parameters in `configs/parameters.yaml`.

3. Update the computational resources available to the pipeline in `configs/resources.yaml`. 

#### Command Line Deployment

To run CAMP on the command line, use the following, where `/path/to/work/dir` is replaced with the absolute path of your chosen working directory, and `/path/to/samples.csv` is replaced with your copy of `samples.csv`. 
    - The default number of cores available to Snakemake is 1 which is enough for test data, but should probably be adjusted to 10+ for a real dataset.
    - Relative or absolute paths to the Snakefile and/or the working directory (if you're running elsewhere) are accepted!
    - The parameters and resource config YAMLs can also be customized.
```Bash
conda activate camp
python /path/to/camp_short-read-quality-control/workflow/short-read-quality-control.py \
    (-c number_of_cores_allocated) \
    (-p /path/to/parameters.yaml) \
    (-r /path/to/resources.yaml) \
    -d /path/to/work/dir \
    -s /path/to/samples.csv
```

#### Slurm Cluster Deployment

To run CAMP on a job submission cluster (for now, only Slurm is supported), use the following.
    - `--slurm` is an optional flag that submits all rules in the Snakemake pipeline as `sbatch` jobs. 
    - In Slurm mode, the `-c` flag refers to the maximum number of `sbatch` jobs submitted in parallel, **not** the pool of cores available to run the jobs. Each job will request the number of cores specified by threads in `configs/resources/slurm.yaml`.
```Bash
conda activate camp
sbatch -J jobname -o jobname.log << "EOF"
#!/bin/bash
python /path/to/camp_short-read-quality-control/workflow/short-read-quality-control.py --slurm \
    (-c max_number_of_parallel_jobs_submitted) \
    (-p /path/to/parameters.yaml) \
    (-r /path/to/resources.yaml) \
    -d /path/to/work/dir \
    -s /path/to/samples.csv
EOF
```

#### Finishing Up

1. To quality-check the processed FastQs, download and compare the collated MultiQC reports, which can be found at `/path/to/work/dir/short_read_qc/final_reports/*_multiqc_report/html`. Multiple rounds of preprocessing may be needed to fully get rid of low-quality bases, adapters, and duplicated sequences. 
    - For example, the dataset I worked with required an additional round of `fastp` to trim 10 low-quality bases from the 5' and 4 low-quality bases from the 3' end respectively. 
    - I recommend creating a new directory, which I've called `/path/to/work/dir/short_read_qc/5_retrimming` and placing reprocessed reads inside them. 
    - Afterwards, I reran FastQC and MultiQC and collated summary statistics (ex. numbers of reads, etc.) from the reprocessed datasets manually. I also updated the location of the reprocessed reads in `/path/to/work/dir/short_read_qc/final_reports/samples.csv` to `/path/to/work/dir/short_read_qc/5_retrimming`.

2. To plot grouped bar graph(s) of the number of reads and bases remaining after each quality control step in each sample, and follow the instructions in the Jupyter notebook:
```Bash
jupyter notebook &
```

3. After checking over `final_reports/` and making sure you have everything you need, you can delete all intermediate files to save space. 
```Bash
python3 /path/to/camp_short-read-quality-control/workflow/short-read-quality-control.py cleanup \
    -d /path/to/work/dir \
    -s /path/to/samples.csv
```

4. If for some reason the module keeps failing, CAMP can print a script containing all of the remaining commands that can be run manually. 
```Bash
python3 /path/to/camp_short-read-quality-control/workflow/short-read-quality-control.py --dry_run \
    -d /path/to/work/dir \
    -s /path/to/samples.csv
```

## Credits

- This package was created with [Cookiecutter](https://github.com/cookiecutter/cookiecutter>) as a simplified version of the [project template](https://github.com/audreyr/cookiecutter-pypackage>).
- Free software: MIT
- Documentation: https://camp-documentation.readthedocs.io/en/latest/short-read-quality-control.html



