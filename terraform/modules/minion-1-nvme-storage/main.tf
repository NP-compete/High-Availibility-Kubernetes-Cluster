module "ami" {
  source = "github.com/terraform-community-modules/tf_aws_ubuntu_ami"
  region = "${var.region}"
  distribution = "xenial"
  virttype = "hvm"
  storagetype = "ebs-ssd"
}

resource "aws_instance" "worker" {
  count = "${var.servers}"
  ami = "${var.ami_id != "" ? var.ami_id : module.ami.ami_id}"
  iam_instance_profile = "${var.iam_instance_profile_id}"
  instance_type = "${var.instance_type}"
  subnet_id = "${element(var.subnet_ids, count.index)}"
  associate_public_ip_address = true # Instances have public, dynamic IP
  source_dest_check = false # TODO Required??
  availability_zone = "${element(var.azs, count.index)}"
  vpc_security_group_ids = ["${var.security_group_id}"]
  key_name = "${var.key_name}"

  tags {
    ansible_managed = "yes",
    kubernetes_role = "worker"
    terraform_module = "minion"
    Name = "kube-minion"
    minion_role = "${var.role}"
  }

  ephemeral_block_device {
      device_name = "/dev/sdf"#"/dev/nvme0n1"
      virtual_name = "ephemeral0"
  }
}
