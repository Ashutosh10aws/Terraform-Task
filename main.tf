provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  region = "us-east-2"
  alias  = "Ohio"
}

data "aws_availability_zones" "virginia_zones" {}

data "aws_availability_zones" "ohio_zones" {
    provider  = aws.Ohio
}

data "aws_ami" "latest_amazon_linux_virginia" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_ami" "latest_amazon_linux_ohio" {
  provider  = aws.Ohio
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}



#-------------VPC and Internet Gateway------------------------------------------
resource "aws_vpc" "virginia_vpc" {
  cidr_block = var.vpc_cidr
  tags       = merge(var.tags, { Name = "${var.env}-vpc" })
}

resource "aws_vpc" "ohio_vpc" {
  provider  = aws.Ohio
  cidr_block = var.vpc_cidr
  tags       = merge(var.tags, { Name = "${var.env}-vpc" })
}


resource "aws_internet_gateway" "virginia_igw" {
  vpc_id = aws_vpc.virginia_vpc.id
  tags   = merge(var.tags, { Name = "${var.env}-igw" })
}

resource "aws_internet_gateway" "ohio_igw" {
  provider  = aws.Ohio
  vpc_id = aws_vpc.ohio_vpc.id
  tags   = merge(var.tags, { Name = "${var.env}-igw" })
}

#-------------Public Subnets and Routing----------------------------------------
resource "aws_subnet" "public_subnets_virginia" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.virginia_vpc.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = data.aws_availability_zones.virginia_zones.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.env}-public-${count.index + 1}" })
}

resource "aws_subnet" "public_subnets_ohio" {
  provider                = aws.Ohio
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.ohio_vpc.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = data.aws_availability_zones.ohio_zones.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.env}-public-${count.index + 1}" })
}


resource "aws_route_table" "public_subnets_virginia" {
  vpc_id = aws_vpc.virginia_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.virginia_igw.id
  }
  tags = merge(var.tags, { Name = "${var.env}-route-public-subnets" })
}

resource "aws_route_table" "public_subnets_ohio" {
  provider  = aws.Ohio
  vpc_id = aws_vpc.ohio_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ohio_igw.id
  }
  tags = merge(var.tags, { Name = "${var.env}-route-public-subnets" })
}

resource "aws_route_table_association" "public_routes_virginia" {
  count          = length(aws_subnet.public_subnets_virginia[*].id)
  route_table_id = aws_route_table.public_subnets_virginia.id
  subnet_id      = aws_subnet.public_subnets_virginia[count.index].id
}

resource "aws_route_table_association" "public_routes_ohio" {
  provider       = aws.Ohio
  count          = length(aws_subnet.public_subnets_ohio[*].id)
  route_table_id = aws_route_table.public_subnets_ohio.id
  subnet_id      = aws_subnet.public_subnets_ohio[count.index].id
}


#-------------EC2 Instance and Security Group----------------------------------------

resource "aws_instance" "web_server_virginia" {
  ami                    = data.aws_ami.latest_amazon_linux_virginia.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.webserver_virginia.id]
  subnet_id              = aws_subnet.public_subnets_virginia[0].id
  user_data              = <<EOF
#!/bin/bash
yum -y update
yum -y install httpd
myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

cat <<HTMLTEXT > /var/www/html/index.html
<h2>
${var.name} WebServer with IP: $myip <br>
Message:</h2> ${var.message}
HTMLTEXT

service httpd start
chkconfig httpd on
EOF
  tags = {
    Name  = "${var.name}-WebServer"
    Owner = "Ashutosh"
  }
}

resource "aws_instance" "web_server_ohio" {
  provider  = aws.Ohio
  ami                    = data.aws_ami.latest_amazon_linux_ohio.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.webserver_ohio.id]
  subnet_id              = aws_subnet.public_subnets_ohio[0].id
  user_data              = <<EOF
#!/bin/bash
yum -y update
yum -y install httpd
myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

cat <<HTMLTEXT > /var/www/html/index.html
<h2>
${var.name} WebServer with IP: $myip <br>
Message:</h2> ${var.message}
HTMLTEXT

service httpd start
chkconfig httpd on
EOF
  tags = {
    Name  = "${var.name}-WebServer"
    Owner = "Ashutosh"
  }
}

resource "aws_security_group" "webserver_virginia" {
  name_prefix = "${var.name} WebServer SG-"
  vpc_id = aws_vpc.virginia_vpc.id

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
    Name  = "${var.name}-web-server-sg"
    Owner = "Ashutosh"
  }
}

resource "aws_security_group" "webserver_ohio" {
  provider  = aws.Ohio
  name_prefix = "${var.name} WebServer SG-"
  vpc_id      = aws_vpc.ohio_vpc.id

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
    Name  = "${var.name}-web-server-sg"
    Owner = "Ashutosh"
  }
}

