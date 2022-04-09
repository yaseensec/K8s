terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.1.0"
    }
  }
}

provider "aws" {
  profile = "darkrose"
  region  = "ap-south-1"
}

resource "aws_vpc" "dark-eks-vpc" {
  cidr_block           = var.vpc-cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "Dark-EKS"
    Project     = var.project
    Environment = terraform.workspace
    ManagedBy   = var.managedby
  }
}

resource "aws_cloudwatch_log_group" "flowlogs-loggroup" {
  name = "dark-eks-flowlogs"
}

resource "aws_iam_role" "flowlogs-role" {
  name = "dark-eks-flowlogs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "flowlogs-role-policy" {
  name = "cloudwatch-logs-rolepolicy"
  role = aws_iam_role.flowlogs-role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_flow_log" "dark-eks-flowlogs" {
  iam_role_arn    = aws_iam_role.flowlogs-role.arn
  log_destination = aws_cloudwatch_log_group.flowlogs-loggroup.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.dark-eks-vpc.id

  depends_on = [aws_vpc.dark-eks-vpc, aws_cloudwatch_log_group.flowlogs-loggroup, aws_iam_role.flowlogs-role, aws_iam_role_policy.flowlogs-role-policy]
}

resource "aws_subnet" "public-subnet" {
  for_each = var.public-subnet-nums

  vpc_id                  = aws_vpc.dark-eks-vpc.id
  cidr_block              = cidrsubnet(aws_vpc.dark-eks-vpc.cidr_block, 4, each.value)
  map_public_ip_on_launch = true
  availability_zone       = each.key

  tags = {
    Name        = "Public-Subnet-${each.key}-${terraform.workspace}"
    Project     = var.project
    Environment = terraform.workspace
    ManagedBy   = var.managedby
    Subnet      = "${each.key}-${each.value}"

    "kubernetes.io/cluster/dark-eks" = "owned"
    "kubernetes.io/role/elb"         = 1
  }

  depends_on = [aws_vpc.dark-eks-vpc]
}

resource "aws_subnet" "private-subnet" {
  for_each = var.private-subnet-nums

  vpc_id                  = aws_vpc.dark-eks-vpc.id
  cidr_block              = cidrsubnet(aws_vpc.dark-eks-vpc.cidr_block, 4, each.value)
  map_public_ip_on_launch = false
  availability_zone       = each.key

  tags = {
    Name        = "Private-Subnet-${each.key}-${terraform.workspace}"
    Project     = var.project
    Environment = terraform.workspace
    ManagedBy   = var.managedby
    Subnet      = "${each.key}-${each.value}"

    "kubernetes.io/cluster/dark-eks"  = "owned"
    "kubernetes.io/role/internal-elb" = 1
  }

  depends_on = [aws_vpc.dark-eks-vpc]
}

resource "aws_internet_gateway" "dark-eks-igw" {
  vpc_id = aws_vpc.dark-eks-vpc.id

  tags = {
    Name        = "Dark-EKS-IGW"
    Project     = var.project
    Environment = terraform.workspace
    ManagedBy   = var.managedby
  }

  depends_on = [aws_vpc.dark-eks-vpc]
}

# resource "aws_eip" "dark-nat-eip" {
#   vpc = true
#
#   tags = {
#     Name        = "Dark-EKS-EIP"
#     Project     = var.project
#     Environment = terraform.workspace
#     ManagedBy   = var.managedby
#   }
#
#   depends_on = [aws_internet_gateway.dark-eks-igw]
# }
#
# resource "aws_nat_gateway" "dark-eks-natgw" {
#   allocation_id = aws_eip.dark-nat-eip.id
#   subnet_id     = aws_subnet.public-subnet[element(keys(aws_subnet.public-subnet), 0)].id
#
#   tags = {
#     Name        = "Dark-EKS-NATGW"
#     Project     = var.project
#     Environment = terraform.workspace
#     ManagedBy   = var.managedby
#   }
#
#   depends_on = [aws_eip.dark-nat-eip, aws_subnet.public-subnet, aws_internet_gateway.dark-eks-igw]
# }

resource "aws_route_table" "dark-eks-publicrt" {
  vpc_id = aws_vpc.dark-eks-vpc.id

  tags = {
    Name        = "Dark-EKS-PublicRT"
    Project     = var.project
    Environment = terraform.workspace
    ManagedBy   = var.managedby
  }

  depends_on = [aws_internet_gateway.dark-eks-igw]
}

resource "aws_route_table" "dark-eks-privatert" {
  vpc_id = aws_vpc.dark-eks-vpc.id

  tags = {
    Name        = "Dark-EKS-PrivateRT"
    Project     = var.project
    Environment = terraform.workspace
    ManagedBy   = var.managedby
  }

#   depends_on = [aws_nat_gateway.dark-eks-natgw]
}

resource "aws_route" "dark-eks-publicroute" {
  route_table_id         = aws_route_table.dark-eks-publicrt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dark-eks-igw.id

  depends_on = [aws_internet_gateway.dark-eks-igw]
}

resource "aws_route" "dark-eks-privateroute" {
  route_table_id         = aws_route_table.dark-eks-privatert.id
  destination_cidr_block = "0.0.0.0/0"
  #nat_gateway_id         = aws_nat_gateway.dark-eks-natgw.id

  #depends_on = [aws_nat_gateway.dark-eks-natgw]
}

resource "aws_route_table_association" "dark-eks-publicrt-association" {
  for_each = aws_subnet.public-subnet

  route_table_id = aws_route_table.dark-eks-publicrt.id
  subnet_id      = aws_subnet.public-subnet[each.key].id

  depends_on = [aws_route_table.dark-eks-publicrt, aws_route.dark-eks-publicroute, aws_subnet.public-subnet]

}

resource "aws_route_table_association" "dark-eks-privatert-association" {
  for_each = aws_subnet.private-subnet

  route_table_id = aws_route_table.dark-eks-privatert.id
  subnet_id      = aws_subnet.private-subnet[each.key].id

  depends_on = [aws_route_table.dark-eks-privatert, aws_route.dark-eks-privateroute, aws_subnet.private-subnet]
}
