module "ami" {
  source = "github.com/terraform-community-modules/tf_aws_ubuntu_ami"
  region = "${var.region}"
  distribution = "xenial"
  virttype = "hvm"
  storagetype = "ebs-ssd"
}


resource "aws_security_group" "deployer" {
  vpc_id = "${var.vpc_id}"
  name = "deployer"

  # Allow all outbound
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    terraform_module = "deployer"
  }
}

resource "aws_instance" "deployer" {
    ami = "${var.ami_id != "" ? var.ami_id : module.ami.ami_id}"

    instance_type = "${var.instance_type}"
    iam_instance_profile = "${var.iam_instance_profile_id}"

    subnet_id = "${var.subnet_id}"
    associate_public_ip_address = true
    source_dest_check = false

    availability_zone = "${var.availability_zone}"
    vpc_security_group_ids = ["${aws_security_group.deployer.id}"]
    key_name = "${var.key_name}"

    tags {
      ansible_managed = "yes",
      kubernetes_role = "deployer"
      terraform_module = "deployer"
      Name = "deployer"
    }
}



resource "aws_s3_bucket" "secrets" {
    bucket = "secrets-${var.cluster_name}"
    acl = "private"
}
