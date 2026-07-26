data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = "dvn-wendel-tfstate-us-east-1"
    key    = "01-networking-stack/terraform.tfstate"
    region = "us-east-1"
  }
}
