provider "aws" {
  region = "us-east-1"
}

# 1️⃣ Generate SSH key pair (Terraform auto-generates this)
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 2️⃣ Upload public key to AWS as EC2 key pair
resource "aws_key_pair" "generated_key" {
  key_name   = "auto-key-${timestamp()}"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# 3️⃣ Security group to allow SSH
resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4️⃣ EC2 Instance with Docker installed via user_data
resource "aws_instance" "ubuntu_ec2" {
  ami                    = "ami-0fc5d935ebf8bc3bc"  # Ubuntu 22.04 in us-east-1
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y docker.io
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "UbuntuEC2WithDocker"
  }
}

# 5️⃣ Output private key so you can use it for SSH
output "private_key_pem" {
  value     = tls_private_key.ec2_key.private_key_pem
  sensitive = true
}

output "instance_ip" {
  value = aws_instance.ubuntu_ec2.public_ip
}
