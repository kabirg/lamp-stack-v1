#################################
########### PROVIDER ############
#################################
provider "aws" {
  region = "us-east-1"
}


#################################
########## VARIABLES ############
#################################
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# Subnet Calculator:
# http://www.davidc.net/sites/default/subnets/subnets.html
variable "public_subnets" {
  type = list(any)
  default = [
    {
      cidr     = "10.0.0.0/19",
      type     = "nat"
      location = "a"
    },
    {
      cidr     = "10.0.32.0/19",
      type     = "nat"
      location = "b"
    }
  ]

  validation {
    condition     = length(var.public_subnets) == 2
    error_message = "Number of private subnets must not exceed 2."
  }
}

variable "private_subnets" {
  type = list(any)
  default = [
    {
      cidr     = "10.0.64.0/18",
      type     = "web"
      location = "a"
    },
    {
      cidr     = "10.0.128.0/18",
      type     = "web"
      location = "b"
    },
    {
      cidr     = "10.0.192.0/19",
      type     = "db"
      location = "a"
    },
    {
      cidr     = "10.0.224.0/19",
      type     = "db"
      location = "b"
    }
  ]

  validation {
    condition     = length(var.private_subnets) == 4
    error_message = "Number of private subnets must not exceed 4."
  }
}

variable "resource_name_prefix" {
  default = "kabapp"
}

variable "ec2_keypair" {
  default = "kabirg"
}

# RHEL 7 AMI
variable "ami" {
  default = "ami-2051294a"
}


#################################
######## DATA RESOURCES #########
#################################
data "aws_region" "current" {}

data "aws_ami" "base_rhel_image" {
  owners      = ["309956199498"]
  most_recent = true
  filter {
    name   = "name"
    values = ["RHEL-7.5_HVM_GA-*"]
  }
}


#################################
########## RESOURCES ############
#################################
# ROUTE53
resource "aws_route53_zone" "primary" {
  name = "kabirg-sandbox.me"
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "kabirg-sandbox.me"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.kabirg-sandbox.me"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}


# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.resource_name_prefix}_vpc"
  }
}

# SUBNETS
# for_each only iterates through maps or sets of strings.
# So either the subnets variable has to be a map (intead of a list of maps),
# or we can use "for" to create a map (and set that equal to for_each). This hacks for_each to iterate through a list of maps.
resource "aws_subnet" "public_subnets" {
  vpc_id   = aws_vpc.main.id
  for_each = { for subnet in var.public_subnets : "${subnet.type}-${subnet.location}" => subnet }

  cidr_block              = each.value.cidr
  availability_zone       = "${data.aws_region.current.name}${each.value.location}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.resource_name_prefix}_${each.value.type}_az${each.value.location}_subnet"
  }
}

resource "aws_subnet" "private_subnets" {
  vpc_id   = aws_vpc.main.id
  for_each = { for subnet in var.private_subnets : "${subnet.type}-${subnet.location}" => subnet }

  cidr_block              = each.value.cidr
  availability_zone       = "${data.aws_region.current.name}${each.value.location}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.resource_name_prefix}_${each.value.type}_az${each.value.location}_subnet"
  }
}

# IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.resource_name_prefix}_igw"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  vpc      = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public_subnets)[0].id
  tags = {
    Name = "${var.resource_name_prefix}_nat"
  }
}

# SECURITY GROUPS
resource "aws_security_group" "nat_sg" {
  name   = "nat_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_name_prefix}_nag_sg"
  }
}

resource "aws_security_group" "alb_sg" {
  name   = "alb_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_name_prefix}_alb_sg"
  }
}

resource "aws_security_group" "web_sg" {
  name   = "web_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.nat_sg.id]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.nat_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ansible_sg.id]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_name_prefix}_web_sg"
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_name_prefix}_web_sg"
  }
}

resource "aws_security_group" "ansible_sg" {
  name   = "ansible_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_name_prefix}_ansible_sg"
  }
}

