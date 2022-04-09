resource "aws_iam_role" "dark-eks-role" {
  name = "dark-eks-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "dark-eks-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.dark-eks-role.name
}

resource "aws_eks_cluster" "dark-eks" {
  name     = "dark-eks"
  role_arn = aws_iam_role.dark-eks-role.arn
  version = "1.21"

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access = true

    subnet_ids = [aws_subnet.public-subnet[element(keys(aws_subnet.public-subnet), 0)].id , aws_subnet.public-subnet[element(keys(aws_subnet.public-subnet), 1)].id , aws_subnet.private-subnet[element(keys(aws_subnet.private-subnet), 0)].id , aws_subnet.private-subnet[element(keys(aws_subnet.private-subnet), 1)].id]
  }

  depends_on = [aws_iam_role_policy_attachment.dark-eks-AmazonEKSClusterPolicy]
}

resource "aws_security_group" "dark-eks-sg" {
  name        = "dark-eks-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.dark-eks-vpc.id 

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    description = "Allow pods to communicate with the cluster API Server"
    security_groups   = [aws_security_group.eks-node-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "dark-eks-sg"
    Project     = var.project
    Environment = terraform.workspace
    ManagedBy   = var.managedby
  }
}
