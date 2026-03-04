# bcf-wdl

WDL workflows for running **patched** bcftools against VCFs streamed directly from GCS, without silent data corruption.

## The problem

htslib's libcurl backend has no retry logic for transient HTTP errors. When streaming a VCF from GCS and the connection blips, htslib silently returns a truncated read instead of propagating the error. Worse, bcftools' synced reader swallows I/O errors from htslib and exits 0, producing silently truncated output with no indication that anything went wrong.

## The patches

Two upstream PRs fix this:

| PR | What it fixes |
|----|---------------|
| [htslib#1987](https://github.com/samtools/htslib/pull/1987) | Adds retry/resilience logic to the libcurl HTTP backend so transient errors are retried instead of silently truncating |
| [bcftools#2503](https://github.com/samtools/bcftools/pull/2503) | Makes the synced reader propagate I/O errors so bcftools exits non-zero on read failures |

## Docker image

The Dockerfile at [`bcftools/docker/Dockerfile`](bcftools/docker/Dockerfile) builds htslib and bcftools 1.23 from source with both patches applied. The pre-built image is available at:

```
us-docker.pkg.dev/broad-dsde-methods/bcftools-patched/bcftools:1.23
```

## WDL workflows

Three template workflows are provided under [`bcftools/wdl/`](bcftools/wdl/):

| Workflow | Description |
|----------|-------------|
| [`bcftools_view.wdl`](bcftools/wdl/bcftools_view.wdl) | Filter/subset a VCF (uses `localization_optional: true` to stream from GCS) |
| [`bcftools_concat.wdl`](bcftools/wdl/bcftools_concat.wdl) | Concatenate VCF files |
| [`bcftools_merge.wdl`](bcftools/wdl/bcftools_merge.wdl) | Merge VCF files (supports gVCF mode) |

All three can serve as smoke tests to verify the patched image works correctly on a given platform.

## GCS token fifo pattern

htslib can authenticate to GCS via the `HTS_AUTH_LOCATION` environment variable, which points to a file containing an OAuth token. The WDLs use a named-pipe (fifo) trick to serve fresh tokens on every read without writing credentials to disk:

```bash
mkfifo /tmp/token_fifo
( while true; do
    curl -s -H "Metadata-Flavor: Google" \
      http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
      > /tmp/token_fifo
done ) &
export HTS_AUTH_LOCATION="/tmp/token_fifo"
```

A background loop continuously fetches a fresh GCE metadata token and writes it to the fifo. Each time htslib opens `HTS_AUTH_LOCATION`, it blocks until the next token is available, so credentials are always current and never touch the filesystem.

See [htslib#803 (comment)](https://github.com/samtools/htslib/issues/803#issuecomment-444514336) for the original discussion of this approach.
