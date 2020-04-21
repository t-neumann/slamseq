#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/slamseq
========================================================================================
 nf-core/slamseq Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/nf-core/slamseq
----------------------------------------------------------------------------------------
*/


def helpMessage() {
    log.info"""
    =======================================================
                                              ,--./,-.
              ___     __   __   __   ___     /,-._.--~\'
        |\\ | |__  __ /  ` /  \\ |__) |__         }  {
        | \\| |       \\__, \\__/ |  \\ |___     \\`-._,-`-,
                                              `._,._,\'

     nf-core/slamseq v${workflow.manifest.version}
    =======================================================

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/slamseq --reads '*_R{1,2}.fastq.gz' -profile standard,docker

    Mandatory arguments:
      --sampleList                  Text file containing the following unnamed columns:
                                    path to fastq, sample name, sample type, time point
                                    (see Slamdunk documentation for details)

      --genome                      Name of iGenomes reference
      -profile                      Configuration profile to use. Can use multiple (comma separated)
                                    Available: standard, conda, docker, singularity, awsbatch, test

    References                      If not specified in the configuration file or you wish to overwrite any of the references.
      --fasta                       Path to Fasta reference
      --bed                         Path to 3' UTR counting window reference
      --mapping                     Path to 3' UTR multimapper recovery reference

    Processing parameters
      --baseQuality                 Minimum base quality to filter reads
      --readLength                  Read length of processed reads

    Other options:
      --outdir                      The output directory where the results will be saved
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

    AWSBatch options:
      --awsqueue                    The AWSBatch JobQueue that needs to be set when running on AWSBatch
      --awsregion                   The AWS Region for your AWS Batch job to run on
    """.stripIndent()
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}

// Reference genome fasta
if (!params.fasta) {
	params.fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false
}
if ( params.fasta ){
    fasta = file(params.fasta)
    if( !fasta.exists() ) exit 1, "Fasta file not found: ${params.fasta}"
}

Channel
    .fromPath( fasta )
    .into { fastaMapChannel ;
            fastaSnpChannel ;
            fastaCountChannel ;
            fastaRatesChannel ;
            fastaUtrRatesChannel ;
            fastaReadPosChannel }

// Configurable reference genomes

if (!params.bed) {
	gtf = params.genome ? params.genomes[ params.genome ].gtf ?: false : false

  Channel
        .fromPath(gtf, checkIfExists: true)
        .ifEmpty { exit 1, "GTF annotation file not found: ${gtf}" }
        .set{ gtfChannel }

  process gtf2bed {
        tag "$gtf"

        input:
        file gtf from gtfChannel

        output:
        file "*.bed" into utrFilterChannel,
                          utrCountChannel,
                          utrratesChannel

        script:
        """
        gtf2bed.py $gtf | sort -k1,1 -k2,2n > ${gtf.baseName}.3utr.bed
        """
    }
} else {
  Channel
        .fromPath(params.bed, checkIfExists: true)
        .ifEmpty { exit 1, "BED 3' UTR annotation file not found: ${params.bed}" }
        .into { utrFilterChannel ; utrCountChannel ; utrratesChannel}
}

// Read length must be supplied
if ( !params.readLength ) exit 1, "Read length must be supplied."

// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}


if( workflow.profile == 'awsbatch') {
  // AWSBatch sanity checking
  if (!params.awsqueue || !params.awsregion) exit 1, "Specify correct --awsqueue and --awsregion parameters on AWSBatch!"
  if (!workflow.workDir.startsWith('s3') || !params.outdir.startsWith('s3')) exit 1, "Specify S3 URLs for workDir and outdir parameters on AWSBatch!"
  // Check workDir/outdir paths to be S3 buckets if running on AWSBatch
  // related: https://github.com/nextflow-io/nextflow/issues/813
  if (!workflow.workDir.startsWith('s3:') || !params.outdir.startsWith('s3:')) exit 1, "Workdir or Outdir not on S3 - specify S3 Buckets for each to run on AWSBatch!"
}

// Stage config files
ch_multiqc_config = Channel.fromPath(params.multiqc_config)
ch_output_docs = Channel.fromPath("$baseDir/docs/output.md")

Channel
   .fromPath( params.sampleList )
   .splitCsv( header: true, sep: '\t' )
   .map { row -> if (row.name == null || row.name == ''){ row.name = file(row.reads).simpleName}; row }
   .map { row -> if (row.type == null || row.type == ''){ row.type = "pulse"}; row }
   .map { row -> if (row.time == null || row.time == ''){ row.time = "0"}; row }
   .set { rawFiles }


