# Terraform/OpenTofu module for creating IAM profile for Let's Encrypt DNS challenge

This module configures the necessary IAM role for the Let's Encrypt DNS challenge. The role will have only the permissions required to create `_acme-challenge` TXT records for the appropriate hostname. You need to provide the module with the hostname and the AWS Route53 hosted zone ID.

## Usage

```terraform
module "lego-iam" {
  source     = "../modules/lego-iam"
  hostname   = var.hostname
  hostedzone = var.hostedzone
}

resource "aws_instance" "instance-with-letsencrypt" {
  ...
  iam_instance_profile   = module.lego-iam.instance-profile-name
  ...
}
```

## Additional Resources

For a more in-depth explanation and practical examples, check out the blog post here:
**[How to manage Let's Encrypt certificate on EC2 instance](https://www.cyberpunk.tools/jekyll/update/2025/03/31/lego-ec2.html)**
