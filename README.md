# Cloud Resume Challenge

This project is my implementation of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/).
You can find the production website at [https://patricknelsen.com](https://patricknelsen.com/). This
monorepo contains all of the frontend, backend, and infrastructure code related to the project.

## Frontend

The frontend is written using Next.js and [Nextra](https://nextra.site/), a framework to easily create
website from simple Markdown. In this, I have several pages, including an about page, my resume, and
some blog posts that are published through an RSS feed.

The about page also displays a hit counter. This makes a call to the backend API to update and read
the view count.

## Backend

The backend consists of some Go modules that are tested, packaged, and deployed to Lambda functions.
This code primarily makes CRUD operations on a DynamoDB table to update and read a view count statistic.

## Infrastructure

The infrastructure code is several Terraform modules that manage the entire
deployment of infrastructure. The frontend code is hosted as a static website
in an S3 bucket, and the backend code is deployed to Lambda functions
that are exposed behind an API Gateway API. These Lambda functions make
CRUD operations to a DynamoDB table. Route 53 is used to handle DNS to the
deployment, and CloudFront is used with ACM to provide HTTPS and also
cache and route to both the frontend and backend.

![Architecture Diagram](frontend/assets/architecture-diagram.png)

## CI/CD

The entire development process is automated through GitHub actions. The general development workflow follows this:

- On a pull request (PR), a new development environment is created with an
  environment name matching the pull request name, like `dev-10-update-readme`
- On every commit to the PR, the code is tested and build, and the development
  environment is updated with the new code
- When the PR is merged, the relevant development environment is destroyed,
  and the staging environment is updated with the new code
- When a new tag is cut, the production environment is updated with the new
  code.

Every step of this flow, the backend Go code is unit tested, both the frontend
JavaScript code and the backend Go code is built, and the infrastructure
Terraform code deploys it to the relevant environment.
