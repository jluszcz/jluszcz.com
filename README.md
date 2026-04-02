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
- **IAM** — OIDC-based GitHub Actions role scoped to `s3:PutObject` on `index.html`

## Deployment

Pushing changes to `index.html` on `main` triggers the [Upload to S3](.github/workflows/upload-to-s3.yml) GitHub Actions workflow,
which assumes an IAM role via OIDC and syncs the file to the S3 bucket.
