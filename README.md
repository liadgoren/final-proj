# final-proj — DevSecOps CI/CD pipeline for a Flask app on AWS

A small Flask app used as the vehicle for a full DevSecOps pipeline:
GitHub Actions (CI + CD), container hardening, Terraform-provisioned AWS
infrastructure, and a security gate at every stage from source to
production.

## Architecture

```
Push/PR ──► CI (GitHub Actions)
              lint ─ unit tests ─ SAST (bandit) ─ dependency audit (pip-audit)
              secret scan (gitleaks) ─ IaC scan (tfsec + checkov)
              docker build ─ image scan (trivy)

Push to main, after CI passes ──► CD (GitHub Actions)
              build ─ trivy scan ─ push (git-sha tag) ─ cosign sign ─ SBOM (syft)
                                  │
                                  ▼
              Terraform plan/apply (OIDC to AWS, no static keys,
              manual approval via GitHub Environment "production")
                                  │
                                  ▼
              Deploy to EC2 via AWS SSM (no SSH, no open port 22)
```

Infra: a VPC + public subnet + EC2 instance (Terraform, `Terraform/`),
reached only over HTTP (80) and AWS SSM Session Manager for
administration -- there is no SSH ingress at all.

An optional, separately-hardened Kubernetes `Deployment`/`Service`
(`appflask/k8s/`) is provided as an alternative deploy target; it is not
part of the AWS pipeline above.

## Security controls in this pipeline

| Stage | Tool | What it catches |
|---|---|---|
| Code | flake8 | style/correctness issues |
| Code | bandit | Python SAST (e.g. the reflected-XSS-shaped bugs) |
| Dependencies | pip-audit | known CVEs in pinned packages |
| Secrets | gitleaks | committed credentials/keys |
| IaC | tfsec, checkov | insecure Terraform (open ingress, missing encryption, etc.) |
| Image | trivy | OS/package CVEs in the built container, run *before* it is pushed |
| Supply chain | cosign | keyless signature on every pushed image digest |
| Supply chain | syft | CycloneDX SBOM published per release |
| Cloud auth | GitHub OIDC | no long-lived AWS access keys anywhere |
| Access | AWS SSM | no SSH keypair, no port 22 open to the internet |

See [docs/aws-setup.md](docs/aws-setup.md) for the one-time AWS setup
(OIDC role, Terraform state bucket, GitHub Environment approval) the CD
workflow depends on.

## Running locally

Requires Python 3.10+ (matches what CI and the Docker image use; the
pinned `click` version requires it).

```bash
cd appflask
pip install -r requirements.txt
python app.py            # dev server, http://localhost:5000/hello/<name>
python -m unittest discover -s . -p test_app.py -v
```

Or via Docker:

```bash
cd appflask
docker build -t appflask:local .
docker run -p 5000:5000 appflask:local
curl http://localhost:5000/hello/world
```

## Repository layout

- [appflask/](appflask/) — Flask app, tests, Dockerfile, optional k8s manifests
- [Terraform/](Terraform/) — AWS VPC/EC2/IAM for the app instance, S3 remote state
- [.github/workflows/](.github/workflows/) — CI and CD pipelines
- [docs/aws-setup.md](docs/aws-setup.md) — one-time AWS/GitHub bootstrap steps
