provider "aws" {
  region = "us-east-1"  # Change to your preferred region
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "ionginx_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ionginx-vpc"
  }
}

resource "aws_subnet" "public" {
  count = 3
  vpc_id = aws_vpc.ionginx_vpc.id
  cidr_block = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_subnet" "private" {
  count = 3
  vpc_id = aws_vpc.ionginx_vpc.id
  cidr_block = "10.0.${count.index + 3}.0/24"
  map_public_ip_on_launch = false
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ionginx_vpc.id
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public[0].id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.ionginx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count = 3
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.ionginx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private" {
  count = 3
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_launch_configuration" "nginx" {
  name = "nginx-lc"
  image_id = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  associate_public_ip_address = false

  user_data = <<-EOF
            #!/bin/bash
            apt-get update
            apt-get install -y nginx
            systemctl start nginx
            systemctl enable nginx
            EOF

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*"]
  }
}

resource "aws_autoscaling_group" "nginx" {
  desired_capacity     = 2
  max_size             = 4
  min_size             = 2
  vpc_zone_identifier  = aws_subnet.private.*.id
  launch_configuration = aws_launch_configuration.nginx.id

  tag {
    key                 = "Name"
    value               = "nginx"
    propagate_at_launch = true
  }
}

resource "aws_route53_zone" "main" {
  name = "example.com"  # Change to your domain
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www"
  type    = "A"
  ttl     = 300
  records = [aws_eip.nat.public_ip]
}
