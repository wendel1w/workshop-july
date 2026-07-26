# Sem blocos ingress/egress: o default Security Group da VPC fica sem nenhuma regra
# (ADR-001 secao 6).
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-sg-default"
  }
}
