# Bootcamp exercise

You are recruited as a DevOps engineer to join an application team delivering containerised application on the AWS EKS service. The company has never used EKS for application deployment but has employed a consultant organisation to build the EKS platform and this is being managed by a separate team, the Platfform team. Your new team will be the first team to deploy to the EKS cluster. Your organisation is also new to automated CICD
methods and have chosen GitHub Actions as their CICD tool and Terraform as their Infrastructure-as-code tool.

In order for the organisation's leadership and tech teams to gain confidence in the technology choices, they have decided to 
proceed in the following manner;

1) <b>Phase One</b>: Design and implement a simple Proof-of-Concept (POC) that showcases the features and capabilities of GitHub Actions as a CICD tool for deploying containerised applications to AWS EKS. Use an image from a public image registry such as the games-2048 image and deploy it and exposed it to the outside world.

2) <b>Phase Two</b>: Having gained some understanding from the POC, design and implement a CICD pipeline that will automate the deployment of the team's java application onto the AWS EKS cluster, across three environments (Dev, UAT and Prod). There are multiple teams using the EKS cluster. In keeping with the principle of separation of responsibility it is important that each team's resources are only available to members of the team.

3) <b>Phase three (Stretched Objective)</b>: The organisation is very quality and security conscious and would like these capabilities to be built into the delivery pipeline for testing and security scanning. Research what tools you could use and how you would integrate them into the pipeline.


### Important 

* Have team consensus with the design
* Submit your design to the Chief Architect and argue and defend your approach. Proceed to implementation only after approval from the Chief Architect.


## Some points to consider

* What is a POC and why is it required?
* What do you understand by the expression <b> To seek common understanding</b> and how would you go about achieving this in the course of this bootcamp?
* As a member of the application team who is required to deploy onto the Platform EKS cluster, how would you go about building a relationship with the platform team?
* Come up with at least 5 questions you would want to ask the platform team in order to gather the information you need for your design
* Design the POC landscape
* Get consensus on the design
* Split the design into the various activities and estimate each task
* Allocate task to members of the team
* Document all your work
* Start the implementation and track your progress

### Teams 

# Application (Feature, Squad, scrum) Team A ():
* Esther  
* Sunny  
* Anis   
* Arsene  

# Application (Feature, Squad, Scrum) Team B ():
* Moules
* Madame
* Vitalis
* Derick
* Christiana

# Platform team:
* Victor
  
# Chief Architect
* Victor


### References

1) https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/deploy-a-sample-java-microservice-on-amazon-eks-and-expose-the-microservice-using-an-application-load-balancer.html

2) https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/automatically-build-and-deploy-a-java-application-to-amazon-eks-using-a-ci-cd-pipeline.html

3) https://github.com/marketplace/actions/contrast-security-eks-build-deploy

4) https://github.com/aws-samples/amazon-eks-example-for-stateful-java-service

5) https://octopus.com/blog/deploying-amazon-eks-github-actions

6) https://eggboy.medium.com/ci-cd-java-apps-securely-to-azure-kubernetes-service-with-github-action-part-1-16393af4d097

7) https://levelup.gitconnected.com/github-actions-to-build-your-java-scala-application-test-and-deploy-it-to-kubernetes-cluster-484779dfc200

  
