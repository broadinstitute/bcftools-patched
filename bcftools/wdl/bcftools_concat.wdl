version 1.0

task bcftools_concat_task {
  input {
    File input_vcf_list
    String output_name = "output.vcf.gz"
    Int? n_threads
    String total_memory = "16GB"
    Int disk_size_gb = 200
    String docker_image = "us-docker.pkg.dev/broad-dsde-methods/bcftools-patched/bcftools:1.23"
  }

  Boolean compressed = (basename(output_name) == basename(output_name, ".gz")) || (basename(output_name) == basename(output_name, ".bgz"))

  command {
    set -e
    
    # XXX: GCS assumptions
    # See https://github.com/samtools/htslib/issues/803#issuecomment-444514336
    mkfifo /tmp/token_fifo
    ( while true ; do curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token > /tmp/token_fifo ; done ) &
    export HTS_AUTH_LOCATION="/tmp/token_fifo"

    bcftools concat \
      -f ~{input_vcf_list} \
      ~{if select_first([n_threads, 0]) > 0 then "--threads ~{n_threads}" else ""} \
      ~{true="--write-index" false="" compressed} \
      -O ~{true="z" false="v" compressed} \
      -o ~{output_name}

    if [ -f "~{output_name}.csi" ]; then
        mv "~{output_name}.csi" "~{output_name}.tbi"
    fi
  }

  output {
    File output_vcf = output_name
    File? output_vcf_index = output_name + ".tbi"
  }

  runtime {
    memory: total_memory
    docker: docker_image
    cpu: 4
    disks: "local-disk ~{disk_size_gb} SSD"
  }
}

workflow bcftools_concat {
  input {
    File input_vcf_list
    String output_name = "output.vcf.gz"
    Int? n_threads
    String total_memory = "16GB"
    Int disk_size_gb = 200
    String docker_image = "us-docker.pkg.dev/broad-dsde-methods/bcftools-patched/bcftools:1.23"
  }

  call bcftools_concat_task {
    input:
      input_vcf_list = input_vcf_list,
      output_name = output_name,
      n_threads = n_threads,
      total_memory = total_memory,
      disk_size_gb = disk_size_gb,
      docker_image = docker_image
  }

  output {
    File output_vcf_file = bcftools_concat_task.output_vcf
    File? output_vcf_index_file = bcftools_concat_task.output_vcf_index
  }
}
