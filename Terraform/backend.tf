# Remote state (S3 + DynamoDB lock) instead of local .tfstate on a CI
# runner: gives locking (no two applies stomp on each other), durability,
# and encryption at rest. Left as a partial configuration on purpose --
# fill in Terraform/backend.hcl (see backend.hcl.example) with your own
# bucket/table and run:
#   terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {}
}
