#=======================random generator=========
resource "random_id" "instance_id" {
  byte_length = 2
  count       = var.main_instance_count #start count 
}

#=======================Key pair==================
resource "aws_key_pair" "my_auth" {
  key_name   = var.key_name              #mykey
  public_key = file(var.public_key_path) #mykey.pub
}
#=======================AMI======================
data "aws_ami" "server_ami" {
  most_recent = true
  owners      = ["099720109477"] #owner id of AMI in aws
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

#===============instance==========================
resource "aws_instance" "my_main_instance" {
  count                  = var.main_instance_count #local variable
  instance_type          = var.main_instance_type
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.my_auth.id
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  subnet_id              = aws_subnet.my_public_subnet[count.index].id
  # user_data              = templatefile("./main-userdata.tpl", { new_hostname = "my-main-instance-${random_id.instance_id[count.index].dec}" }) #boostraping grafana using script MAKE SURE TEMPLATE FILE IS NOT TYPO
  root_block_device {
    volume_size = var.main_vol_size
  }
  tags = {
    Name = "my-main-instance-${random_id.instance_id[count.index].dec}"
  }
  #provisioner using hypen (-) ont underscore (_)
  # add ip to aws_hosts

  provisioner "local-exec" {
    command = "printf '\n${self.public_ip}' >> aws_hosts && aws ec2 wait instance-status-ok --instance-ids ${self.id} --region us-west-1"
  }

  #remove public ip
  provisioner "local-exec" {
    when    = destroy
    command = "sed -i '/^[0-9]/d' aws_hosts"
    # regex means: anyline that start with number should be delete when destroy happen
  }

}
resource "null_resource" "grafana_install" {
  depends_on = [
    aws_instance.my_main_instance
  ]
  provisioner "local-exec" {
    command = "ansible-playbook -i aws_hosts --key-file /home/fvhg/.ssh/mykey playbooks/grafana.yml"
  }
}
output "grafana_access" {
  value = { for i in aws_instance.my_main_instance[*] : i.tags.Name => "${i.public_ip}:3000" }
}