// Header log info
log.info """=======================================================
                                          ,--./,-.
          ___     __   __   __   ___     /,-._.--~\'
    |\\ | |__  __ /  ` /  \\ |__) |__         }  {
    | \\| |       \\__, \\__/ |  \\ |___     \\`-._,-`-,
                                          `._,._,\'

nf-core/slamseq v${workflow.manifest.version}"
======================================================="""
def summary = [:]
summary['Pipeline Name']  = 'nf-core/slamseq'
summary['Pipeline Version'] = workflow.manifest.version
summary['Run Name']     = custom_runName ?: workflow.runName
summary['Fasta Ref']    = params.fasta
summary['Max Memory']   = params.max_memory
summary['Max CPUs']     = params.max_cpus
summary['Max Time']     = params.max_time
summary['Output dir']   = params.outdir
summary['Working dir']  = workflow.workDir
summary['Container Engine'] = workflow.containerEngine
if(workflow.containerEngine) summary['Container'] = workflow.container
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outdir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile
if(workflow.profile == 'awsbatch'){
   summary['AWS Region'] = params.awsregion
   summary['AWS Queue'] = params.awsqueue
}
if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="


def create_workflow_summary(summary) {
    def yaml_file = workDir.resolve('workflow_summary_mqc.yaml')
    yaml_file.text  = """
    id: 'nf-core-slamseq-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'nf-core/slamseq Workflow Summary'
    section_href: 'https://github.com/nf-core/slamseq'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
        </dl>
    """.stripIndent()

   return yaml_file
}


/*
 * Parse software version numbers
 */
process get_software_versions {

    output:
    file 'software_versions_mqc.yaml' into software_versions_yaml

    script:
    """
    echo $workflow.manifest.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    trim_galore --version > v_trimgalore.txt
    slamdunk --version > v_slamdunk.txt
    multiqc --version > v_multiqc.txt
    scrape_software_versions.py > software_versions_mqc.yaml
    """
}

/*
 * STEP 1 - TrimGalore!
 */
process trim {

     tag { parameters.name }

     input:
     val(parameters) from rawFiles

     output:
     set val(parameters), file("TrimGalore/${parameters.name}.fastq.gz") into trimmedFiles
     file ("TrimGalore/*.txt") into trimgaloreQC
     file ("TrimGalore/*.{zip,html}") into trimgaloreFastQC

     script:
     """
     mkdir -p TrimGalore
     trim_galore ${parameters.reads} --stringency 3 --fastqc --cores ${task.cpus} --output_dir TrimGalore
     mv TrimGalore/*.fq.gz TrimGalore/${parameters.name}.fastq.gz
     """
}

/*
 * STEP 2 - Map
 */
 process map {

     publishDir path: "${params.outdir}", mode: 'copy', overwrite: 'true'

     tag { parameters.name }

     input:
     set val(parameters), file(fastq) from trimmedFiles
     each file(fasta) from fastaMapChannel

     output:
     set val(parameters.name), file("map/*bam") into slamdunkMap

     script:
     """
     slamdunk map -r ${fasta} -o map \
        -5 12 -n 100 -t ${task.cpus} \
        --sampleName ${parameters.name} \
        --sampleType ${parameters.type} \
        --sampleTime ${parameters.time} --skip-sam \
        ${fastq}
     """
 }

 /*
  * STEP 3 - Filter
  */
  process filter {

      publishDir path: "${params.outdir}", mode: 'copy', overwrite: 'true'

      tag { name }

      input:
      set val(name), file(map) from slamdunkMap
      each file(bed) from utrFilterChannel

      output:
      set val(name), file("filter/*bam*") into slamdunkFilter,
                               slamdunkCount

      script:
      """
      slamdunk filter -o filter \
         -b ${bed} \
         -t ${task.cpus} \
         ${map}
      """
  }

/*
 * STEP 4 - Snp
 */
 process snp {

     publishDir path: "${params.outdir}", mode: 'copy', overwrite: 'true'

     tag { name }

     input:
     set val(name), file(filter) from slamdunkFilter
     each file(fasta) from fastaSnpChannel

     output:
     set val(name), file("snp/*vcf") into slamdunkSnp

     script:
     """
     slamdunk snp -o snp \
        -r ${fasta} \
        -f 0.2 \
        -t ${task.cpus} \
        ${filter[0]}
     """
 }

// Join by column 3 (reads)
 slamdunkCount
     .join(slamdunkSnp)
     .into{ slamdunkResultsChannel ;
            slamdunkForRatesChannel ;
            slamdunkForUtrRatesChannel ;
            slamdunkForTcPerReadPosChannel }

/*
* STEP 5 - Count
*/
process count {

    publishDir path: "${params.outdir}", mode: 'copy', overwrite: 'true'

    tag { name }

    input:
    set val(name), file(filter), file(snp) from slamdunkResultsChannel
    each file(bed) from utrCountChannel
    each file(fasta) from fastaCountChannel

    output:
    set val(name), file("count/*tsv") into slamdunkCountOut

    script:
    """
    slamdunk count -o count \
       -r ${fasta} \
       -s . \
       -b ${bed} \
       -l ${params.readLength} \
       -t ${task.cpus} \
       ${filter[0]}
    """
}

/*
* STEP 6 - Collapse
*/
process collapse {

    publishDir path: "${params.outdir}", mode: 'copy', overwrite: 'true'

    tag { name }

    input:
    set val(name), file(count) from slamdunkCountOut

    output:
    set val(name), file("collapse/*csv") into slamdunkCollapseOut

    script:
    """
    alleyoop collapse -o collapse \
       -t ${task.cpus} \
       ${count}
    """
}

