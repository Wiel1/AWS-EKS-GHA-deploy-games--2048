# Bootcamp exercise

You are recruited as a DevOps engineer to join an application team delivering containerised application on the AWS EKS service. The company has never used EKS for application deployment but has employed a consultant organisation to build the EKS platform and this is being managed by a separate team, the Platfform team. Your new team will be the first team to deploy to the EKS cluster. Your organisation is also new to automated CICD
methods and have chosen GitHub Actions as their CICD tool and Terraform as their Infrastructure-as-code tool.

In order for the organisation's leadership and tech teams to gain confidence in the technology choices, they have decided to 
proceed in the following manner;

1) <b>Phase One</b>: Design and implement a simple Proof-of-Concept (POC) that showcases the features and capabilities of GitHub Actions as a CICD tool for deploying containerised applications to AWS EKS. Use an image from a public image registry such as the games-2048 image and deploy it and exposed it to the outside world.

2) <b>Phase Two</b>: Having gained some understanding from the POC, design and implement a CICD pipeline that will automate the deployment of the team's java application onto the AWS EKS cluster, across three environments (Dev, UAT and Prod). There are multiple teams using the EKS cluster. In keeping with the principle of separation of responsibility it is important that each team's resources are only available to members of the team.

3) <b>Phase three (Stretched Objective)</b>: The organisation is very quality and security conscious and would like these capabilities to be built into the delivery pipeline for testing and security scanning. Research what tools you could use and how you would integrate them into the pipeline.

