locals {
  account_id = data.aws_caller_identity.current.account_id
  role_name  = "github-actions-ci-dvn-workshop"

  ecr_repository_arns = [
    for repo in var.ecr_repositories :
    "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${repo}"
  ]
}
