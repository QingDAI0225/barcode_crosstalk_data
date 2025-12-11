# barcode_crosstalk_data

Analysis code and protocols for the manuscript:

> Qing Dai, Claudia K. Gunsch, Joshua A. Granek, [*A simple library preparation modification significantly reduces barcode crosstalk in ONT multiplexed sequencing* (bioRxiv, 2025)](https://www.biorxiv.org/content/10.1101/2025.11.19.689316v2).

This repository collects the scripts used to generate the figures and tables in the paper, together with the wet-lab protocols for the post-ligation pooling (PLP) and related library-preparation variants.

---

## Repository structure

- `protocol/`  
  Wet-lab protocols used in the study, including post-ligation pooling (PLP) and related SQK-NBD114 high-yield workflows (e.g. PLP high-yield and PLP+SFB variants). These are the versions used to generate the data in the manuscript.

- `run_nanoplot_minimap2_samtools.sh`  
  Bash pipeline for Nanopore read QC and alignment, running on SLURM cluster. It typically:
  - runs **NanoPlot** on raw reads,
  - aligns reads to the reference genomes with **minimap2**,
  - computes alignment statistics with **samtools**,
  and writes the summary files consumed by the R Markdown notebooks.

- `samtools_result_analysis.Rmd`  
  R Markdown notebook that summarizes samtools statistics, including:
  - mapping rates and on-target fractions,
  - quantification of barcode crosstalk across protocols and input amounts,
  - protocol-level comparisons that appear as figures/tables in the paper.
 
- `minimap_megan_analysis.Rmd`  
  R Markdown notebook for downstream analyses based on minimap2/MEGAN outputs, including:
  - taxonomic profiling visualization of each barcoded sample,
  - generation of figures and tables used in the main text and supplement.

---

