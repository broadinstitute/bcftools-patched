version 1.0

task bcftools_view_task {
  input {
    File input_vcf
    File? input_vcf_index
    String output_name = "output.vcf"
    Boolean exclude_uncalled = false
    Boolean force_samples = false
    String? exclude
    String? include
    Int? n_threads
    Array[String] samples = []
    String total_memory = "16GB"
    String docker_image = "us-docker.pkg.dev/broad-dsde-methods/bcftools-patched/bcftools:1.23"
  }

  Boolean compressed = (basename(output_name) != basename(output_name, ".gz")) || (basename(output_name) != basename(output_name, ".bgz"))

  command {
    set -e
    
    # XXX: GCS assumptions
    # See https://github.com/samtools/htslib/issues/803#issuecomment-444514336
    mkfifo /tmp/token_fifo
    ( while true ; do curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token > /tmp/token_fifo ; done ) &
    export HTS_AUTH_LOCATION="/tmp/token_fifo"

    mkdir -p "$(dirname ~{output_name})"
    bcftools view \
    ~{"--exclude " + exclude} \
    ~{"--include " + include} \
    ~{true="--exclude-uncalled" false="" exclude_uncalled} \
    ~{true="--force-samples" false="" force_samples} \
    ~{if length(samples) > 0 then "-s" else ""} ~{sep="," samples} \
    ~{if select_first([n_threads, 0]) > 0 then "--threads ~{n_threads}" else ""} \
    -o ~{output_name} \
    -O ~{true="z" false="v" compressed} \
    ~{input_vcf}

    ~{if compressed then 'bcftools index --tbi ~{output_name}' else ''}
  }

  output {
    File output_vcf = output_name
    File? output_vcf_index = output_name + ".tbi"
  }

  parameter_meta {
    input_vcf: {
      description: "Input VCF File",
      localization_optional: true
    }
  }

  runtime {
    memory: total_memory
    docker: docker_image
    cpu: 4
    disks: "local-disk 200 SSD"
  }
}

workflow bcftools_view {
  input {
    File input_vcf
    File? input_vcf_index
    String output_name = "output.vcf"
    Boolean exclude_uncalled = false
    Boolean force_samples = false
    String? exclude
    String? include
    Int? n_threads
    Array[String] samples = []
    String total_memory = "16GB"
    String docker_image = "us-docker.pkg.dev/broad-dsde-methods/bcftools-patched/bcftools:1.23"
  }

  call bcftools_view_task {
    input:
      input_vcf = input_vcf,
      input_vcf_index = input_vcf_index,
      output_name = output_name,
      exclude_uncalled = exclude_uncalled,
      force_samples = force_samples,
      exclude = exclude,
      include = include,
      n_threads = n_threads,
      samples = samples,
      total_memory = total_memory,
      docker_image = docker_image
  }

  output {
    File output_vcf_file = bcftools_view_task.output_vcf
    File? output_vcf_index_file = bcftools_view_task.output_vcf_index
  }
}

