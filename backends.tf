#connect to terraform cloud
terraform {
  cloud {
    organization = "favian-terraform-ansible"

    workspaces {
      name = "terraform-ansible"
    }
  }
}
