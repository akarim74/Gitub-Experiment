provider "aws" {
  region = "us-east-1"
  access_key = "AKIAXFTDN4XQ3KQMCVX5"
  secret_key = "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"
}
variable "subnet_prefix" {
  description = "cidr block for the subnet"
  #can also have the below:
  #default
  #type = Supports different types (String,Bool,any)
}


#Playing around - learning how to create subnets, VPCs, 
#Instances and other resources on AWS

/* resource "aws_instance" "my-first-server" {
  ami           = "ami-052efd3df9dad4825"
  instance_type = "t2.micro"

  tags = {
    Name = "HelloWorld"
  }


} */
/* 
# Create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.first-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "prod-subnet"
  }
}  

# Create a VPC 
resource "aws_vpc" "first-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }

} */

# Mini - project -> Creating a web server with custom VPC resources
# and deploying it in an EC2 instance and installing apache

 #Create custom VPC 
resource "aws_vpc" "project-vpc" {
  cidr_block = "10.0.0.0/16"

}
#Create a custom IGW 
resource "aws_internet_gateway" "project-igw" {
  vpc_id = aws_vpc.project-vpc.id
}
# Create Custom Route tables 
resource "aws_route_table" "project-route-table" {
  vpc_id = aws_vpc.project-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project-igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.project-igw.id
  }

  tags = {
    Name = "project-public-route"
  }
}
# Create Custom Subnets 
resource "aws_subnet" "project-subnet" {
  vpc_id     = aws_vpc.project-vpc.id
  cidr_block = var.subnet_prefix #"10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "project-subnet"
  }
}  
#Assign subnet to route table 
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.project-subnet.id
  route_table_id = aws_route_table.project-route-table.id
}
#Create a custom Security Group - allow port 22, 80, 443
resource "aws_security_group" "project-sg" {
  name        = "project-sg"
  description = "Allow Web Traffic inbound traffic"
  vpc_id      = aws_vpc.project-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  
  }
ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
#Create a network interface with an IP in the custom subnet 
resource "aws_network_interface" "project-ni" {
  subnet_id       = aws_subnet.project-subnet.id
  private_ips     = ["10.0.50.50"]
  security_groups = [aws_security_group.project-sg.id]

}
#Assign elastic IP to network interface 
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.project-ni.id
  associate_with_private_ip = "10.0.50.50"
  depends_on = [
    aws_internet_gateway.project-igw
  ]
}

output "public_ip_server" {
  value = aws_eip.one.public_ip
}

#Deploy web server and install apache 
resource "aws_instance" "Project_Instance" {
  ami           = "ami-052efd3df9dad4825"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.project-ni.id
  }

  tags = {
    Name = "First_TF_Apache_Web_Server"
  }

  user_data = <<-EOF
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF


} 

