#================terraform aws initiate============== 
terraform{
    required_providers {
      aws ={
        source = "hashicorp/aws"
      }
    }
    
}
#=======================credentials initiate=========
provider "aws"{
    region = "us-west-1"
    shared_credentials_files = ["~/.aws/credentials"]
    profile = "tutorial"
}