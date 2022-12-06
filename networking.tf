#======================AZ==================
locals {
  azs = data.aws_availability_zones.available.names
}
data "aws_availability_zones" "available" {}
#=============random-id-for-tags=============
### random must be initiated fir every tags in the resouces and not clashes each other
resource "random_id" "random" {
  byte_length = 2
}
#============VPC==================
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "my_vpc-${random_id.random.dec}"
  }

  lifecycle {
    #just like its name, before the folowing reosuceces dsisapereed it will created new one first
    #tips for avoid havoc or confglict as the old ones pair to the new ones
    create_before_destroy = true
  }
}
#=============IGW=================
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my_igw-${random_id.random.dec}"
  }
}

#=============route table===========
#to connect to the internet gateway
resource "aws_route_table" "my_public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-public-rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.my_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

resource "aws_default_route_table" "my_private_rt" {
  default_route_table_id = aws_vpc.my_vpc.default_route_table_id
  tags = {
    Name = "my_private_rt"
  }

}

#=============CIDR public Subnets===============
resource "aws_subnet" "my_public_subnet" {
  count                   = length(local.azs) # because vpc have two value of subnets
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = local.azs[count.index]

  tags = {
    Name = "my-public-subnet-${count.index + 1}"
  }
}
#=============Privat Subnets =================
resource "aws_subnet" "my_private_cidrs" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, length(local.azs) + count.index)
  map_public_ip_on_launch = false
  availability_zone       = local.azs[count.index]
  tags = {
    Name = "my-private-cidr-${count.index + 1}"
  }
}

#private subnet will be associated with default route

#===================rt assoc===================

resource "aws_route_table_association" "my_public_associate" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.my_public_subnet[count.index].id
  route_table_id = aws_route_table.my_public_rt.id
}


#=================SecurityGroups==============
###accesing resources

resource "aws_security_group" "my_sg" {
  name        = "public_sg"
  description = "SG for public"
  vpc_id      = aws_vpc.my_vpc.id
}

resource "aws_security_group_rule" "ingress_all" {
  ## able to access everyhing within the sg [inbound]
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1" #access to all protocol
  cidr_blocks       = [var.access_ip]
  security_group_id = aws_security_group.my_sg.id
}

resource "aws_security_group_rule" "egress_all" {
  #commuincate outside [ooutbound]
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.my_sg.id

}
