terraform {
  required_version = "~> 1.8.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.21"
    }
  }

  backend "s3" {
    bucket = "demo512"
    key    = "terraform/snapshot/state.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

provider "aws" {
  alias   = "aws_lab"
  region  = "us-east-2"
}

# Data source to get all EC2 instances in the specified region
data "aws_instances" "all_instances" {
  provider = aws.aws_lab
  filter {
      name   = "instance-state-name"
      values = ["running", "stopped"] # Include running and stopped instances
    }
}

# Iterate over each instance and get details about the instance
data "aws_instance" "target_instance" {
  for_each = toset(data.aws_instances.all_instances.ids)
  provider = aws.aws_lab

  instance_id = each.value
}

# Iterate over attached EBS volumes of all instances
resource "aws_ebs_snapshot" "attached_volume_snapshots" {
  provider = aws.aws_lab
  for_each = {
    for instance_id, instance_data in data.aws_instance.target_instance : instance_id => instance_data.ebs_block_device[*].volume_id
  }

  volume_id = each.value
  tags = {
    Name        = "Snapshot-${each.value}"
    CreatedBy   = "Terraform"
    Description = "Snapshot of volume ${each.value}"
  }
}

# Iterate over root volumes of all instances
resource "aws_ebs_snapshot" "root_volume_snapshots" {
  provider = aws.aws_lab
  for_each = {
    for instance_id, instance_data in data.aws_instance.target_instance : instance_id => instance_data.root_block_device[*].volume_id
  }

  volume_id = each.value
  tags = {
    Name        = "Snapshot-${each.value}"
    CreatedBy   = "Terraform"
    Description = "Snapshot of root volume ${each.value}"
  }
}

# Output all EC2 instance details for debugging
output "all_instance_details" {
  value = data.aws_instance.target_instance
}

# Output attached EBS volumes snapshots
output "attached_volumes_snapshots" {
  value = aws_ebs_snapshot.attached_volume_snapshots
}

# Output root volumes snapshots
output "root_volumes_snapshots" {
  value = aws_ebs_snapshot.root_volume_snapshots
}
