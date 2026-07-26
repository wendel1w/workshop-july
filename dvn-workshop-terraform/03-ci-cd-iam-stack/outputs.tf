output "oidc_provider_arn" {
  description = "ARN do OIDC Identity Provider para GitHub Actions."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_actions_role_arn" {
  description = "ARN da IAM Role que o GitHub Actions assume via OIDC. Use no workflow com role-to-assume."
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Nome da IAM Role do GitHub Actions."
  value       = aws_iam_role.github_actions.name
}