#ROUTE TABLE FOR PUBLIC SUBNET (need this for SSH access into public-subnet instances)
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.resource_name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public-rt-association" {
  count = length(var.public_subnets)
  subnet_id      = values(aws_subnet.public_subnets)[count.index].id
  route_table_id = aws_route_table.public-rt.id
}

# Needed for Internet Access (via NAT) for private instances
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.resource_name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private-rt-association" {
  count = length(var.private_subnets)
  subnet_id      = values(aws_subnet.private_subnets)[count.index].id
  route_table_id = aws_route_table.private-rt.id
}

# LOGGING BUCKET
resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.resource_name_prefix}-bucket"
  acl    = "private"

  tags = {
    Name = "${var.resource_name_prefix}_bucket"
  }
}

# SSL Certificiate Upload to IAM (can't use ACM since 4096-bit RSA Certs aren't supported w/ACM)
# Source: https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/ssl-server-cert.html#upload-cert
resource "aws_iam_server_certificate" "self_signed_cert" {
  name             = "${var.resource_name_prefix}-cert"
  certificate_body = file("cert/self-ca-cert.pem")
  private_key      = file("cert/key.pem")
}

# LOAD BALANCER, TARGET GRUOP & LISTENER
resource "aws_lb" "app_lb" {
  name               = "${var.resource_name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  tags = {
    Name = "${var.resource_name_prefix}_alb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "${var.resource_name_prefix}-alb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "front_end_http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_listener" "front_end_htps" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_iam_server_certificate.self_signed_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ASG & LAUNCH CONFIG
resource "aws_launch_configuration" "launch_config" {
  name            = "${var.resource_name_prefix}-launch_config"
  image_id        = data.aws_ami.base_rhel_image.id
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.web_sg.id]
  key_name        = var.ec2_keypair
}

resource "aws_autoscaling_group" "asg" {
  desired_capacity     = 2
  max_size             = 2
  min_size             = 1
  launch_configuration = aws_launch_configuration.launch_config.name
  vpc_zone_identifier = [values(aws_subnet.private_subnets)[2].id, values(aws_subnet.private_subnets)[3].id]
  tag {
    key                 = "Resource"
    value               = "ASG"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.asg.id
  alb_target_group_arn   = aws_lb_target_group.app_tg.arn
}

# ANSIBLE MANAGER
# Since Subnets were created with for-each, their output is a Map, which requires more work to parse (unlike Count which returns a list and is more intuitive)
# Use values() to get all the maps values (minus keys), pick the index of that resulint list that you want, and pick the attribute.
# Ref: https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
resource "aws_instance" "ansible_controller" {
  ami                         = var.ami
  instance_type               = "t2.micro"
  key_name                    = var.ec2_keypair
  subnet_id                   = values(aws_subnet.public_subnets)[0].id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]

  tags = {
    Name = "${var.resource_name_prefix}_ansible_controller"
    managed_by = "Terraform"
  }

  # To install Ansible, we need the EPEL (Extra Packages for Linux) software repo.
  # You can either do a wget xxx.rpm and rpm -i xxx.rpm to download/install the RPM package...or you can do a yum install.
  # Repo: https://fedoraproject.org/wiki/EPEL#Quickstart
  # https://www.shellhacks.com/epel-repo-centos-8-7-6-install/
  user_data = <<-EOF
              #!/bin/bash
              yum update -y &> /root/status.txt
              yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &>> /root/status.txt
              yum -y install ansible git &>> /root/status.txt
              git clone https://github.com/kabirg/lamp-stack-v1.git /home/ec2-user/lamp-stack-v1
              chown -R ec2-user /home/ec-2user/lamp-stack-v1
              chgrp -R ec2-user /home/ec-2user/lamp-stack-v1
              echo 'done' >> /root/status.txt
              EOF
}

# RDS MYSQL
# CLOUDFORMATION
