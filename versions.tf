terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    random = {
      source = "hashicorp/random"
    }
    template = {
      source = "hashicorp/template"
    }
  }

  required_version = ">= 0.13"
}
