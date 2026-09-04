#!/usr/bin/env bash
#SBATCH -J nanosim_default
#SBATCH -A chsi
#SBATCH -p chsi
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH -t 12:00:00
set -euo pipefail

: "${SLURM_ARRAY_TASK_ID:?Run with --array=0-3}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
REFERENCE="${REFERENCE:-/hpc/dctrl/qd33/reference_genome/reference.fasta}"
OUTDIR="${OUTDIR:-${ROOT}/data/nanosim_mapping/simulated_reads_default}"
MODEL_PREFIX="${MODEL_PREFIX:-${ROOT}/models/nanosim/human_giab_hg002_sub1M_kitv14_dorado_v3.2.1/training}"
NANOSIM_IMG="${NANOSIM_IMG:-docker://quay.io/biocontainers/nanosim:3.2.3--hdfd78af_2}"
READS_PER_GENOME="${READS_PER_GENOME:-200000}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

NAMES=(DCS_Lambda Mycoplasma_hominis Phocaeicola_vulgatus Corynebacterium_striatum)
PREFIXES=(DCS_Lambda ATCC_23114 ATCC_8482 ATCC_6940)

I="$SLURM_ARRAY_TASK_ID"
NAME="${NAMES[$I]}"
PREFIX="${PREFIXES[$I]}"
WORK="${SLURM_TMPDIR:-/tmp}/nanosim_${SLURM_JOB_ID}_${I}"
LOCAL_MODEL="${WORK}/model/training"
REF="${WORK}/${NAME}.fasta"
OUT="${OUTDIR}/${NAME}.fastq"
STAMP="${OUTDIR}/${NAME}.DONE.stamp"

mkdir -p "$WORK/model" "$OUTDIR"
[[ -f "$STAMP" && -s "$OUT" ]] && exit 0
cp -a "$(dirname "$MODEL_PREFIX")/." "$WORK/model/"
printf 'Aligned / Unaligned ratio:\t1000000000000\n' > "${LOCAL_MODEL}_reads_alignment_rate"
awk -v p="$PREFIX" '/^>/{keep=index($0, ">" p)==1} keep' "$REFERENCE" > "$REF"
[[ -s "$REF" ]]

TMP_OUT="${OUT}.tmp.${SLURM_JOB_ID}"
SEED=$((104729 + I * 1000))
PREFIX_OUT="${WORK}/${NAME}"
LENGTH_ARGS=()
[[ "$NAME" == "DCS_Lambda" ]] && LENGTH_ARGS=(-med 3525 -sd 0.094605 -min 3000 -max 3587)
SIMULATOR="simulator.py"

if [[ "$NAME" == "DCS_Lambda" ]]; then
  apptainer exec --bind "${WORK}" "$NANOSIM_IMG" \
    cp /usr/local/bin/simulator.py "${WORK}/simulator.py"
  sed -i 's/random.randint(0, genome_len)/random.randint(0, genome_len - length)/g' \
    "${WORK}/simulator.py"
  sed -i '/^                seg_pointer += segments$/i\                if any(x > genome_len for x in seg_length_list):\n                    continue\n' \
    "${WORK}/simulator.py"
  SIMULATOR="${WORK}/simulator.py"
fi

apptainer exec --bind "${ROOT}","$(dirname "$REFERENCE")","${WORK}" "$NANOSIM_IMG" \
  env PYTHONPATH=/usr/local/bin "$SIMULATOR" genome \
  -rg "$REF" -c "$LOCAL_MODEL" -n "$READS_PER_GENOME" \
  "${LENGTH_ARGS[@]}" --seed "$SEED" --fastq -t "$THREADS" -o "$PREFIX_OUT" >&2
awk -v tag="$NAME" 'NR%4==1{sub(/^@/, "@" tag "|")} {print}' \
  "${PREFIX_OUT}_aligned_reads.fastq" > "$TMP_OUT"

N=$(awk 'END{print NR/4}' "$TMP_OUT")
[[ "$N" -eq "$READS_PER_GENOME" ]]
mv "$TMP_OUT" "$OUT"
date > "$STAMP"
