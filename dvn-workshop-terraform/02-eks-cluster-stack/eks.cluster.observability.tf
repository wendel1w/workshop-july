# CloudWatch Log Group para os logs do EKS Control Plane.
# Criado antes do cluster para controlar a politica de retencao.
# O EKS cria automaticamente o log group se nao existir, mas sem controle de retencao.

resource "aws_cloudwatch_log_group" "cluster" {
  name              = local.log_group_name
  retention_in_days = var.cluster.log_retention_in_days

  tags = {
    Name = local.log_group_name
  }
}
