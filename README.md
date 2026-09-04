[![DOI](https://zenodo.org/badge/1110180378.svg)](https://doi.org/10.5281/zenodo.17981223)

# barcode_crosstalk_data

Analysis code and protocols for:

> Qing Dai, Claudia K. Gunsch, Joshua A. Granek, [*Identification, quantification, and elimination of barcode crosstalk in multiplexed Oxford Nanopore sequencing*](https://doi.org/10.1101/2025.11.19.689316).

## Analysis notebooks

- `dorado_misassignment_analysis.Rmd`: barcode assignment, mapping, performance, and quality-score analyses using the default Dorado barcode setting.
- `dorado_misassignment_analysis_both_end.Rmd`: the same analyses with `--barcode-both-ends`.
- `dorado_read_length_distribution.Rmd`: read-length distributions for the six default-setting runs.

The notebooks read the six sample sheets from `sample_sheet/`. Set `DORADO_RESULTS_ROOT` to a directory with this layout:

```text
<DORADO_RESULTS_ROOT>/<batch>/either_end/merged_bam/sequencing_summary_merged.txt
<DORADO_RESULTS_ROOT>/<batch>/both_ends/merged_bam/sequencing_summary_merged.txt
```

Required R packages are `data.table`, `ggplot2`, `knitr`, `rmarkdown`, and `ragg`.

Render from the repository root after setting `DORADO_RESULTS_ROOT`:

```bash
Rscript -e 'rmarkdown::render("dorado_misassignment_analysis.Rmd")'
Rscript -e 'rmarkdown::render("dorado_misassignment_analysis_both_end.Rmd")'
Rscript -e 'rmarkdown::render("dorado_read_length_distribution.Rmd")'
```

Tabular and figure outputs are written to `dorado_species_qc_out/` and `dorado_read_length_out/`.

## Mapping simulation

`nanosim_mapping/` contains the NanoSim read simulation, observed-length truncation, Dorado mapping, and mapping-confusion summaries. See `nanosim_mapping/README.md` for inputs and commands.

## Other files

- `protocol/`: wet-lab protocols used in the study.
- `run_nanoplot_minimap2_samtools.sh`: NanoPlot, Minimap2, and Samtools workflow.
- `minimap_megan_analysis.Rmd`: Minimap2-MEGAN taxonomic profiling analysis.

The Dorado basecalling and demultiplexing workflow is available from [dorado_basecalling_with_qscore](https://github.com/QingDAI0225/dorado_basecalling_with_qscore) and [Zenodo](https://doi.org/10.5281/zenodo.18942955).
