locals {
  terragrunt_project = "myproject"
  tags = {
    Project   = "${local.terragrunt_project}"
    ManagedBy = "Terraform"
    CreatedBy = "Saurav"
  }
}