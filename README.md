# AWS Infrastructure :- 

Write the following AWS infrastructure as code in terraform,
1. VPC
• Name: “ionginx-vpc”
• Public Subnet – 3
• Private Subnet – 3
• Internet Gateway – 1
• NAT Gateway – 1
2. EC2 Auto Scaling Group
• Minimum – 2
• Maximum – 4
• Subnets – Only Private Subnets
• NGINX on Ubuntu
• Don’t assign Public IPv4 to EC2 Instances
• Don’t allow SSH Access to EC2 Instance
3. Route 53 A Record
• Pointing to the NAT Gateway and allow nginx to serve the default webpage.
Share the code and snippets in a Git repository. 
