# =============================================================================
# S3 Bucket for UE5 Build Artifacts
# =============================================================================

resource "aws_s3_bucket" "builds" {
  bucket = "${var.s3_builds_bucket_name}-${random_string.suffix.result}"

  tags = {
    Name = "${local.name_prefix}-builds"
  }
}

# Enable versioning for build rollbacks
resource "aws_s3_bucket_versioning" "builds" {
  bucket = aws_s3_bucket.builds.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "builds" {
  bucket = aws_s3_bucket.builds.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "builds" {
  bucket = aws_s3_bucket.builds.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rules to manage old builds
resource "aws_s3_bucket_lifecycle_configuration" "builds" {
  bucket = aws_s3_bucket.builds.id

  rule {
    id     = "archive-old-builds"
    status = "Enabled"

    filter {}

    # Move builds older than 30 days to Infrequent Access
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move builds older than 90 days to Glacier
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete builds older than 365 days
    expiration {
      days = 365
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "cleanup-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
