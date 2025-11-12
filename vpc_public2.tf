# סבנט ציבורי שני ב־us-east-1b
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.4.0/24" # ודא שלא מתנגש עם אחרים
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.project}-public-2" }
}

# שיוך ל-Route Table הציבורית
resource "aws_route_table_association" "public2_assoc" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

