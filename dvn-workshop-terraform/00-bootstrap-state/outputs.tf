output "state_bucket_name" {
  description = "Nome do bucket S3 de state, usado como valor do argumento 'bucket' nos blocos backend dos demais stacks."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN do bucket S3 de state."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_region" {
  description = "Regiao do bucket S3 de state."
  value       = aws_s3_bucket.state.region
}
