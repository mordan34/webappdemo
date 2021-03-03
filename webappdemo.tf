terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.25"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  shared_credentials_file = "/home/mor/.aws/credentials"
  profile = "Mor"
}

# Create the new role
resource "aws_iam_role" "mgmt_role" {
  name = "mgmt_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

# Ceate a new policy and attach the definitions from mgmtpolic.json
resource "aws_iam_policy" "mgmt_policy" {
  name   = "mgmt_policy"
  description = "This is initial policy for the management client"
  policy = "${file("mgmtpolicy.json")}"
}

# Attaching our policy to the role
resource "aws_iam_policy_attachment" "attachement" {
  name       = "attachment"
  roles      = ["${aws_iam_role.mgmt_role.name}"]
  policy_arn = "${aws_iam_policy.mgmt_policy.arn}"
}

# Create instance profile
resource "aws_iam_instance_profile" "mgmt_profile" {
  name = "mgmt_profile"
  role = "${aws_iam_role.mgmt_role.name}"
}

# Using pre-created key-pair
resource "aws_key_pair" "terraform-keys" {
  key_name = "terraform-keys"
  public_key = "${file("${path.root}/terraform-keys.pub")}"
}

# Create Management ec2 client for k8s installation
resource "aws_instance" "mgmt" {
  ami           = "ami-02fe94dee086c0c37"
  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.mgmt_profile.name}"
  user_data = "${file("${path.root}/kopsinit.sh")}"
  key_name = "terraform-keys"

  tags = {
    Name = "CI-MGMT-Client"
  }
}