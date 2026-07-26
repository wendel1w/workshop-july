# OIDC Identity Provider para GitHub Actions.
# Permite que workflows do GitHub assumam IAM Roles via federation,
# eliminando a necessidade de access keys estaticas.

# Busca o thumbprint dinamicamente, evitando problemas com rotacao de certificado.
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = {
    Name = "github-actions-oidc"
  }
}
