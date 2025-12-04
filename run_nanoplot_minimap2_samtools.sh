#!/usr/bin/env bash
#SBATCH --job-name=mapont_qc
#SBATCH --cpus-per-task=10                 # threads for NanoPlot/minimap2/samtools
#SBATCH --time=24:00:00
#SBATCH --mem=16G
#SBATCH --output=logs/%x_%A_%a.out
# Optionally pin defaults here (otherwise pass via sbatch flags):
# #SBATCH --partition=<your_partition>
# #SBATCH --account=<your_account>

set -euo pipefail

# ======================= Usage & Required Args =======================
# Run as a Slurm array job where each task handles one *.fastq.gz.
# Args:
#   $1 = INPUT_DIR   (directory containing *.fastq.gz; non-recursive)
#   $2 = REF_FA      (reference FASTA)
#   $3 = MAP_DIR     (mapping outputs: flat files in this single directory)
#   $4 = QC_DIR      (QC outputs: per-sample subdirs under this directory)
#   $5 = THREADS     (optional; defaults to --cpus-per-task)
#
# Example submit:
#   INPUT_DIR=/path/to/fastqs
#   REF_FA=/path/to/ref.fa
#   MAP_DIR=/path/to/map_out
#   QC_DIR=/path/to/qc_out
#   THREADS=10
#   PARTITION=your_partition
#   ACCOUNT=your_account
#   MAX_CONCURRENT=50
#   N=$(ls -1 "$INPUT_DIR"/*.fastq.gz 2>/dev/null | wc -l)
#   sbatch -p "$PARTITION" -A "$ACCOUNT" \
#     --cpus-per-task="$THREADS" --mem=24G --time=24:00:00 \
#     --array=0-$((N-1))%${MAX_CONCURRENT} \
#     run_nanoplot_minimap2_samtools.sh "$INPUT_DIR" "$REF_FA" "$MAP_DIR" "$QC_DIR" "$THREADS"

# ======================= Parameters =======================
INPUT_DIR="${1:?usage: sbatch --array=0-(N-1)%M run_nanoplot_minimap2_samtools.sh INPUT_DIR REF_FA MAP_DIR QC_DIR [THREADS]}"
REF_FA="${2:?missing REF_FA}"
MAP_DIR="${3:?missing MAP_DIR}"
QC_DIR="${4:?missing QC_DIR}"
THREADS="${5:-${SLURM_CPUS_PER_TASK:-8}}"

# Containers (Apptainer pulls Docker URIs as needed)
NANOPLOT_IMG="docker://quay.io/biocontainers/nanoplot:1.44.1--pyhdfd78af_0"
MM2_IMG="docker://quay.io/biocontainers/minimap2:2.28--he4a0461_3"
SAMTOOLS_IMG="docker://quay.io/biocontainers/samtools:1.22.1--h96c455f_0"

# Make base dirs (logs stay in CWD unless you change #SBATCH --output)
mkdir -p "$MAP_DIR" "$QC_DIR" logs

# ======================= Path normalization =======================
abs_path() { python3 - "$1" <<'PY'
import os,sys; print(os.path.abspath(sys.argv[1]))
PY
}
INPUT_DIR="$(abs_path "$INPUT_DIR")"
REF_FA="$(abs_path "$REF_FA")"
MAP_DIR="$(abs_path "$MAP_DIR")"
QC_DIR="$(abs_path "$QC_DIR")"

[ -d "$INPUT_DIR" ] || { echo "INPUT_DIR not found: $INPUT_DIR" >&2; exit 1; }
[ -r "$REF_FA" ]    || { echo "REF_FA not readable: $REF_FA" >&2; exit 1; }

# ======================= Resolve array item =======================
mapfile -t READS < <(find "$INPUT_DIR" -maxdepth 1 -type f -name '*.fastq.gz' | sort)
TOTAL="${#READS[@]}"
if (( TOTAL == 0 )); then
  echo "No .fastq.gz in $INPUT_DIR"; exit 0
fi
: "${SLURM_ARRAY_TASK_ID:?This script must be run as a Slurm array job}"
if (( SLURM_ARRAY_TASK_ID >= TOTAL )); then
  echo "Array index ${SLURM_ARRAY_TASK_ID} out of range (TOTAL=$TOTAL)"; exit 1
fi

fq="${READS[$SLURM_ARRAY_TASK_ID]}"
bn="$(basename "$fq")"
sample="${bn%.fastq.gz}"

# Mapping outputs (flat in MAP_DIR, sample-prefixed)
SAM_OUT="$MAP_DIR/${sample}.sam"
BAM_OUT="$MAP_DIR/${sample}.bam"
SORTED_BAM="$MAP_DIR/${sample}.sorted.bam"
IDXSTATS_TSV="$MAP_DIR/${sample}.idxstats.tsv"

# NanoPlot outputs (per-sample subdir)
QC_OUT_DIR="$QC_DIR/$sample"
mkdir -p "$QC_OUT_DIR"

echo "[$(date)] START  sample=$sample  threads=$THREADS  array=${SLURM_ARRAY_TASK_ID}/${TOTAL}"

# ======================= Step 0: NanoPlot QC =======================
apptainer exec \
  --bind "$INPUT_DIR":"$INPUT_DIR","$QC_DIR":"$QC_DIR" \
  "$NANOPLOT_IMG" \
  sh -lc "NanoPlot -t ${THREADS} --fastq '$fq' --loglength -o '$QC_OUT_DIR'"

# ======================= Step 1: minimap2 (map-ont) -> SAM =======================
apptainer exec \
  --bind "$INPUT_DIR":"$INPUT_DIR","$MAP_DIR":"$MAP_DIR","$(dirname "$REF_FA")":"$(dirname "$REF_FA")" \
  "$MM2_IMG" \
  sh -lc "minimap2 -t ${THREADS} -ax map-ont '$REF_FA' '$fq' > '$SAM_OUT'"

# ======================= Step 2: samtools view/sort/index/idxstats =======================
apptainer exec \
  --bind "$MAP_DIR":"$MAP_DIR" \
  "$SAMTOOLS_IMG" \
  sh -lc "
    set -euo pipefail
    samtools view -@ ${THREADS} -bS '$SAM_OUT' > '$BAM_OUT'
    samtools sort -@ ${THREADS} -o '$SORTED_BAM' '$BAM_OUT'
    samtools index '$SORTED_BAM'
    samtools idxstats '$SORTED_BAM' > '$IDXSTATS_TSV'
  "

# ======================= Cleanup & Summary =======================
# Keep: BAM (unsorted), sorted BAM/BAI, idxstats; Remove: SAM
rm -f "$SAM_OUT"

echo "[$(date)] DONE  sample=$sample"
echo "  QC dir : $QC_OUT_DIR"
echo "  kept   : $BAM_OUT"
echo "  outputs: $SORTED_BAM  ${SORTED_BAM}.bai  $IDXSTATS_TSV"
