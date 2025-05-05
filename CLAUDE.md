# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Jacob Luszcz's personal website (jluszcz.com), a simple static HTML site hosted on AWS S3 with CloudFront CDN distribution. The site serves as a personal landing page with social media links and project references.

## Architecture

- **Frontend**: Single static HTML file (`index.html`) using Bootstrap 5 for styling and FontAwesome for icons
- **Infrastructure**: Terraform configuration (`jluszcz.tf`) defining AWS resources including:
  - S3 bucket for hosting
  - CloudFront distribution for CDN
  - Route 53 DNS management
  - ACM SSL certificate
  - IAM roles for GitHub Actions deployment
- **Deployment**: GitHub Actions workflow automatically uploads `index.html` to S3 on changes to main branch

## Development Commands

Since this is a static site, there are no build or test commands. Development involves:

1. **Local Development**: Open `index.html` directly in a browser for testing
2. **Infrastructure Changes**: Use Terraform commands:
   ```bash
   terraform plan
   terraform apply
   ```
3. **Deployment**: Changes to `index.html` automatically deploy via GitHub Actions when pushed to main branch

## Key Files

- `index.html`: The complete website - single HTML file with embedded CSS
- `jluszcz.tf`: Terraform configuration for AWS infrastructure
- `.github/workflows/workflow.yml`: GitHub Actions deployment pipeline
- `env-site`: Environment configuration file (likely for Terraform variables)

## Infrastructure Notes

The Terraform configuration creates a complete AWS hosting setup with:
- S3 bucket with website configuration
- CloudFront distribution with custom domain and SSL
- Route 53 hosted zone and DNS records
- GitHub OIDC integration for secure deployments
- BlueSky domain verification via DNS TXT record

The GitHub Actions workflow uses AWS IAM role assumption (no access keys) and only triggers on changes to `index.html` in the main branch.
