/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "random_pet" "server" {}

locals {
  petname = random_pet.server.id
  admin_enabled_apis = [
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "containeranalysis.googleapis.com",
    "binaryauthorization.googleapis.com",
    "container.googleapis.com",
    "cloudkms.googleapis.com",
    "anthos.googleapis.com",
    "containerscanning.googleapis.com"
  ]

  attestors = [
    "quality",
    "build",
    "security"
  ]

  sa-permissions = [
    "roles/storage.admin",
    "roles/cloudkms.admin",
    "roles/binaryauthorization.attestorsViewer",
    "roles/cloudkms.signerVerifier",
    "roles/containeranalysis.occurrences.editor",
    "roles/containeranalysis.notes.occurrences.viewer",
    "roles/containeranalysis.notes.attacher",
    "roles/container.developer",
    "roles/secretmanager.secretAccessor"
  ]
}

data "google_container_engine_versions" "central1b" {
  location       = var.zone
  version_prefix = var.gke-version
}

module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = ">= 10.1.0"

  project_id = var.project

  # Don't disable the services
  disable_services_on_destroy = false
  disable_dependent_services  = false

  activate_apis = local.admin_enabled_apis
}

resource "google_service_account" "cicd-build-gsa" {
  project      = var.project
  account_id   = "cicd-builds"
  display_name = "CICD Pipeline builder Google Service Account (GSA)"
  description  = "GSA for CICD builds and GCR pushes"
}

resource "google_project_iam_member" "permissions" {
  for_each = toset(local.sa-permissions)
  project  = var.project
  role     = each.value
  member   = "serviceAccount:${google_service_account.cicd-build-gsa.email}"
}

resource "google_service_account_key" "cicd-build-gsa-key" {
  service_account_id = google_service_account.cicd-build-gsa.name
}

resource "google_secret_manager_secret" "cicd-build-gsa-key-secret" {
  provider = google-beta

  secret_id = "cicd-build-gsa-key"

  labels = {
    label = "gsa-service-key"
  }

  replication {
    automatic = true
  }

}

resource "google_secret_manager_secret_version" "cicd-build-gsa-key-secret-version" {
  provider = google-beta

  secret = google_secret_manager_secret.cicd-build-gsa-key-secret.id

  secret_data = google_service_account_key.cicd-build-gsa-key.private_key
}


resource "google_container_cluster" "development" {
  provider                    = google-beta
  name                        = "bin-auth-dev"
  location                    = var.zone
  enable_binary_authorization = true
  enable_shielded_nodes       = true
  node_version                = data.google_container_engine_versions.central1b.latest_node_version
  min_master_version          = data.google_container_engine_versions.central1b.latest_node_version
  initial_node_count          = 1
  resource_labels = {
    environment = "development"
  }

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    preemptible  = true
    machine_type = "n1-standard-4"

    metadata = {
      disable-legacy-endpoints = "true"
    }

  }

  timeouts {
    create = "30m"
    update = "40m"
  }
  depends_on = [module.project-services]
}

resource "google_container_cluster" "qa" {
  provider                    = google-beta
  name                        = "bin-auth-qa"
  location                    = var.zone
  enable_binary_authorization = true
  enable_shielded_nodes       = true
  node_version                = data.google_container_engine_versions.central1b.latest_node_version
  min_master_version          = data.google_container_engine_versions.central1b.latest_node_version
  initial_node_count          = 1
  resource_labels = {
    environment = "qa"
  }

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    preemptible  = true
    machine_type = "n1-standard-4"

    metadata = {
      disable-legacy-endpoints = "true"
    }

  }

  timeouts {
    create = "30m"
    update = "40m"
  }
  depends_on = [module.project-services]
}

resource "google_resource_manager_lien" "lien" {
  parent       = "projects/${data.google_project.project.number}"
  restrictions = ["resourcemanager.projects.delete"]
  origin       = "machine-readable-explanation"
  reason       = "This project utilizes a public-facing repository for Securing CICD"
}

data "google_project" "project" {
  project_id = var.project
}

resource "google_container_cluster" "production" {
  provider                    = google-beta
  name                        = "bin-auth-prod"
  location                    = var.zone
  enable_binary_authorization = true
  enable_shielded_nodes       = true
  node_version                = data.google_container_engine_versions.central1b.latest_node_version
  min_master_version          = data.google_container_engine_versions.central1b.latest_node_version
  initial_node_count          = 1
  resource_labels = {
    environment = "production"
  }

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    preemptible  = true
    machine_type = "n1-standard-4"

    metadata = {
      disable-legacy-endpoints = "true"
    }

  }

  timeouts {
    create = "30m"
    update = "40m"
  }
  depends_on = [module.project-services]
}
