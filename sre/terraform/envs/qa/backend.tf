terraform {
  backend "s3" {
    key = "eks/qa/terraform.tfstate"
  }
}
