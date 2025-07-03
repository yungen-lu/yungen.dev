---
title: Terraform short note
description: A short note for Google Developer Student Club meetings
date: 2023-02-26T00:00:00+08:00
lastmod: 2025-02-09T14:37:56+08:00
draft: false
category: "[[Posts]]"
tags:
  - posts
---

# Introduction

在使用雲端服務時我們通常會使用雲端平台提供 GUI 介面去設定並使用雲端服務，但這樣有個缺點就是使用 GUI 設定很難被紀錄、重現，假設今天我架設一台 VM 更動了 20 幾個設定 ，日後我想要再設定另一台一模一樣的 VM 就會很麻煩，又或著我使用多個不同的雲端服務建立一個環境我希望其他人也能建立一個跟我一樣的環境。這時候我們就可以使用 Terraform 這個工具來達到 [Infrastructure as Code](https://en.wikipedia.org/wiki/Infrastructure_as_Code)。我們可以使用 Code 來建置、更改並版本紀錄我們的 Infrastructure。

# HCL(Hashicorp Configuration Language)

Terraform 主要使用 HCL 來設定雲端服務，HCL 主要用來描述你想要設定的 [resource](https://developer.hashicorp.com/terraform/language/resources) ，例如以下

```json
resource "gpc_vpc" "main" {
  cidr_block = var.base_cidr_block
}

<BLOCK TYPE> "<BLOCK LABEL>" "<BLOCK LABEL>" {
  # Block body
  <IDENTIFIER> = <EXPRESSION> # Argument
}
```

如果你使用 vscode 可以用這個 [extension](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform)

# Install

請參考官方 [連結](https://developer.hashicorp.com/terraform/downloads)

# Authentication

在使用 terraform 存取 GCP 服務前需要取得認證，主要有兩種方法 1. gcloud Application Default Credentials 2. service account。如果你是在本機端使用自己的帳號話會推薦方法 1，如果是多人共用一組帳號或是要分享權限給其他人的話會推薦方法 2。

## gcloud Application Default Credentials

```bash
gcloud auth login
gcloud auth application-default login
```

## service account

1. 前往 [Service Accounts](https://console.cloud.google.com/apis/credentials/serviceaccountkey)
2. 選擇 project
3. 選擇 Create Service Account
4. 給予一個名字，並在 **“Grant this service account access to project”** Role 選項選擇 Project→Editor
5. 選擇剛剛建立的 service account
6. 選擇 “Keys” 並點選 “Create new key”
7. Key type 選擇 JSON

# Enable Compute Engine API

```bash
gcloud services enable compute.googleapis.com --project="<PROJECT_ID>"
```

# HCL

首先我們建立一個 `main.tf` 檔案

```bash
touch main.tf
```

接著在 `main.tf` 檔案中加入一個 terraform block，並設定 provider。terraform 這個 block 主要是設定一些 Global 的設定

```yaml
# main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}
```

provider 可以理解為 terraform 的 plugin。目前提供雲端服務的平台有那麼多種，terraform 不可能花費人力針對每個平台作開發，所以 terraform 採用 provider 的形式，讓雲端服務平台、或其他人可以自己開發 provider。這邊我們使用 "hashicorp/google" 官方的 gcp provider。

provider 的部分主要需要設定兩個參數，”project” 跟 “region”。這裡的 project 就填入你的 project-id region 就填入 “asia-east1”

```bash
provider "google" {
  project = "<PROJECT_ID>"
  region  = "asia-east1"
	zone = "asia-east1-a"
}
```

接著我們定義 resource block

```yaml
resource "google_compute_instance" "vm" { 
  machine_type = "n2-standard-4"
  name         = "gdsc_vm"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network = "default"
    access_config {
    }
  }
}
```

"hashicorp/google" 這個 provider 有提供不同種 resource 我們可以從 [這裡](https://registry.terraform.io/providers/hashicorp/google/latest/docs) 查詢每個 resource 的詳細設定

設定好之後我們輸入

```bash
terraform init
```

terraform 會幫我們準備好環境

接著輸入

```bash
terraform plan
```

以下是 terraform plan 的範例輸出

```bash
Terraform will perform the following actions:

  # google_compute_instance.vm will be created
  + resource "google_compute_instance" "vm" {
      + can_ip_forward       = false
      + cpu_platform         = (known after apply)
      + current_status       = (known after apply)
      + deletion_protection  = false
      + guest_accelerator    = (known after apply)
      + id                   = (known after apply)
      + instance_id          = (known after apply)
      + label_fingerprint    = (known after apply)
      + machine_type         = "n2-standard-4"
      + metadata_fingerprint = (known after apply)
      + min_cpu_platform     = (known after apply)
      + name                 = "gdsc_vm"
      + project              = (known after apply)
      + self_link            = (known after apply)
      + tags_fingerprint     = (known after apply)
      + zone                 = (known after apply)

      + boot_disk {
          + auto_delete                = true
          + device_name                = (known after apply)
          + disk_encryption_key_sha256 = (known after apply)
          + kms_key_self_link          = (known after apply)
          + mode                       = "READ_WRITE"
          + source                     = (known after apply)

          + initialize_params {
              + image  = "debian-cloud/debian-11"
              + labels = (known after apply)
              + size   = (known after apply)
              + type   = (known after apply)
            }
        }

      + confidential_instance_config {
          + enable_confidential_compute = (known after apply)
        }

      + network_interface {
          + ipv6_access_type   = (known after apply)
          + name               = (known after apply)
          + network            = "default"
          + network_ip         = (known after apply)
          + stack_type         = (known after apply)
          + subnetwork         = (known after apply)
          + subnetwork_project = (known after apply)

          + access_config {
              + nat_ip       = (known after apply)
              + network_tier = (known after apply)
            }
        }

      + reservation_affinity {
          + type = (known after apply)

          + specific_reservation {
              + key    = (known after apply)
              + values = (known after apply)
            }
        }

      + scheduling {
          + automatic_restart           = (known after apply)
          + instance_termination_action = (known after apply)
          + min_node_cpus               = (known after apply)
          + on_host_maintenance         = (known after apply)
          + preemptible                 = (known after apply)
          + provisioning_model          = (known after apply)

          + node_affinities {
              + key      = (known after apply)
              + operator = (known after apply)
              + values   = (known after apply)
            }
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

確認無誤後就可以輸入

```bash
terraform apply
```

terraform 就會幫我們建置 vm 了

# Variable

我們可以設定 variable 讓我們的 terraform code 更彈性，我們先建立一個檔案 `variables.tf`

```bash
variable "region" {
  default = "asia-east1"
}

variable "os_image" {
  default = "debian-cloud/debian-11"
}

variable "machine_type" {
  default = "e2-standard-2"
}
```

接著我們就可以將 `main.tf` 改成以下

```bash
resource "google_compute_instance" "vm" { 
  machine_type = var.machine_type
  name         = "gdsc_vm"
  boot_disk {
    initialize_params {
      image = var.os_image
    }
  }
  network_interface {
    network = "default"
    access_config {
    }
  }
}
```

如果我們要更改 default variable 的值的話我們可以透過新增一個 *.tfvars 檔案

```bash
# variables.tfvars
machine_type = "n2-standard-4"
```

# Output

[https://gdsc.community.dev/events/details/developer-student-clubs-national-cheng-kung-university-presents-gcp-meeting-226/](https://gdsc.community.dev/events/details/developer-student-clubs-national-cheng-kung-university-presents-gcp-meeting-226/)
