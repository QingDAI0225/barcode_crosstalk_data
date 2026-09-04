#!/usr/bin/env bash
#SBATCH -J nanosim_stats
#SBATCH -A chsi
#SBATCH -p chsi
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH -t 02:00:00
set -euo pipefail

MODE="${1:-empirical_length}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
SAMTOOLS_IMG="${SAMTOOLS_IMG:-docker://quay.io/biocontainers/samtools:1.22.1--h96c455f_0}"

case "$MODE" in
  default_length)
    BAMDIR="${BAMDIR:-${ROOT}/data/nanosim_mapping/dorado_mapping_default}"
    OUTDIR="${OUTDIR:-${ROOT}/data/nanosim_mapping/summary_default}"
    ;;
  empirical_length)
    BAMDIR="${BAMDIR:-${ROOT}/data/nanosim_mapping/dorado_mapping_empirical_length}"
    OUTDIR="${OUTDIR:-${ROOT}/data/nanosim_mapping/summary_empirical_length}"
    ;;
  *)
    echo "Usage: sbatch $0 {default_length|empirical_length}" >&2
    exit 2
    ;;
esac

NAMES=(DCS_Lambda Mycoplasma_hominis Phocaeicola_vulgatus Corynebacterium_striatum)
CONF="${OUTDIR}/mapping_confusion.tsv"
SUMMARY="${OUTDIR}/mapping_summary.tsv"
MATRIX="${OUTDIR}/mapping_confusion_matrix.tsv"
CONF_TMP="${CONF}.tmp.${SLURM_JOB_ID:-$$}"
SUMMARY_TMP="${SUMMARY}.tmp.${SLURM_JOB_ID:-$$}"
MATRIX_TMP="${MATRIX}.tmp.${SLURM_JOB_ID:-$$}"

mkdir -p "$OUTDIR"
printf 'true_genome\tobserved_genome\treads\tproportion_all_reads\tproportion_mapped_reads\n' > "$CONF_TMP"
printf 'true_genome\ttotal_reads\tmapped_reads\tcorrect_reads\tmisassigned_reads\tunmapped_reads\tmapping_rate\tcorrect_rate_all\tmisassignment_rate_all\tmisassignment_rate_mapped\n' > "$SUMMARY_TMP"

for TRUE in "${NAMES[@]}"; do
  BAM="${BAMDIR}/${TRUE}.bam"
  [[ -s "$BAM" ]]
  apptainer exec --bind "${ROOT}" "$SAMTOOLS_IMG" samtools view -F 2304 "$BAM" | \
    awk -v truth="$TRUE" -v conf="$CONF_TMP" -v summary="$SUMMARY_TMP" '
      BEGIN {
        name[1]="DCS_Lambda"; name[2]="Mycoplasma_hominis";
        name[3]="Phocaeicola_vulgatus"; name[4]="Corynebacterium_striatum";
        name[5]="unmapped"
      }
      {
        total++
        flag=$2+0
        ref=$3
        if (and(flag,4)) observed="unmapped"
        else if (index(ref,"DCS_Lambda")==1) observed="DCS_Lambda"
        else if (index(ref,"ATCC_23114")==1) observed="Mycoplasma_hominis"
        else if (index(ref,"ATCC_8482")==1) observed="Phocaeicola_vulgatus"
        else if (index(ref,"ATCC_6940")==1) observed="Corynebacterium_striatum"
        else {
          print "Unrecognized reference: " ref > "/dev/stderr"
          exit 2
        }
        count[observed]++
      }
      END {
        mapped=total-count["unmapped"]
        correct=count[truth]
        wrong=mapped-correct
        for (i=1;i<=5;i++) {
          observed=name[i]
          mapped_prop=(observed=="unmapped" || mapped==0) ? "NA" : count[observed]/mapped
          printf "%s\t%s\t%d\t%.10g\t%s\n", truth, observed, count[observed], count[observed]/total, mapped_prop >> conf
        }
        printf "%s\t%d\t%d\t%d\t%d\t%d\t%.10g\t%.10g\t%.10g\t%.10g\n", truth, total, mapped, correct, wrong, count["unmapped"], mapped/total, correct/total, wrong/total, wrong/mapped >> summary
      }
    '
done

mv "$CONF_TMP" "$CONF"
mv "$SUMMARY_TMP" "$SUMMARY"

awk -F '\t' 'BEGIN {
  OFS="\t"
  split("DCS_Lambda Mycoplasma_hominis Phocaeicola_vulgatus Corynebacterium_striatum", genome, " ")
  print "true_genome", genome[1], genome[2], genome[3], genome[4], "unmapped"
}
NR > 1 { count[$1 SUBSEP $2] = $3 }
END {
  for (i = 1; i <= 4; i++) {
    printf "%s", genome[i]
    for (j = 1; j <= 4; j++) printf "\t%d", count[genome[i] SUBSEP genome[j]] + 0
    printf "\t%d\n", count[genome[i] SUBSEP "unmapped"] + 0
  }
}' "$CONF" > "$MATRIX_TMP"

mv "$MATRIX_TMP" "$MATRIX"
