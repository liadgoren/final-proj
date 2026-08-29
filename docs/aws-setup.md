# One-time AWS bootstrap for the CD pipeline

These steps only need to run once, by hand, before `.github/workflows/cd.yml`
can work. They intentionally are **not** run by Terraform/CI, because they
create the very state bucket/lock table and trust relationship the pipeline
then depends on (a classic chicken-and-egg problem for IaC).

## 1. Terraform remote state (S3 + DynamoDB)

```bash
aws s3api create-bucket --bucket <your-unique-tfstate-bucket> --region us-east-1
aws s3api put-bucket-versioning --bucket <your-unique-tfstate-bucket> \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket <your-unique-tfstate-bucket> \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket <your-unique-tfstate-bucket> \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws dynamodb create-table --table-name <your-tfstate-lock-table> \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Then set these as **repository variables** (Settings -> Secrets and variables ->
Actions -> Variables), which `cd.yml` reads directly:
- `TF_STATE_BUCKET` = `<your-unique-tfstate-bucket>`
- `TF_STATE_DYNAMODB_TABLE` = `<your-tfstate-lock-table>`

## 2. GitHub OIDC federation to AWS (no static AWS keys anywhere)

Create the OIDC identity provider once per AWS account:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Create the role GitHub Actions will assume, trusting only this repo's `main`
branch:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike": { "token.actions.githubusercontent.com:sub": "repo:<GH_ORG_OR_USER>/final-proj:ref:refs/heads/main" }
    }
  }]
}
```

Attach a permissions policy scoped to what the pipeline actually touches
(VPC/EC2/IAM-for-the-instance-profile/EIP/SSM/S3-state/DynamoDB-lock) --
start from `AmazonEC2FullAccess` + a scoped inline policy for
`iam:CreateRole`, `iam:PutRolePolicy`, `iam:PassRole`,
`iam:CreateInstanceProfile`, `ssm:SendCommand`, `ssm:GetCommandInvocation`,
`s3:GetObject`/`PutObject` on the state bucket, and `dynamodb:*Item` on the
lock table, then tighten further with least privilege once things work.

Set the resulting role ARN as repository variable `AWS_OIDC_ROLE_ARN`.

## 3. Docker Hub push credentials

Create a Docker Hub **access token** (not your account password) and set:
- `DOCKERHUB_USERNAME` (variable or secret)
- `DOCKERHUB_TOKEN` (secret)

## 4. GitHub Environment protection

Create a GitHub Environment named `production` (Settings -> Environments) and
add yourself as a **required reviewer**. Both the `terraform` and `deploy`
jobs in `cd.yml` target this environment, so every apply/deploy pauses for a
manual approval -- this is what closes the "Terraform auto-applied on every
push" issue from the Jenkins pipeline.
