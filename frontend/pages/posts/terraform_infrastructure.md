---
title: Creating a Production-Ready Terraform Infrastructure
date: 2023/7/3
description: Terraform can be unruly.
tag: terraform
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
