# EFS Setup
resource "aws_efs_file_system" "efs" {
  creation_token = "eks-efs"
  tags = {
    Name = "eks-efs"
  }
}
resource "aws_security_group" "efs_sg" {
  name   = "efs-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "efs-sg"
  }
}
resource "aws_efs_mount_target" "efs_mt" {
  count             = length(module.vpc.private_subnets)
  file_system_id    = aws_efs_file_system.efs.id
  subnet_id         = module.vpc.private_subnets[count.index]
  security_groups   = [aws_security_group.efs_sg.id]
}