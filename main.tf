terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "server_port" {
  description = "value of port server will listen on"
  default     = "8080"
  type        = number
}

resource "aws_instance" "running_server" {
  ami                    = "ami-0ea18256de20ecdfc"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.server_security_group.id]
  user_data              = <<-EOF
              #!/bin/bash
              sudo apt install -y apache2
              sudo apt-get install ec2-instance-connect 
              yum install -y httpd
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  tags = {
    Name = "terraform-example"
  }
}

resource "aws_security_group" "server_security_group" {
  name        = "terraform-example"
  description = "Allow HTTP and SSH inbound traffic"
  ingress {
    description = "HTTP from VPC"
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


output "public_ip" {
  value = aws_instance.running_server.public_ip
  description = "value of public ip of the server"
}
