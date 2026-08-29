terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.15"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.0"

  name                 = "example-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
  enable_nat_gateway   = false
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Environment = "example"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"]
}

# No inbound SSH (port 22) at all: instance access goes through AWS SSM
# Session Manager (see aws_iam_role.ssm below), which needs no open ports
# and gives full IAM + CloudTrail audit control over who connects.
resource "aws_security_group" "example_sg" {
  name        = "example-app-sg"
  description = "Allow inbound HTTP only; no SSH ingress (access via SSM)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example-app-sg"
  }
}

# IAM role + instance profile granting the EC2 instance SSM connectivity,
# so operators/CI can reach it via `aws ssm start-session` / `send-command`
# instead of SSH, without any long-lived keypair or open port 22.
resource "aws_iam_role" "ssm" {
  name = "example-instance-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "example-instance-ssm-profile"
  role = aws_iam_role.ssm.name
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.1.0"

  name = "example-instance"

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.example_sg.id]

  # Enforce IMDSv2 (session-token required) to close off the classic
  # SSRF-to-instance-credential-theft path that IMDSv1 allows.
  metadata_options = {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  root_block_device = [{
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }]

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    echo "Starting Docker installation"
    sudo yum update -y
    sudo amazon-linux-extras enable docker
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user
    echo "Docker installed successfully" > /home/ec2-user/docker_installed.txt
  EOF

  tags = {
    Name = "example-amazon-linux-instance"
  }
}

resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "MyElasticIP"
  }
}

resource "aws_eip_association" "eip_attach" {
  instance_id   = module.ec2_instance.id
  allocation_id = aws_eip.eip.id
}
