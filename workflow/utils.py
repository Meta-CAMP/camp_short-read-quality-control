'''Utilities.'''


# --- Workflow setup --- #


import glob
import gzip
import os
from os import makedirs, symlink
from os.path import abspath, exists, join
import pandas as pd
import shutil
import yaml

def get_conda_prefix(yaml_file):
    """Load conda_prefix from parameters.yaml."""
    with open(yaml_file, "r") as file:
        config = yaml.safe_load(file)
    return config.get("conda_prefix", "Not Found")  # Default value if key is missing


def extract_from_gzip(ap, out):
    if open(ap, 'rb').read(2) != b'\x1f\x8b': # If the input is not gzipped
        with open(ap, 'rb') as f_in, gzip.open(out, 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)
    else: # Otherwise, symlink
        symlink(ap, out)


def ingest_samples(samples, tmp):
    df = pd.read_csv(samples, header = 0, index_col = 0) # name, fwd, rev
    s = list(df.index)
    lst = df.values.tolist()
    for i,l in enumerate(lst):
        if not exists(join(tmp, s[i] + '_1.fastq.gz')):
            extract_from_gzip(abspath(l[0]), join(tmp, s[i] + '_1.fastq.gz'))
            extract_from_gzip(abspath(l[1]), join(tmp, s[i] + '_2.fastq.gz'))
    return s


def check_make(d):
    if not exists(d):
        makedirs(d)


class Workflow_Dirs:
    """Management of the working directory tree."""
    OUT = ''
    TMP = ''
    LOG = ''

    def __init__(self, work_dir, module):
        self.OUT = join(work_dir, module)
        self.TMP = join(work_dir, 'tmp') 
        self.LOG = join(work_dir, 'logs') 
        check_make(self.OUT)
        out_dirs = ['0_lowqual_removal', '1_adapter_removal', '2_host_removal', '3_error_removal', '4_summary', 'final_reports']
        for d in out_dirs: 
            check_make(join(self.OUT, d))
        check_make(self.TMP)
        check_make(self.LOG)
        log_dirs = ['lowqual_removal', 'adapter_removal', 'host_removal', 'error_removal']
        for d in log_dirs: 
            check_make(join(self.LOG, d))


def print_cmds(f):
    # fo = basename(log).split('.')[0] + '.cmds'
    # lines = open(log, 'r').read().split('\n')
    fi = [l for l in f.split('\n') if l != '']
    write = False
    with open('commands.sh', 'w') as f_out:
        for l in fi:
            if 'rule' in l:
                f_out.write('# ' + l.strip().replace('rule ', '').replace(':', '') + '\n')
                write = False
            if 'wildcards' in l:
                f_out.write('# ' + l.strip().replace('wildcards: ', '') + '\n')
            if 'resources' in l:
                write = True
                l = ''
            if write:
                f_out.write(l.strip() + '\n')
            if 'rule make_config' in l:
                break


def cleanup_files(work_dir, df):
    smps = list(df.index)
    for s in smps:
        for d in ['1', '2']:
            for dir in ['0_lowqual_removal', '1_adapter_removal', '2_host_removal']:
                os.remove(join(work_dir, 'short_read_qc', dir, s + '_' + d + '.fastq.gz'))
            for dir in glob.glob(join(work_dir, 'short_read_qc', '3_error_removal')):
                os.remove(join(work_dir, 'short_read_qc', '3_error_removal', dir, s + '_tmp_' + d + '.fastq.gz'))


# --- Workflow functions --- #


def calc_read_lens(sp, st, fqs, fo): # A list of FastQ files
    # Extract read sequences and their lengths
    seq_lens = []
    for fq in fqs:
        with gzip.open(fq, 'rt') if 'gz' in fq else open(fq, 'r') as f:
            for i,l in enumerate(f):
                if i % 4 == 1:
                    seq_lens.append(len(l.strip()))
    line = "%s,%s,%d,%d,%.2f" % (sp, st, len(seq_lens), sum(seq_lens), float(sum(seq_lens)/len(seq_lens)))
    with open(fo, 'w') as f_out:
        f_out.write(line + '\n')


def sample_statistics(stats, fo):
    dfs = []
    for s in stats:
        dfs.append(pd.read_csv(s, header = None))
    merged_df = pd.concat(dfs) # sample_name,step,num_reads,total_size,mean_read_len
    begin_row = merged_df.iloc[:,1] == '0_begin'
    merged_df.loc[:,5] = merged_df.iloc[:,2]/int(merged_df.loc[begin_row,2]) # prop_init_reads
    merged_df.loc[:,6] = merged_df.iloc[:,3]/int(merged_df.loc[begin_row,3]) # prop_init_bases
    merged_df = merged_df.reindex(columns=[0,1,2,5,3,6,4])
    merged_df.to_csv(str(fo), header = False, index = False)




            
