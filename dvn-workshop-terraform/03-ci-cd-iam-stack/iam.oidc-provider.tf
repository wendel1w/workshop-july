# OIDC Identity Provider para GitHub Actions.
# Permite que workflows do GitHub assumam IAM Roles via federation,
# eliminando a necessidade de access keys estaticas.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprints oficiais do GitHub Actions OIDC.
  # O provider AWS >= 5.x gerencia automaticamente, mas listamos para
  # compatibilidade e reproducibilidade.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}
