# Snippets



# simpleSharedVpcExample.tf
Creates a shared VPC host project for Google Cloud Platform (GCP) using Terraform. The host project is the project where the shared VPC network resides, and other projects, known as service projects, can connect to it. We'll set up the shared VPC network and a subnet within it.

Replace \<YOUR-HOST-PROJECT-ID\> and \<YOUR-REGION\> with your actual host project ID and region.

This Terraform script performs the following functions:

* Sets up the GCP provider with the host project ID and region.
* Enables the necessary APIs (Compute Engine and Service Networking) for    shared VPC functionality.
* Creates the shared VPC network with the specified name and disables automatic subnetwork creation.
* Creates a subnet within the shared VPC network with the specified IP CIDR range.
* Configures the host project to enable shared VPC functionality.
* Outputs the names of the created shared VPC network and subnet.

In this script, we've created a shared VPC network and a subnet within the host project. Now you can set up service projects to connect to this shared VPC network.





