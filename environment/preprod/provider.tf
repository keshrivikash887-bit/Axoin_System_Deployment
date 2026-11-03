terraform {
   required_providers {
     azurerm = {
        source = "hashicorp/azurerm"
        version = "5.2.0"
     }
   }
   backend "azurerm" {
    resource_group_name = "kuldeep_rg"
    storage_account_name = "lalakastorage"
    container_name = "pappu"
    key = "kuldeep.tfstate"
   }
}

provider "azurerm" {
    features {}
}