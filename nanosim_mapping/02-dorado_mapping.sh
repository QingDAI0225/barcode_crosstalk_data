#!/usr/bin/env bash
#SBATCH -J nanosim_map
#SBATCH -A chsi
#SBATCH -p chsi
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH -t 12:00:00
set -euo pipefail

: "${SLURM_ARRAY_TASK_ID:?Run with --array=0-3}"

MODE="${1:-empirical_length}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
REFERENCE="${REFERENCE:-/hpc/dctrl/qd33/reference_genome/reference.fasta}"
DORADO_IMG="${DORADO_IMG:-docker://ontresearch/dorado:sha00aa724a69ddc5f47d82bd413039f912fdaf4e77}"

case "$MODE" in
  default_length)
    READDIR="${READDIR:-${ROOT}/data/nanosim_mapping/simulated_reads_default}"
    OUTDIR="${OUTDIR:-${ROOT}/data/nanosim_mapping/dorado_mapping_default}"
    ;;
  empirical_length)
    READDIR="${READDIR:-${ROOT}/data/nanosim_mapping/simulated_reads_empirical_length}"
    OUTDIR="${OUTDIR:-${ROOT}/data/nanosim_mapping/dorado_mapping_empirical_length}"
    ;;
  *)
    echo "Usage: sbatch --array=0-3 $0 {default_length|empirical_length}" >&2
    exit 2
    ;;
esac

NAMES=(DCS_Lambda Mycoplasma_hominis Phocaeicola_vulgatus Corynebacterium_striatum)
NAME="${NAMES[$SLURM_ARRAY_TASK_ID]}"
FASTQ="${READDIR}/${NAME}.fastq"
BAM="${OUTDIR}/${NAME}.bam"
BAI="${BAM}.bai"
STAMP="${OUTDIR}/${NAME}.DONE.stamp"
WORK="${SLURM_TMPDIR:-/tmp}/dorado_map_${MODE}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

mkdir -p "$WORK" "$OUTDIR"
[[ -f "$STAMP" && -s "$BAM" ]] && exit 0
[[ -s "$FASTQ" ]]

apptainer -s run --bind "${ROOT}","$(dirname "$REFERENCE")","${WORK}" "$DORADO_IMG" \
  dorado aligner "$REFERENCE" "$FASTQ" --output-dir "$WORK/output"

mapfile -t BAMS < <(find "$WORK/output" -type f -name '*.bam')
[[ "${#BAMS[@]}" -eq 1 ]]
mv "${BAMS[0]}" "$BAM"
[[ -f "${BAMS[0]}.bai" ]] && mv "${BAMS[0]}.bai" "$BAI"
date > "$STAMP"
