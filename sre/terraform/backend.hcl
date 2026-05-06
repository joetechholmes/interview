# Shared S3 backend config — passed to every env via:
#   terraform init -backend-config=../../backend.hcl
#
# Set up the bucket once:
#   aws s3api create-bucket --bucket <name> --region us-east-1
#   aws s3api put-bucket-versioning --bucket <name> \
#       --versioning-configuration Status=Enabled
#
# Optional state locking (recommended for team use):
#   aws dynamodb create-table --table-name terraform-locks \
#       --attribute-definitions AttributeName=LockID,AttributeType=S \
#       --key-schema AttributeName=LockID,KeyType=HASH \
#       --billing-mode PAY_PER_REQUEST

bucket         = "interview-backend-terraform-state"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "interview-backend-terraform-locks"
