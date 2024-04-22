
resource "aws_vpc" "terraformvpc" {
  cidr_block = "10.0.0.0/16"

}

resource "aws_subnet" "subone" {
  vpc_id                  = aws_vpc.terraformvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subtwo" {
  vpc_id                  = aws_vpc.terraformvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.terraformvpc.id

}

resource "aws_route_table" "myroute" {
  vpc_id = aws_vpc.terraformvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
}
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subone.id
  route_table_id = aws_route_table.myroute.id

}
resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subtwo.id
  route_table_id = aws_route_table.myroute.id

}
resource "aws_security_group" "allow_tls" {
  name   = "websec"
  vpc_id = aws_vpc.terraformvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

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

  tags = {
    name = "web-sec"
  }
}
resource "aws_s3_bucket" "example" {
  bucket = "vinayterraform2024project"
}

resource "aws_instance" "webserverone" {
  ami                    = "ami-080e1f13689e07408"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  subnet_id              = aws_subnet.subone.id
  user_data              = base64encode(file("userdataec1.sh"))

}
resource "aws_instance" "webservertwo" {
  ami                    = "ami-080e1f13689e07408"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  subnet_id              = aws_subnet.subtwo.id
  user_data              = base64encode(file("userdataec2.sh"))
}
#creating ALP
resource "aws_lb" "mylb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.allow_tls.id]
  subnets         = [aws_subnet.subone.id, aws_subnet.subtwo.id]

  tags = {
    Name = "web"
  }

}
resource "aws_lb_target_group" "tg" {
  name     = "0mytg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraformvpc.id

  health_check {
    path = "/"
    port = "traffic-port"

  }
}
resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.id
  target_id        = aws_instance.webserverone.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.id
  target_id        = aws_instance.webservertwo.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

