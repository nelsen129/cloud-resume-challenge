---
title: Creating a Production-Ready Terraform Infrastructure
date: 2023/7/9
description:
  Terraform can make production-ready architecture much easier to implement.
  But it can be difficult to streamline the development process.
tag: terraform, devops
author: Patrick Nelsen
---

## The problem

Terraform is an incredible infrastructure-as-code (IaC) development tool which simplifies
the process of planning and deploying cloud infrastructure. It is incredibly powerful,
and it can manage everything from a simple S3 bucket to an entire organization's cloud
presence.

Terraform uses a state file to manage its created resources. When you run `terraform apply`,
Terraform checks the existing state file to see what it has already created so that it
only has to apply the changes. This also helps ensure that `terraform destroy` can properly
destroy all created resources and return the infrastructure to a blank slate.

This state file is incredible useful, and it's Terraform's greatest strength, but it can also
be a platform engineer's biggest headache. Here's some problems that can arise from this state
file:

- How do we manage multiple identical environments?
- How do we manage resources of different lifecycles, such as a long-lived database versus a
  short-lived Lambda function?
- What do we do if a state file gets corrupted, where resources exist that Terraform isn't
  aware of?
- How do we scale up our IaC so that multiple platform engineers can work concurrently?

## A naive solution

When you get to an infrastructure of a certain size, you are forced to start addressing some
of these problems. Here's a simple code layout that is pretty common among smaller projects,
and it is similar to what you can find at [https://www.terraform-best-practices.com](https://www.terraform-best-practices.com).

```
.
├── modules
│   └── network
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── prod
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── variables.tf
└── stage
    ├── main.tf
    ├── outputs.tf
    ├── terraform.tfvars
    └── variables.tf
```

In this structure, each environment has its own directory. This directory contains a `main.tf`,
which mostly simply contains references to the modules. It also contains `variables.tf` and
`outputs.tf` for inputs and outputs, and it contains `terraform.tfvars`, which is an environment
configuration file setting all of the various variables for that environment.

There's also a `modules/` directory, which contains several modules, such as `network`, `compute`,
`database`, etc. Each of these modules has a `main.tf`, which is a more complex Terraform file
containing all of the various resources that must be created for that module, as well as the
usual `variables.tf` and `outputs.tf`.

This structure works well for a basic workflow, but it can be limiting for any project of a
reasonable scale. Each new environment requires a new environment folder, and any new module
requires changes to every environment's `main.tf` file. This results in a lot of code duplication,
and it's nearly impossible to create ephemeral development/test environments.

Furthermore, this instrinsically links the lifecycle of an entire environment. Long-lived network
and database code gets deployed alongside short-lived compute code. Because of how Terraform
handles state, this means that the only way to issue an infrastructure update is to update the
entire environment, and so only one developer can meaningfully work on the development environment
at a time. Most importantly, if one part of the state file is corrupted, this may require Terraform
state surgery across all resources. If a bad deployment leaves the compute resources in a bad state,
this may also affect network resources, which can lead to unstable deployments and a general bad
time for anyone responsible for Terraform

## A scalable solution

These scalability issues have led to me creating this solution that can work for a wide array of
projects, workflows, and companies:

```
.
├── components
│   └── network
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── environments
│   ├── prod.tfvars
│   └── stage.tfvars
└── modules
    └── vpc
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

In this, we split what was previously only modules into two types of Terraform projects: modules
and components. A component represents a project-specific, broadly-scoped set of resources that
share the same lifecycle. Some examples of components are network, compute, database, etc. A
module represents a generic, narrowly scoped set of resources that accomplish a specific task.
Some examples of modules might be vpc, ec2_bastion_host, s3_bucket_with_sns_topic, etc. Ideally,
modules should be general enough that they could be split off into their own repository for
organization-wide usage.

The previous environments directories are now simple environment variable files. This allows
incredibly flexible environment definition and creation without having to copy chunks of code
between multiple environnments.

In the backend, each combination of environment and component has its own state file. These
state files might be named something like `<environment>-<component>/terraform.tfstate`.
The life cycles of every component is isolated, allowing for isolated changes and deployments.

This structure requires more work in the CI/CD pipeline to configure. The CI/CD pipeline needs
to deploy each component in order to the correct environment. Once this is set up, it can be
incredibly easy to add more components.

It also requires some extra configuration to manually initialize and deploy Terraform infrastructure.
For a development environment, the developer will have to modify both their `init` and `apply`
commands. This is an example for a `dev` environment deploying to a `compute` component:

```
terraform init -backend-config="key=dev-compute/terraform.tfvars
terraform apply -var-file="../../environments/dev.tfvars"
```

Finally, it also requires some planning to pass required data between two components. For
example, an EC2-based compute component might require VPC and subnet IDs from the network
component. Depending on your organization, you may already have a way to store and use secrets,
such as Hashicorp Vault, and that would be an excellent way to communicate this data. For
this project, I've chosen to use AWS SSM Parameter Store. This is a hierarchical parameter
store that can handle simple parameters and also secrets. What I've done is store relevant
parameters, such as VPC ID, in an SSM parameter named like
`/cloud-resume-challenge/dev/network/vpc-id`. Downstream components can use these parameters
for their configuration. These parameters will automatically update on subsequent runs,
creating easy and automatic updates across components.

## Conclusion

Creating a scalable infrastructure deployment can be difficult for any architecture, but
having a good plan can make it significantly easier to deploy updates to many environments.
Different solutions may work better for different organizations, but this structure has
proven incredibly useful in my experience.

While it may take some extra effort to set up and configure this structure, its benefits
greatly outweigh its weaknesses. This creates a repeatably deployable infrastructure that
can work for more complex architectures.
