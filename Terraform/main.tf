
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.15.0" 
    }
  }

  required_version = ">= 1.3.0" 
}

provider "aws" {
  region = "us-east-1" 
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.18.1"

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
 
resource "aws_security_group" "example_sg" {
  name        = "example-ssh-sg"
  description = "Allow SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
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
    Name = "example-ssh-sg"
  }
}


module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.1.0"

  name = "example-instance"

  ami           = data.aws_ami.amazon_linux.id 
  instance_type = "t2.micro"
  key_name      = "keypaircicd" 

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


  
  subnet_id       = module.vpc.public_subnets[0] 
  vpc_security_group_ids = [aws_security_group.example_sg.id]
  

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