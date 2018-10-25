data "aws_caller_identity" "current" {}

provider "aws" { region = "${var.region}" }

resource "aws_key_pair" "kubernetes" {
  key_name = "tf-${var.cluster_name}"
  public_key = "${var.public_key}"
}

#### VPC ####
resource "aws_vpc" "kubernetes" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_peering_connection" "vpc_peering" {
    count="${length(var.existing_vpc_ids)}"

    peer_owner_id = "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id = "${element(var.existing_vpc_ids, count.index)}"
    vpc_id = "${aws_vpc.kubernetes.id}"
    auto_accept = true

    tags {
      Name = "VPC Peering between ${var.cluster_name} and existing VPC"
    }
}

resource "aws_subnet" "kubernetes" {
  count = "${length(var.availability_zones)}"
  vpc_id = "${aws_vpc.kubernetes.id}"
  cidr_block = "${cidrsubnet(aws_vpc.kubernetes.cidr_block, var.subnet_mask_bytes, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.kubernetes.id}"
}

resource "aws_route_table" "kubernetes" {
    vpc_id = "${aws_vpc.kubernetes.id}"
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.gw.id}"
    }

    lifecycle {
      ignore_changes = ["*"]
    }
}

resource "aws_route_table_association" "kubernetes" {
  count = "${length(var.availability_zones)}"
  subnet_id = "${element(aws_subnet.kubernetes.*.id, count.index)}"
  route_table_id = "${aws_route_table.kubernetes.id}"
}

module "etcd" {
    source = "./modules/etcd"

    vpc_id = "${aws_vpc.kubernetes.id}"
    key_name = "${aws_key_pair.kubernetes.key_name}"
    servers = "3"
    subnet_ids = ["${aws_subnet.kubernetes.*.id}"]
    azs = "${var.availability_zones}"
    security_group_id = "${aws_security_group.kubernetes.id}"
    cluster_name = "${var.cluster_name}"
    region = "${var.region}"
    instance_type = "${var.etcd_instance_type}"
    ami_id = "${var.etcd_ami_id}"
}

resource "aws_security_group" "kubernetes" {
  vpc_id = "${aws_vpc.kubernetes.id}"
  name = "kubernetes"

  # Allow all outbound
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all internal
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }

  # Allow all traffic from the API ELB
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_groups = ["${module.deployer.security_group}"]
  }

  # Allow all traffic from control host IP
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["${var.control_cidr}"]
  }
}

#######
# IAM
#######
resource "aws_iam_role" "kubernetes" {
  name = "tf-kubernetes-${var.cluster_name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Role policy
resource "aws_iam_role_policy" "kubernetes" {
  name = "tf-kubernetes-${var.cluster_name}"
  role = "${aws_iam_role.kubernetes.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action" : ["ec2:*"],
      "Effect": "Allow",
      "Resource": ["*"]
    },
    {
      "Action" : ["elasticloadbalancing:*"],
      "Effect": "Allow",
      "Resource": ["*"]
    },
    {
      "Action": "route53:*",
      "Effect": "Allow",
      "Resource": ["*"]
    },
    {
      "Action": "ecr:*",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "tf-secrets-${var.cluster_name}"
  role = "${aws_iam_role.kubernetes.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "arn:aws:s3:::*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${module.deployer.secrets_bucket}",
        "arn:aws:s3:::${module.deployer.secrets_bucket}/*"
      ]
    }
  ]
}
EOF
}

resource  "aws_iam_instance_profile" "kubernetes" {
 name = "tf-instance-profile-${var.cluster_name}"
 role = "${aws_iam_role.kubernetes.name}"
}

module "master" {
    source = "./modules/master"

    vpc_id = "${aws_vpc.kubernetes.id}"
    key_name = "${aws_key_pair.kubernetes.key_name}"
    servers = "3"
    subnet_ids = ["${aws_subnet.kubernetes.*.id}"]
    azs = "${var.availability_zones}"
    security_group_id = "${aws_security_group.kubernetes.id}"
    iam_instance_profile_id = "${aws_iam_instance_profile.kubernetes.id}"
    cluster_name = "${var.cluster_name}"
    region = "${var.region}"
    instance_type = "${var.master_instance_type}"
    ami_id = "${var.master_ami_id}"
}

module "deployer" {
    source = "./modules/deployer"

    vpc_id = "${aws_vpc.kubernetes.id}"
    key_name = "${aws_key_pair.kubernetes.key_name}"
    subnet_id = "${element(aws_subnet.kubernetes.*.id, 1)}"
    availability_zone = "${element(var.availability_zones, 1)}"
    iam_instance_profile_id = "${aws_iam_instance_profile.kubernetes.id}"
    control_cidr = "${var.control_cidr}"
    region = "${var.region}"
    cluster_name = "${var.cluster_name}"
    ami_id = "${var.deployer_ami_id}"
}

resource "aws_iam_user" "etcd_backuper" {
  count = "${var.etcd_backup_keys}"
  name = "etcd-backuper-${var.cluster_name}"
  path = "/system/"
}

resource "aws_iam_access_key" "etcd_backuper" {
  count   = "${var.etcd_backup_keys}"
  user    = "${element(aws_iam_user.etcd_backuper.*.name, count.index)}"
}

resource "aws_iam_policy_attachment" "etcd_admin" {
  count = "${var.etcd_backup_keys}"
  name = "tf-etcd-admin-${var.cluster_name}"
  users = ["${element(aws_iam_user.etcd_backuper.*.name, count.index)}"]
  policy_arn = "${aws_iam_policy.etcd_backup.arn}"
}

resource "aws_iam_policy" "etcd_backup" {
    name = "tf-etcd-bkp-${var.cluster_name}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "arn:aws:s3:::*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${module.etcd.backup_bucket}",
        "arn:aws:s3:::${module.etcd.backup_bucket}/*"
      ]
    }
  ]
}
EOF
}
