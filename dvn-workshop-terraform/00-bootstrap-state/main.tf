# Bucket S3 dedicado a armazenar o terraform.tfstate de todos os stacks do projeto.
# ADR-002: decisão original era bootstrap manual (Opção E); implementado como stack
# Terraform com state local (Opção F) por instrução do revisor humano em 2026-07-25.
# Este stack NUNCA deve usar backend remoto — seu state é local de propósito.

resource "aws_s3_bucket" "state" {
  bucket        = var.state_bucket.name
  force_destroy = var.state_bucket.force_destroy

  tags = {
    Name = var.state_bucket.name
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = var.state_bucket.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = var.state_bucket.block_public_access
  block_public_policy     = var.state_bucket.block_public_access
  ignore_public_acls      = var.state_bucket.block_public_access
  restrict_public_buckets = var.state_bucket.block_public_access
}

# Politica de bucket: exige TLS (aws:SecureTransport) e restringe acesso a esta conta.
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "state_bucket" {
  # Negar qualquer chamada que nao use HTTPS.
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Negar qualquer principal de fora desta conta AWS.
  statement {
    sid     = "DenyExternalAccounts"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json
}

# Lifecycle rule: expira versoes anteriores do state apos N dias, evitando acumulo
# indefinido de objetos historicos.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.state_bucket.noncurrent_version_expiration_days
    }
  }
}
