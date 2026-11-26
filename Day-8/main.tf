provider "aws" {
    region = "ap-southeast-2"
}

resource "aws_instance" "example" {
  ami                                  = "ami-09a2f74ce8538e414"
  associate_public_ip_address          = true
  availability_zone                    = "ap-southeast-2b"
  disable_api_stop                     = false
  disable_api_termination              = false
  ebs_optimized                        = true
  force_destroy                        = false
  get_password_data                    = false
  hibernation                          = false
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = "t3.micro"
  key_name                             = "Linux-key-pair"
  monitoring                           = false
  placement_partition_number           = 0
  private_ip                           = "172.31.37.6"
  region                               = "ap-southeast-2"
  secondary_private_ips                = []
  vpc_security_group_ids      = ["sg-042e64c96a5497e3f"]
  source_dest_check                    = true
  subnet_id                            = "subnet-0ed201bb391d80ce4"
  tags = {
    Name = "Linux-server"
  }
  tenancy                     = "default"
  user_data                   = null
  user_data_replace_on_change = null
  volume_tags                 = null
  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }
  cpu_options {
    core_count            = 1
    threads_per_core      = 2
  }
  credit_specification {
    cpu_credits = "unlimited"
  }
  enclave_options {
    enabled = false
  }
  maintenance_options {
    auto_recovery = "default"
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }
  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }
  root_block_device {
    delete_on_termination = true
    encrypted             = false
    iops                  = 3000
    tags                  = {}
    throughput            = 125
    volume_size           = 8
    volume_type           = "gp3"
  }
}
