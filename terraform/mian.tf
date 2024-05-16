terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
}

resource "aws_eks_cluster" "main" {
  name     = "ghost-eks-cluster"
  role_arn = aws_iam_role.eks_role[0].arn

  vpc_config {
    subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  }
}

data "aws_iam_role" "eks_role" {
  name = "eks_role"
}

resource "aws_iam_role" "eks_role" {
  count = length(data.aws_iam_role.eks_role.id) == 0? 1 : 0
  name = "eks_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy_attachment" {
  count     = length(data.aws_iam_role.eks_role.id) == 0? 1 : 0
  role       = aws_iam_role.eks_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_user" "new_user" {
  name = "GhostUser"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_access_key" "AccK" {
  user = aws_iam_user.new_user.name
}

output "secret_key" {
  value     = aws_iam_access_key.AccK.secret
  sensitive = true
}

output "access_key" {
  value = aws_iam_access_key.AccK.id
}

resource "aws_iam_user_policy" "iam" {
  name = "ListBuckets"
  user = aws_iam_user.new_user.name
  policy = <<EOF
{
  "Version": "2022-1-6",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "*"
    }
  ]
}
EOF
}
