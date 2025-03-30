terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "hostname" {
  type = list(string)
  description = "List of domains (e.g., ['google.com', '*.google.com'])"
}

variable "hostedzone" {
  type = string
}

locals {
  # Strip leading "*." and normalize to lowercase
  sanitized_hostname = [
    for hostname in var.hostname : lower(replace(hostname, "*.", ""))
  ]

  # Build list of _acme-challenge record names
  acme_challenge_names = [
    for hostname in local.sanitized_hostname : "_acme-challenge.${hostname}"
  ]
}

resource "aws_iam_policy" "lego_dns_policy" {
  name        = "${local.sanitized_hostname[0]}-lego_dns_policy"
  path        = "/"
  description = "Policy for lego scripts for letsencrypt for creating DNS records"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "route53:GetChange",
        "Resource" : "arn:aws:route53:::change/*"
      },
      {
        "Effect" : "Allow",
        "Action" : "route53:ListHostedZonesByName",
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ListResourceRecordSets"
        ],
        "Resource" : [
          "arn:aws:route53:::hostedzone/${var.hostedzone}"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource" : [
          "arn:aws:route53:::hostedzone/${var.hostedzone}"
        ],
        "Condition" : {
          "ForAllValues:StringEquals" : {
            "route53:ChangeResourceRecordSetsNormalizedRecordNames" : local.acme_challenge_names,
            "route53:ChangeResourceRecordSetsRecordTypes" : [
              "TXT"
            ]
          }
        }
      }
    ]
  })
}

#Create a role
resource "aws_iam_role" "lego_dns_role" {
  name = "${local.sanitized_hostname[0]}-lego_dns_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

#Attach role to policy
resource "aws_iam_role_policy_attachment" "lego_dns_policy_attach" {
  role       = aws_iam_role.lego_dns_role.name
  policy_arn = aws_iam_policy.lego_dns_policy.arn
}

#Attach role to an instance profile
resource "aws_iam_instance_profile" "lego_dns_instance_profile" {
  name = "${local.sanitized_hostname[0]}-lego_dns_instance_profile"
  role = aws_iam_role.lego_dns_role.name
}