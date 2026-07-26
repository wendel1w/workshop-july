output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint do API server do cluster EKS."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificado CA do cluster EKS (base64)."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Versao do Kubernetes do cluster EKS."
  value       = aws_eks_cluster.this.version
}

output "cluster_oidc_issuer_url" {
  description = "URL do OIDC issuer do cluster (usado para IRSA)."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "ID do Security Group do control plane."
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "ID do Security Group dos worker nodes."
  value       = aws_security_group.node.id
}

output "node_role_arn" {
  description = "ARN da IAM role dos worker nodes."
  value       = aws_iam_role.node.arn
}

output "cluster_role_arn" {
  description = "ARN da IAM role do cluster."
  value       = aws_iam_role.cluster.arn
}

output "ecr_backend_repository_url" {
  description = "URL do repositorio ECR do backend."
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "URL do repositorio ECR do frontend."
  value       = aws_ecr_repository.frontend.repository_url
}
