terraform {
  backend "s3" {
    key = "eks/staging/terraform.tfstate"
  }
}
