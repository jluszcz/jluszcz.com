# [jluszcz.com](https://jluszcz.com)

[![Status Badge](https://github.com/jluszcz/jluszcz.com/actions/workflows/minify-and-upload-to-s3.yml/badge.svg)](https://github.com/jluszcz/jluszcz.com/actions/workflows/minify-and-upload-to-s3.yml)

Jacob Luszcz's personal website — a static HTML page with social media links.

## Overview

- `index.html` — single-page site built with Bootstrap 5 and Font Awesome icons
- `jluszcz.tf` — Terraform configuration for AWS infrastructure

## Infrastructure

Managed with Terraform (state stored in S3 at `jluszcz-tf-state`):

- **S3** — private bucket serving the static site
- **CloudFront** — CDN distribution with HTTPS redirect, HTTP/2+3, and OAC-based S3 access
- **ACM** — TLS certificate for `jluszcz.com` and `www.jluszcz.com`
- **Route 53** — hosted zone with A records for apex and `www`, plus a TXT record for Bluesky ATProto verification
- **IAM** — OIDC-based GitHub Actions role scoped to `s3:PutObject` on `index.html`, plus invalidating the site's CloudFront distribution

## Deployment

Pushing to `main` triggers the [Minify and Upload to S3](.github/workflows/minify-and-upload-to-s3.yml)
workflow, which assumes an IAM role via OIDC, minifies `index.html`, uploads it
to the bucket, and then invalidates the CloudFront distribution.

Two things the deploy depends on:

- **The upload sets `--content-type` explicitly.** The minified HTML is written
  to `index.min`, which has no extension for the CLI to infer a MIME type from,
  so without it the page is served as `binary/octet-stream` and only renders
  because browsers sniff it.
- **The `CLOUDFRONT_DISTRIBUTION_ID` repository secret** must be set, or the
  invalidation step fails. Cache TTLs run to 24h, so without the invalidation a
  successful deploy still serves the old page. Get the value from Terraform:

  ```sh
  gh secret set CLOUDFRONT_DISTRIBUTION_ID --body "$(terraform output -raw cloudfront_distribution_id)"
  ```

Terraform changes must be applied before merging a change that depends on them —
the deploy role's permissions come from `jluszcz.tf`, so a workflow that uploads
a new file or calls a new AWS API fails with `AccessDenied` until `terraform
apply` has run. Note that `s3:PutObject` is scoped to `index.html` alone, so
**adding any second file to the site requires a Terraform change first.**
