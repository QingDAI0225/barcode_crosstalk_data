# NanoSim mapping simulation

This workflow tests whether simulated R10/Dorado sequencing errors cause reads from four defined genomes to map to the wrong genome in a combined reference.

## Inputs

- Combined reference FASTA with sequence names beginning with `DCS_Lambda`, `ATCC_23114`, `ATCC_8482`, or `ATCC_6940`.
- NanoSim 3.2.3 human HG002 Kit 14/Dorado model prefix (`MODEL_PREFIX`).
- Default-setting Dorado summaries under `DORADO_RESULTS_ROOT` for observed read lengths.
- Sample sheets in `../sample_sheet/`.

The scripts use Apptainer images for NanoSim 3.2.3, Dorado, and Samtools 1.22.1. Paths and images can be overridden with environment variables defined near the top of each script.

## Workflow

Set `ROOT` to the work directory containing `barcode_crosstalk_data/`, `data/`, and `models/`, then run from this directory.

```bash
sbatch --array=0-3 01-simulate_reads.sh
```

This generates 200,000 reads per genome. The three bacterial genomes use the pretrained model's default length and error distributions. DCS lambda uses the observed 3.0--3.587 kb amplicon range and the same error model. Only aligned NanoSim reads are retained. Read names contain the source genome and NanoSim source-coordinate information.

```bash
sbatch --array=0-2 01b-truncate_reads.py
```

This creates the observed-length dataset for the three bacterial genomes. Each batch contributes equally to 200,000 target lengths per genome. Target lengths are sampled with replacement from reads assigned to the corresponding sample-sheet barcode. Sequence and quality strings are cropped at the same random interval. DCS lambda is reused without additional truncation.

Map either length dataset to the combined reference:

```bash
sbatch --array=0-3 02-dorado_mapping.sh default_length
sbatch --array=0-3 02-dorado_mapping.sh empirical_length
```

Summarize primary alignments:

```bash
sbatch 03-summarize_mapping.sh default_length
sbatch 03-summarize_mapping.sh empirical_length
```

The summary step writes long and wide confusion tables plus correct, misassigned, and unmapped counts. Secondary and supplementary alignments are excluded.

Outputs are written under `ROOT/data/nanosim_mapping/`; each mapping and summary directory is suffixed with `default` or `empirical_length`.
