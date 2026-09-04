#!/usr/bin/env python3
#SBATCH -J nanosim_truncate
#SBATCH -A chsi
#SBATCH -p chsi
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH -t 06:00:00
import csv
import os
import random
import re
import statistics
from datetime import datetime
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parents[1]
ROOT = Path(os.environ.get("ROOT", REPO_DIR.parent))
DATA_ROOT = Path(os.environ.get("DORADO_RESULTS_ROOT", ROOT / "data/dorado_results"))
SHEET_DIR = REPO_DIR / "sample_sheet"
READDIR = Path(os.environ.get(
    "READDIR", ROOT / "data/nanosim_mapping/simulated_reads_default"
))
OUTDIR = Path(os.environ.get(
    "OUTDIR", ROOT / "data/nanosim_mapping/simulated_reads_empirical_length"
))
N_READS = int(os.environ.get("READS_PER_GENOME", "200000"))

RUNS = (
    "20251018_MPI_CLO_3ng",
    "20251019_LCI_PMO_3ng",
    "20251020_MLI_PCO_20ng",
    "20251023_CPI_LMO_20ng",
    "20251026_PMI_LCO_20ng",
    "20251029_LMI_CPO_3ng",
)
GENOMES = (
    ("Mycoplasma_hominis", "M"),
    ("Phocaeicola_vulgatus", "P"),
    ("Corynebacterium_striatum", "C"),
)


def link_dcs_lambda():
    for suffix in ("fastq", "DONE.stamp"):
        source = READDIR / f"DCS_Lambda.{suffix}"
        destination = OUTDIR / f"DCS_Lambda.{suffix}"
        if not source.exists():
            raise RuntimeError(f"Missing {source}")
        try:
            destination.hardlink_to(source)
        except FileExistsError:
            pass


def barcode_for_run(run, alias_code):
    path = SHEET_DIR / f"{run}_sample_sheet.csv"
    with path.open(newline="") as handle:
        for row in csv.DictReader(handle):
            if row["alias"] == alias_code:
                return row["barcode"]
    raise RuntimeError(f"No {alias_code} barcode in {path}")


def empirical_lengths(run, barcode):
    path = DATA_ROOT / run / "either_end/merged_bam/sequencing_summary_merged.txt"
    values = []
    with path.open() as handle:
        header = handle.readline().rstrip("\n").split("\t")
        alias_i = header.index("alias")
        type_i = header.index("type")
        length_i = header.index("sequence_length_template")
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            alias = fields[alias_i]
            read_type = fields[type_i]
            called = alias if re.fullmatch(r"barcode[0-9]+", alias) else read_type
            if called != barcode:
                continue
            try:
                length = int(float(fields[length_i]))
            except ValueError:
                continue
            if length > 0:
                values.append(length)
    if not values:
        raise RuntimeError(f"No lengths for {barcode} in {path}")
    return values


def fastq_lengths(path):
    lengths = []
    with path.open() as handle:
        while True:
            header = handle.readline()
            if not header:
                break
            sequence = handle.readline().rstrip("\n")
            plus = handle.readline()
            quality = handle.readline().rstrip("\n")
            if not header.startswith("@") or not plus.startswith("+"):
                raise RuntimeError(f"Malformed FASTQ: {path}")
            if len(sequence) != len(quality):
                raise RuntimeError(f"Sequence/quality length mismatch: {path}")
            lengths.append(len(sequence))
    return lengths


def crop_fastq(source, destination, assigned, rng):
    with source.open() as src, destination.open("w") as out:
        for target in assigned:
            header = src.readline()
            sequence = src.readline().rstrip("\n")
            plus = src.readline()
            quality = src.readline().rstrip("\n")
            start = rng.randint(0, len(sequence) - target)
            end = start + target
            out.write(header.rstrip("\n") + f"|crop={start + 1}-{end}|length={target}\n")
            out.write(sequence[start:end] + "\n")
            out.write(plus)
            out.write(quality[start:end] + "\n")
        if src.readline():
            raise RuntimeError(f"Unexpected extra reads in {source}")


task = int(os.environ["SLURM_ARRAY_TASK_ID"])
if task < 0 or task >= len(GENOMES):
    raise RuntimeError("Run with --array=0-2")
name, alias_code = GENOMES[task]
rng = random.Random(271828 + task)
per_run = [N_READS // len(RUNS)] * len(RUNS)
for i in range(N_READS % len(RUNS)):
    per_run[i] += 1

targets = []
for run, count in zip(RUNS, per_run):
    observed = empirical_lengths(run, barcode_for_run(run, alias_code))
    targets.extend(rng.choices(observed, k=count))

source = READDIR / f"{name}.fastq"
OUTDIR.mkdir(parents=True, exist_ok=True)
link_dcs_lambda()
output = OUTDIR / f"{name}.fastq"
stamp = OUTDIR / f"{name}.DONE.stamp"
stats = OUTDIR / f"{name}.truncation.tsv"
if stamp.exists() and output.exists() and output.stat().st_size > 0:
    raise SystemExit(0)

source_lengths = fastq_lengths(source)
if len(source_lengths) != N_READS or len(targets) != N_READS:
    raise RuntimeError("Read-count mismatch")

source_order = sorted(range(N_READS), key=source_lengths.__getitem__)
targets.sort()
requested = list(targets)
adjusted = 0
assigned = [0] * N_READS
for rank, source_i in enumerate(source_order):
    target = targets[rank]
    if target > source_lengths[source_i]:
        target = source_lengths[source_i]
        adjusted += 1
    assigned[source_i] = target

job = os.environ.get("SLURM_JOB_ID", str(os.getpid()))
temporary = Path(f"{output}.tmp.{job}")
crop_fastq(source, temporary, assigned, rng)
temporary.replace(output)

with stats.open("w") as handle:
    handle.write(
        "genome\treads\tbatches\tadjusted_targets\t"
        "source_mean_bp\trequested_mean_bp\tfinal_mean_bp\t"
        "source_median_bp\trequested_median_bp\tfinal_median_bp\n"
    )
    handle.write(
        f"{name}\t{N_READS}\t{len(RUNS)}\t{adjusted}\t"
        f"{statistics.mean(source_lengths):.3f}\t"
        f"{statistics.mean(requested):.3f}\t"
        f"{statistics.mean(assigned):.3f}\t"
        f"{statistics.median(source_lengths):.3f}\t"
        f"{statistics.median(requested):.3f}\t"
        f"{statistics.median(assigned):.3f}\n"
    )

stamp.write_text(datetime.now().astimezone().isoformat() + "\n")
