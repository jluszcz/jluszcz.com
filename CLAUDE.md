# CLAUDE.md

Single-page personal site: one hand-written `index.html` and `jluszcz.tf` for all
the AWS infrastructure. There is no build system, no package.json, and no test
suite — the only automated checks are `pre-commit` (see
`.pre-commit-config.yaml`) and `terraform fmt`/`validate`.

See `README.md` for the infrastructure overview and deploy steps.

## The site is exactly one file

`s3:PutObject` in `jluszcz.tf` is scoped to `${bucket}/index.html`, so adding a
second file to the site — an image, a favicon, a manifest — requires widening
that policy and running `terraform apply` *before* the deploy will succeed.
Otherwise the upload fails with `AccessDenied`.

The same ordering applies to any new AWS API the workflow calls: apply first,
then merge.

Because the bucket blocks public access and is readable only through
CloudFront's OAC, a file `index.html` references but that was never uploaded
returns **403, not 404**. Don't read that as a permissions bug.

## The bucket must use SSE-S3

`sse_algorithm` is `AES256`, and changing it to `aws:kms` takes the whole site
down with `403 AccessDenied` (`server: AmazonS3`). CloudFront's OAC fetches the
origin as the `cloudfront.amazonaws.com` service principal, which needs
`kms:Decrypt` granted in the KMS *key policy*. With no `kms_master_key_id` S3
uses the AWS-managed `aws/s3` key, whose policy cannot be edited — so OAC can
never decrypt the object, no matter how correct the bucket policy looks.

A customer-managed key would work, but it also needs `kms:GenerateDataKey` and
`kms:Encrypt` added to the GitHub deploy role. The page is public by design, so
KMS buys no confidentiality here.

Changing this setting does **not** re-encrypt `index.html` — S3 default
encryption only applies to new objects. After the apply, re-upload the object
(pushing to `main` does it) or the old KMS-encrypted version keeps 403ing.

## Uploads must set `--content-type` explicitly

The minified HTML is written to `index.min`, which has no file extension, so the
AWS CLI infers no MIME type and defaults to `binary/octet-stream`. The page still
renders — browsers sniff it — which is why this was wrong in production for a
long time without anyone noticing, and why adding a `nosniff` header would have
broken the site. `.github/workflows/minify-and-upload-to-s3.yml` passes
`--content-type "text/html; charset=utf-8"`.

## Every deploy invalidates CloudFront

`default_ttl` is 24h and `min_ttl` is 1h, so without an invalidation a green
deploy still serves the old page for up to a day. The workflow creates the
invalidation and waits for it to complete, so a passing check means the change is
actually live. It reads the distribution ID from the
`CLOUDFRONT_DISTRIBUTION_ID` repository secret.
