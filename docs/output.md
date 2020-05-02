# nf-core/slamseq: Output

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/)
and processes data using the following steps:

1. Adapter trimming ([`Trim Galore!`](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/))
2. Conversion-aware mapping ([`Slamdunk`](http://t-neumann.github.io/slamdunk/))
3. Alignment filtering and multimapper recovery ([`Slamdunk`](http://t-neumann.github.io/slamdunk/))
4. SNP calling to filter T>C SNPs ([`Slamdunk`](http://t-neumann.github.io/slamdunk/))
5. Total and converted read quantification ([`Slamdunk`](http://t-neumann.github.io/slamdunk/))
6. Collapsing quantifications on gene level ([`Slamdunk`](http://t-neumann.github.io/slamdunk/))
7. Calculating QC stats ([`Slamdunk`](http://t-neumann.github.io/slamdunk/))
    1. Summary-statistics for nucleotide-conversions on a read level
    2. Summary-statistics for nucleotide-conversions on a gene level
    3. Summary-statistics for nucleotide-conversions along read positions
    4. Summary-statistics for nucleotide-conversions along gene positions
8. Summarising Slamdunk results ([`Slamdunk`](http://t-neumann.github.io/slamdunk/))
    1. Sequenced reads
    2. Mapped reads
    3. Retained reads
    4. Counted reads
9. Determine direct transcriptional targets ([`DESeq2`](https://doi.org/10.1186/s13059-014-0550-8))
10. Present QC for raw read, trimming, alignment, filtering and quantification ([`MultiQC`](http://multiqc.info/), [`R`](https://www.r-project.org/))

## TrimGalore

The nfcore/slamseq pipeline uses [TrimGalore](http://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) for removal of adapter contamination and trimming of low quality regions. TrimGalore uses [Cutadapt](https://github.com/marcelm/cutadapt) for adapter trimming and runs FastQC after it finishes.

MultiQC reports the percentage of bases removed by TrimGalore in the _General Statistics_ table, along with a line plot showing where reads were trimmed.

## Slamdunk

[Slamdunk](https://github.com/t-neumann/slamdunk) is a software to map and quantify nucleotide-conversion containing read sets with ultra-high sensitivity. The nfcore/slamseq pipeline uses Slamdunk for mapping SLAMseq datasets, calculating QC metrics and extracting both total and converted read counts for differential transcriptional output analysis.

**Output directory: `results/slamdunk`**

* `bam/*.{bam,bai}`
  * The aligned and filtered BAM and BAI files
* `vcf/*.vcf`
  * The called SNPs for filtering T>C SNPs from `slamdunk snp`
* `count/utrs/*tsv`
  * The total and converted read quantifications on a UTR level ([format details](https://t-neumann.github.io/slamdunk/docs.html#tcount-file-format)).
* `count/genes/*csv`
  * The total and converted read quantifications summarised per gene.

## DESeq2

[DESeq2](https://doi.org/10.1186/s13059-014-0550-8) is used to call differential transcriptional output between conditions to infer direct transcriptional targets. The nfcore/slamseq pipeline uses the total read counts to calculate the sizeFactors and then proceeds with the converted read counts for the remaining steps of the DESeq2 workflow.

**Output directory: `results/deseq2`**

* Directly in the output directory you will find one subfolder per `group`.

**Output directory: `results/deseq2/<group>`**

* `PCA.pdf`
  * A plain PCA plot for the samples in a given group (see [vignette](https://bioconductor.org/packages/release/bioc/vignettes/DESeq2/inst/doc/DESeq2.html))
* Again in each `group` folder you will find one subfolder for a given contrast of a `condition` vs the specified control condition

**Output directory: `results/deseq2/<group>/<condition>`**

* `DESeq2.txt`
  * A tab-delimited text file with the DESeq2 results containing the following columns:
    * `gene_name`: Name of the gene as in `--bed` file
    * `log2FC_deseq2`: The log2 fold-change of `condition` vs `control`
    *	`padj`: Adjusted p-value for a given gene
    *	`avg.RPM.ctrl`: Average RPM of the control samples for a given gene
* `MAPlot.pdf`
  * [MA-plot](https://en.wikipedia.org/wiki/MA_plot) of the average RPM in control samples vs log2 fold-changes coloring significant genes exceed the p-value threshold defined in `--pvalue`.

## MultiQC

[MultiQC](http://multiqc.info) is a visualisation tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in within the report data directory.

The pipeline has special steps which allow the software versions used to be reported in the MultiQC output for future traceability.

**Output directory: `results/multiqc`**

* `Project_multiqc_report.html`
  * MultiQC report - a standalone HTML file that can be viewed in your web browser
* `Project_multiqc_data/`
  * Directory containing parsed statistics from the different tools used in the pipeline

For more information about how to use MultiQC reports, see [http://multiqc.info](http://multiqc.info)
