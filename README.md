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
  - runs [NanoPlot](https://github.com/wdecoster/NanoPlot) [[1]](#ref-1) on raw reads,
  - aligns reads to the reference genomes with [Minimap2](https://github.com/lh3/minimap2) [[2]](#ref-2),
  - computes alignment statistics with [Samtools](https://github.com/samtools/samtools) [[3]](#ref-3),
  and writes the summary files consumed by the R Markdown notebooks.

- `samtools_result_analysis.Rmd`  
  R Markdown notebook that summarizes Samtools statistics, including:
  - mapping rates and on-target fractions,
  - quantification of barcode crosstalk across protocols and input amounts,
  - protocol-level comparisons that appear as figures/tables in the paper.
 
- `minimap_megan_analysis.Rmd`  
  R Markdown notebook for downstream analyses based on Minimap2-MEGAN outputs, including:
  - taxonomic profiling visualization of each barcoded sample,
  - generation of figures and tables used in the main text and supplement.


## Reference data

- Complexed community taxonomy profiling for Minimap2-MEGAN pipeline
  - Minimap2 indexed database are downloaded from NCBI nt database (ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nt.gz*)
  - MEGAN database are downloade from [MEGAN6 download website](https://software-ab.cs.uni-tuebingen.de/download/megan6/) (megan-nucl-Feb2022.db.zip).
  
- Customized Minimap2 mapping
  - The four defined ATCC genomes DNA sequences are downloaded from [ATCC official protal](https://github.com/ATCC-Bioinformatics/genome\_portal\_api) [[4]](#ref-4)
  - ONT DCS sequences are downloaded from [ONT official website](https://a.storyblok.com/f/196663/x/f69b1ef376/dcs\_reference.txt).
  - PhiX sequences are downloaded from [NCBI Reference Sequence NC_001422.1](https://www.ncbi.nlm.nih.gov/nuccore/9626372)

## Dependencies

- Basecalling and demultiplexing (Dorado pipeline)

- Complex community taxonomy profiling ([Minimap2-MEGAN pipeline](https://github.com/QingDAI0225/pacbio-metagenomics-tools))
  - A minor modified pipeline from [PacBio Minimap-MEGAN pipeline](https://github.com/lh3/minimap2) for parallel running on SLURM cluster. The step 6 outputs are used for total reads summary, and step 9 filtered mpa format outputs are used for relative abundance calculation and visualization.

  
## References
1. <a id="ref-1"></a> De Coster et al. NanoPack2: population-scale evaluation of long-read sequencing data. *Bioinformatics* **39**, DOI: 10.1093/bioinformatics/btad311 (2023)
2. <a id="ref-2"></a> Li, H. New strategies to improve minimap2 alignment accuracy. *Bioinformatics* **37**, 4572–4574, DOI: 10.1093/
bioinformatics/btab705 (2021).
3. Danecek, P. et al. Twelve years of SAMtools and BCFtools. *GigaScience* **10**, DOI: 10.1093/gigascience/giab008 (2021).
4. <a id="ref-4"></a> Nguyen, S. V. et al. The atcc genome portal: 3, 938 authenticated microbial reference genomes. *Microbiol. Resour. Announc.* **13**, DOI: 10.1128/mra.01045-23 (2024).
---

