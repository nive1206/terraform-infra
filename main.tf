data "aws_caller_identity" "current" {}

locals {
  repo_name    = var.repo_name
  repo_zip     = var.repo_zip
  account_id   = data.aws_caller_identity.current.account_id
  cluster_name = "microservices-cluster"

  # Enable section based on the counter
  enable_section_3 = lookup(var.section_counter, "section_3", false) == true ? 1 : 0
  enable_section_4 = (
    local.enable_section_3 * (lookup(var.section_counter, "section_4", false) == true ? 1 : 0)
  ) == 1 ? 1 : 0
  enable_section_5 = (
    local.enable_section_4 * (lookup(var.section_counter, "section_5", false) == true ? 1 : 0)
  ) == 1 ? 1 : 0
  enable_section_6 = (
    local.enable_section_4 * (lookup(var.section_counter, "section_6", false) == true ? 1 : 0)
  ) == 1 ? 1 : 0
  enable_section_7 = (
    local.enable_section_6 * (lookup(var.section_counter, "section_7", false) == true ? 1 : 0)
  ) == 1 ? 1 : 0
  enable_section_8 = (
    local.enable_section_5 * (lookup(var.section_counter, "section_8", false) == true ? 1 : 0)
  ) == 1 ? 1 : 0
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


resource "aws_security_group" "default" {
  name        = "microservices-sg"
  vpc_id      = data.aws_vpc.default.id
  description = "microservices-sg"

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

#permissions for codebuild role to run pipeline
resource "aws_iam_policy" "codebuild_policy" {
  name        = "CodeBuildPolicy-${var.repo_name}"
  description = "Policy for CodeBuild role to access S3 and IAM"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Statement1",
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "iam:PassRole",
          "s3:PutObject"
        ],
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# Attach AmazonEC2ContainerRegistryPowerUser policy to the role
resource "aws_iam_policy_attachment" "AmazonEC2ContainerRegistryPowerUser" {
  name       = "codebuild-policy-attachment-${var.repo_name}"
  roles      = [aws_iam_role.codebuild_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_policy_attachment" "AWSElasticBeanstalkRoleECS" {
  name       = "codebuild-policy-attachment-${var.repo_name}"
  roles      = [aws_iam_role.codebuild_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkRoleECS"
}

resource "aws_iam_policy_attachment" "CloudWatchFullAccess" {
  name       = "codebuild-policy-attachment-${var.repo_name}"
  roles      = [aws_iam_role.codebuild_role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_policy_attachment" "AWSCodeCommitReadOnly" {
  name       = "codebuild-policy-attachment-${var.repo_name}"
  roles      = [aws_iam_role.codebuild_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitReadOnly"
}

# CodePipeline Role

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role-${var.repo_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
}


resource "aws_iam_policy" "codepipeline_custom_policy" {
  name = "CodepipelineCustomPolicy"
  path = "/"
  policy = jsonencode({
    "Statement" = [
      {
        "Action" = [
          "iam:PassRole"
        ],
        "Resource" = "*",
        "Effect"   = "Allow",
        "Condition" = {
          "StringEqualsIfExists" = {
            "iam:PassedToService" = [
              "cloudformation.amazonaws.com",
              "elasticbeanstalk.amazonaws.com",
              "ec2.amazonaws.com",
              "ecs-tasks.amazonaws.com"
            ]
          }
        }
      },
      {
        "Action" = [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive"
        ],
        "Resource" = "*",
        "Effect"   = "Allow"
      },
      {
        "Action" = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ],
        "Resource" = "*",
        "Effect"   = "Allow"
      },
      {
        "Action" = [
          "codestar-connections:UseConnection"
        ],
        "Resource" = "*",
        "Effect"   = "Allow"
      },
      {
        "Action" = [
          "elasticbeanstalk:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "s3:*",
          "sns:*",
          "cloudformation:*",
          "rds:*",
          "sqs:*",
          "ecs:*"
        ],
        "Resource" = "*",
        "Effect"   = "Allow"
      },
      {
        "Action" = [
          "lambda:InvokeFunction",
          "lambda:ListFunctions"
        ],
        "Resource" = "*",
        "Effect"   = "Allow"
      },
      {
        "Action" = [
          "opsworks:CreateDeployment",
          "opsworks:DescribeApps",
          "opsworks:DescribeCommands",
          "opsworks:DescribeDeployments",
          "opsworks:DescribeInstances",
          "opsworks:DescribeStacks",
          "opsworks:UpdateApp",
          "opsworks:UpdateStack"
        ],
        "Resource" = "*",
        "Effect"   = "Allow"
      },
      {
        "Action" = [
          "cloudformation:CreateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:SetStackPolicy",
          "cloudformation:ValidateTemplate"
        ],
        "Resource" = "*",
        "Effect"   = "Allow"
      },
      {
        "Action" = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ],
        "Resource" = "*",
        "Effect"   = "Allow"
      },
      {
        "Effect" = "Allow",
        "Action" = [
          "devicefarm:ListProjects",
          "devicefarm:ListDevicePools",
          "devicefarm:GetRun",
          "devicefarm:GetUpload",
          "devicefarm:CreateUpload",
          "devicefarm:ScheduleRun"
        ],
        "Resource" = "*"
      },
      {
        "Effect" = "Allow",
        "Action" = [
          "servicecatalog:ListProvisioningArtifacts",
          "servicecatalog:CreateProvisioningArtifact",
          "servicecatalog:DescribeProvisioningArtifact",
          "servicecatalog:DeleteProvisioningArtifact",
          "servicecatalog:UpdateProduct"
        ],
        "Resource" = "*"
      },
      {
        "Effect" = "Allow",
        "Action" = [
          "cloudformation:ValidateTemplate"
        ],
        "Resource" = "*"
      },
      {
        "Effect" = "Allow",
        "Action" = [
          "ecr:DescribeImages"
        ],
        "Resource" = "*"
      },
      {
        "Effect" = "Allow",
        "Action" = [
          "states:DescribeExecution",
          "states:DescribeStateMachine",
          "states:StartExecution"
        ],
        "Resource" = "*"
      },
      {
        "Effect" = "Allow",
        "Action" = [
          "appconfig:StartDeployment",
          "appconfig:StopDeployment",
          "appconfig:GetDeployment"
        ],
        "Resource" = "*"
      }
    ],
    "Version" = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_custom_policy_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_custom_policy.arn
}

# Create IAM role for ECS Task Execution
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_AmazonECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create IAM role for ECS Instance
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-cluster-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ecs_instance_role" {
  name = "ecs-${local.cluster_name}"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_policy_attachment" "ecs_instance_role_attachment" {
  name       = "ecs-instance-role-attachment"
  roles      = [aws_iam_role.ecs_instance_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

module "section_3" {
  count = local.enable_section_3

  source    = "./modules/section-3"
  repo_name = local.repo_name
}


resource "null_resource" "upload_code" {
  count = local.enable_section_3

  depends_on = [module.section_3]

  provisioner "local-exec" {
    command = <<-EOT
      set -ex
      export AWS_DEFAULT_REGION=${local.region}
      export AWS_PROFILE=${local.profile}
      export ACCOUNT_ID=${local.account_id}
      export DIR_PATH="./assets/${local.repo_name}"

      mkdir -p assets
      cd assets
      git clone codecommit::${local.region}://${local.repo_name} || echo "Directory exists"

      unzip -o ${local.repo_zip} -d demo
      cp -r demo/* ${local.repo_name};rm -rf demo
      cd -

      python3 "./template_replace.py" || exit 1

      cd $DIR_PATH
      git config --global user.email "test@test.com"
      git config --global user.name "test"
      git add .
      
      set +ex
      git commit -m "Initial commit"
      git push 
      cd -
    EOT
  }
}

module "section_4" {
  count      = local.enable_section_4
  depends_on = [module.section_3]

  source         = "./modules/section-4"
  repo_name      = local.repo_name
  repo_url       = module.section_3[0].clone_url_http
  codebuild_role = aws_iam_role.codebuild_role.arn
}

module "section_5" {
  count      = local.enable_section_5
  depends_on = [module.section_4]

  source = "./modules/section-5"

  service_name           = local.repo_name
  desired_count          = 1
  cluster_name           = local.cluster_name
  container_image        = "${module.section_4[0].ecr_repository_url}:latest"
  aws_region             = local.region
  container_port         = 5000
  security_group_id      = aws_security_group.default.id
  create_tg              = local.enable_section_6 == 1 ? true : false
  target_group_arn       = local.enable_section_6 == 1 ? module.section_6[0].target_group_arn : ""
  task_execution_role    = aws_iam_role.ecsTaskExecutionRole.arn
  enable_circuit_breaker = local.enable_section_7 == 1 ? true : false
  instance_profile_name  = aws_iam_instance_profile.ecs_instance_role.name

}

module "section_6" {
  count      = local.enable_section_6
  depends_on = [module.section_4]

  source = "./modules/section-6"

  aws_region            = local.region
  codebuild_project_arn = module.section_4[0].codebuild_project_arn
  ecs_cluster_name      = local.cluster_name
  ecs_service_name      = local.repo_name
  ecs_service_port      = 5000
  vpc_id                = data.aws_vpc.default.id
  alb_security_group_id = aws_security_group.default.id
  subnets               = data.aws_subnets.default.ids
  alb_name              = "microservices-alb"
}

module "section_8" {
  count      = local.enable_section_8
  depends_on = [module.section_5]

  source = "./modules/section-8"

  cluster_name = local.cluster_name
  repo_name    = var.repo_name
  role_arn     = aws_iam_role.codepipeline_role.arn
}