/*
* STEP 7 - rates
*/
process rates {

    tag { name }

    input:
    set val(name), file(filter), file(snp) from slamdunkForRatesChannel
    each file(fasta) from fastaRatesChannel

    output:
    set val(name), file("rates/*csv") into alleyoopRatesOut

    script:
    """
    alleyoop rates -o rates \
       -r ${fasta} \
       -mq 27 \
       -t ${task.cpus} \
       ${filter[0]}
    """
}

/*
* STEP 8 - utrrates
*/
process utrrates {

    tag { name }

    input:
    set val(name), file(filter), file(snp) from slamdunkForUtrRatesChannel
    each file(fasta) from fastaUtrRatesChannel
    each file(bed) from utrratesChannel

    output:
    set val(name), file("utrrates/*csv") into alleyoopUtrRatesOut

    script:
    """
    alleyoop utrrates -o utrrates \
       -r ${fasta} \
       -mq 27 \
       -b ${bed} \
       -l ${params.readLength} \
       -t ${task.cpus} \
       ${filter[0]}
    """
}

/*
* STEP 9 - tcperreadpos
*/
process tcperreadpos {

    tag { name }

    input:
    set val(name), file(filter), file(snp) from slamdunkForTcPerReadPosChannel
    each file(fasta) from fastaReadPosChannel

    output:
    set val(name), file("tcperreadpos/*csv") into alleyoopTcPerReadPosOut

    script:
    """
    alleyoop tcperreadpos -o tcperreadpos \
       -r ${fasta} \
       -s . \
       -mq 27 \
       -l ${params.readLength} \
       -t ${task.cpus} \
       ${filter[0]}
    """
}

 /*
  * STEP 3 - Summary
  *
  process summary {

      publishDir path: "${params.outdir}/slamdunk", mode: 'copy', overwrite: 'true'

      input:
      file("filter/*") from slamdunkFilter.collect()
      file("count/*") from slamdunkCount.collect()

      output:
      file("summary*.txt") into summaryQC

      script:
      """
      #alleyoop summary -o summary.txt -t ./count ./filter/*bam
      alleyoop summary -o summary.txt ./filter/*bam
      """
  }

 slamdunkStats
     .flatten()
     .filter( ~/.*csv|.*summary.txt/ )
     .set { alleyoopQC }

/*
 * STEP 4 - MultiQC
 *
process multiqc {

    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    input:
    file multiqc_config from ch_multiqc_config

    file("alleyoop/*") from alleyoopQC.collect().ifEmpty([])
    file("summary*.txt") from summaryQC.collect().ifEmpty([])
    file ("TrimGalore/*") from trimgaloreQC.collect().ifEmpty([])
    file ("TrimGalore/*") from trimgaloreFastQC.collect().ifEmpty([])
    file ('software_versions/*') from software_versions_yaml
    file workflow_summary from create_workflow_summary(summary)

    output:
    file "*multiqc_report.html" into multiqc_report
    file "*_data"

    script:
    rtitle = custom_runName ? "--title \"$custom_runName\"" : ''
    rfilename = custom_runName ? "--filename " + custom_runName.replaceAll('\\W','_').replaceAll('_+','_') + "_multiqc_report" : ''

    """
    multiqc -m fastqc -m cutadapt -m slamdunk -f $rtitle $rfilename --config $multiqc_config .
    """
}
*/



/*
 * STEP 3 - Output Description HTML
 */
process output_documentation {
    publishDir "${params.outdir}/Documentation", mode: 'copy'

    input:
    file output_docs from ch_output_docs

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.r $output_docs results_description.html
    """
}



/*
 * Completion e-mail notification
 */
workflow.onComplete {

    // Set up the e-mail variables
    def subject = "[nf-core/slamseq] Successful: $workflow.runName"
    if(!workflow.success){
      subject = "[nf-core/slamseq] FAILED: $workflow.runName"
    }
    def email_fields = [:]
    email_fields['version'] = workflow.manifest.version
    email_fields['runName'] = custom_runName ?: workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if(workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if(workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if(workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
    email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$baseDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: params.email, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir" ]
    def sf = new File("$baseDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (params.email) {
        try {
          if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
          // Try to send HTML e-mail using sendmail
          [ 'sendmail', '-t' ].execute() << sendmail_html
          log.info "[nf-core/slamseq] Sent summary e-mail to $params.email (sendmail)"
        } catch (all) {
          // Catch failures and try with plaintext
          [ 'mail', '-s', subject, params.email ].execute() << email_txt
          log.info "[nf-core/slamseq] Sent summary e-mail to $params.email (mail)"
        }
    }

    // Write summary e-mail HTML to a file
    def output_d = new File( "${params.outdir}/Documentation/" )
    if( !output_d.exists() ) {
      output_d.mkdirs()
    }
    def output_hf = new File( output_d, "pipeline_report.html" )
    output_hf.withWriter { w -> w << email_html }
    def output_tf = new File( output_d, "pipeline_report.txt" )
    output_tf.withWriter { w -> w << email_txt }

    log.info "[nf-core/slamseq] Pipeline Complete"

}
