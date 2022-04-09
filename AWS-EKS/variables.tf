variable "vpc-cidr" {
  type    = string
  default = "192.168.0.0/20"
}

variable "project" {
  type        = string
  description = "Project Name"
}

variable "managedby" {
  type = string
}

variable "public-subnet-nums" {
  type        = map(number)
  description = "Map of AZ to a number so that value can be used as netnum for cidrsubnet function and Key can be used as AZ name-Public"
  default = {
    "ap-south-1a" = 1
    "ap-south-1b" = 2
  }
}

variable "private-subnet-nums" {
  type        = map(number)
  description = "Map of AZ to a number so that value can be used as netnum for cidrsubnet function and Key can be used as AZ name-Private"
  default = {
    "ap-south-1a" = 3
    "ap-south-1b" = 4
  }
}

