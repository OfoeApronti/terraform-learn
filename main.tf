provider "aws" {
  region="us-east-1"
}

variable "vpc_cidr_block" {}

variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {
  
}
variable "public_key_location" {
  
}
variable "private_key_location" {
  
}



resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "dev-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block=var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags={
    Name: "${var.env_prefix}-igw"
  }
}
/*
resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags={
    Name: "${var.env_prefix}-rtb"
  }
}

resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id=aws_subnet.dev-subnet-1.id
  route_table_id = aws_route_table.myapp-route-table.id
}
*/

//a default route table is created for the vpc. The subnet just created is associated with the default route table

resource "aws_default_route_table" "default-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags={
    Name: "${var.env_prefix}-default-rtb"
  }
}


resource "aws_security_group" "myapp-sg" {
  name="myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
  }
  //allows internet to port 8080 
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  //allows any traffic from the box to the internet
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags={
    Name: "${var.env_prefix}-sg"
  }
}



//using the default security group
/*
resource "aws_default_security_group" "default-sg" {
  vpc_id = aws_vpc.myapp-vpc.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
  }
  //allows internet to port 8080 
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  //allows any traffic from the box to the internet
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags={
    Name: "${var.env_prefix}-default-sg"
  }
}
*/

//to search for images 
//go to  https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#Images:
data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["amzn2*gp2"]

  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}

resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
  ami=data.aws_ami.latest-amazon-linux-image.id 
  instance_type = var.instance_type
  subnet_id = aws_subnet.dev-subnet-1.id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone = var.avail_zone
  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  # user_data = <<EOF
  #               #!/bin/bash
  #               sudo yum update -y && sudo yum install -y docker
  #               sudo systemctl start docker
  #               sudo usermod -aG docker ec2-user
  #               docker run -p 8080:80 nginx
  #             EOF

  user_data = file("entry-script.sh")

  #alternatively user provisioners(not recommended) to execute command on the remote server
  #to invoke command on a remote source after resource is created
  connection {
    type="ssh"
    host=self.public_ip
    user="ec2-user"
    private_key=file(var.private_key_location)
  }

  # file provisioner is used to copy file to remote server
  provisioner "file" {
    source ="entry-script.sh"
    destination = "/home/ec2-user/entry-script-on-ec2.sh"
  }
  provisioner "remote-exec" {
    script = file("entry-script-on-ec2.sh")
  }

  tags={
    Name: "${var.env_prefix}-dev-server"
  }
}