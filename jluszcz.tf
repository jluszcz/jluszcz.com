terraform {
  backend "s3" {}
}

# Sourced from environment variables named TF_VAR_${VAR_NAME}
variable "aws_acct_id" {}

variable "site_name" {
  type    = string
  default = "Jacob Luszcz"
}

variable "site_url" {
  type    = string
  default = "jluszcz.com"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "site" {
  bucket = var.site_url
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }
}

data "aws_iam_policy_document" "site" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

resource "aws_s3_object" "site" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
  etag         = filemd5("index.html")
}

resource "aws_acm_certificate" "cert" {
  provider                  = aws
  domain_name               = var.site_url
  subject_alternative_names = ["www.${var.site_url}"]
  validation_method         = "DNS"
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = aws_route53_zone.zone.id
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_cloudfront_origin_access_control" "site_distribution_oac" {
  name                              = var.site_name
  description                       = "OAC for ${var.site_url}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  origin {
    domain_name              = aws_s3_bucket.site.bucket_domain_name
    origin_id                = "site_bucket_origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.site_distribution_oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  default_root_object = "index.html"

  aliases = ["www.${var.site_url}", var.site_url]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "site_bucket_origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 3600
    default_ttl            = 86400
    max_ttl                = 604800
    compress               = true
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_route53_zone" "zone" {
  name    = var.site_url
  comment = "${var.site_name} Hosted Zone"
}

resource "aws_route53_record" "record" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = var.site_url
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "record_www" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "www.${var.site_url}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_iam_user" "github" {
  name = "github.${var.site_url}"
}

data "aws_iam_policy_document" "github" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.site.arn}/index.html"]
  }
}

resource "aws_iam_policy" "github" {
  name   = "${var.site_url}.github"
  policy = data.aws_iam_policy_document.github.json
}

resource "aws_iam_user_policy_attachment" "github" {
  user       = aws_iam_user.github.name
  policy_arn = aws_iam_policy.github.arn
}
