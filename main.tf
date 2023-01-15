provider "aws" {
  region = "us-east-1"
}
variable "environment" {
  description = "development environment"
}

variable "subnet_cidr_block" {
  description = "subnet cidr block"
  default = "10.0.10.0/24"
  type = string
}

variable "vpc_cidr_block" {
  description= "vpc cidr block"
}

resource "aws_vpc" "dev-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "development",
    vpc_end: "dev"
  }
}

resource "aws_subnet" "dev-subnet-1" {
  vpc_id = aws_vpc.dev-vpc.id
  //cidr_block="10.0.10.0/24"
  cidr_block=var.subnet_cidr_block
  availability_zone = "us-east-1a"
  tags = {
    Name: "subnet-1-dev"
  }
}

/*updating existing vpc or deployment
data "aws_vpc" "existing_vpc" {
  default = true
}

resource "aws_subnet" "dev-subnet-2" {
  vpc_id = data.aws_vpc.existing_vpc.id
  cidr_block="10.0.10.0/24"
  availability_zone = "us-east-1a"
}
*/ 