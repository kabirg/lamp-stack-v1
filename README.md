# Deploy Containerized Flask App to AWS (Using NGINX & Gunicorn)

Step-by-step instructions on setting up a Gitlab Environment and Pipeline.

Clone this repo and go through the directories as listed below in order, to complete this walkthrough....


## 1 - Provision Infrastructure With Terraform
The terraform template in this directory will deploy:
  - A VPC and a set of public/private subnets
  - An Internet-facing Application Load Balancer and Auto-Scaling group behind it. The ASG will provision our servers that will host the NGINX webserver, Gunicorn appserver, and the Flask applicaiton itself.
  - Upload an self-signed SSL cert to IAM to HTTPS termination at the ALB (user must create the cert, instructions provided...)
  - 1 EC2 instance to serve as the Ansible Controller.
  - Route53 Hosted Zone and A-records to add a domain on the ALB (user must update their registrar with the AWS-provided nameservers, instructions provided...)

See the design folder for a visual of what will be deployed....

    > Pre-Requisites:
    > An EC2 key pair (since it can't be created programmatically) for both EC2 instances.
    > A self-signed SSL certificate & private key.
    > A purchased domain.

**Steps:**
  - Create an EC2 keypair
  - Create a self-signed certificate, store the certificate and key in the terraform/cert/ directory named as "self-ca-cert.pem" and "key.pem", respectively.
  - Run ***aws-configure*** to ensure your CLI can log into your AWS account.
  - ***cd*** into the terraform directory *(make sure you have Terraform installed)*
  - Run ***terraform init***
  - Run ***terraform apply***


## 2 - Deploy the Application and Web/App Servers with Ansible
The Ansible playbook provided will deploy the application.

**Steps:**
  - ***SSH*** into the Ansible controller.
  - Update the /***ec2-user/lamp-stack-v1/ansible/inventory*** "host" parameter with the private IP of the 2 app-server machines that were provisioned.
  - Run:
      > ansible-playbook lamp-stack-v1/ansible/main.yml -i lamp-stack-v1/ansible/inventory

You should now be able to login to either app server, and run ***docker ps*** to see the NGINX and Flask-application containers running.

## 3 - Setup Registrar

Navigate to the Domain Registrar where you purchased your domain, swap the nameservers with the 4 Nameservers provided to you in your Hosted Zone.

# 4 - Done!

You should now be able to hit your URL in your browser.


## Enhancements...
- Run the ansible playbook within a Packer template for an immutable infrastructure that won't require users to run the playbook manually on ephemeral instances of an ASG.
- Modularize the Terraform template and add outputs.
- Add more validation for TF code (i.e can / try blocks)
- Use cidrsubnet function to condense subnet input.
- Use cloudposse for tags
