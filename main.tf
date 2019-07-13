# cloudwatch dashboard to monitor EC2 instances

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "dashboard"
  dashboard_body = <<EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 6,
            "height": 3,
            "properties": {
                "view": "singleValue",
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "InstanceId", "instance_id", { "label": "site_name" } ]
                ],
                "region": "eu-west-1"
            }
        }
    ]
}
 EOF
}


# lambda function which update EC2 metrics of CloudWatch

resource "aws_lambda_function" "EC2DashboardUpdater" {
  filename         = "functions/ec2DashboardUpdater.zip"
  function_name    = "EC2DashboardUpdater"
  role             = "${aws_iam_role.Lambda-EC2DashboardUpdater-role.arn}"
  handler          = "ec2DashboardUpdater.handler"
  timeout          = "60"
  runtime          = "nodejs8.10"
  source_code_hash = "${base64sha256(file("functions/ec2DashboardUpdater.zip"))}"
  environment {
    variables = {
      AWS_DASHBOARDS   =  "[{\"dashboardName\": \"dashboard\", \"ec2DescribeInstanceParams\": { \"Filters\": [{\"Name\": \"tag:site\", \"Values\": [ \"site_name\"]}]}}]"
    }
  }
}


# role/policy allowing lambda to update dashboards

resource "aws_iam_role" "Lambda-EC2DashboardUpdater-role" {
  name               = "Lambda-EC2DashboardUpdater"
  description        = "Lambda-EC2DashboardUpdater" 
  assume_role_policy = "${data.aws_iam_policy_document.Lambda-EC2DashboardUpdater-role.json}"
}

data "aws_iam_policy_document" "Lambda-EC2DashboardUpdater-role" {
  statement {
    effect  = "Allow"
    actions = [ "sts:AssumeRole" ]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "Lambda-EC2DashboardUpdater-policy" {
  name   = "Lambda-EC2DashboardUpdater"
  role   = "${aws_iam_role.Lambda-EC2DashboardUpdater-role.id}"
  policy = "${data.aws_iam_policy_document.Lambda-EC2DashboardUpdater-policy.json}"
}

data "aws_iam_policy_document" "Lambda-EC2DashboardUpdater-policy" {
  statement {
    effect   = "Allow"

    actions  = [
      "cloudwatch:GetDashboard",
      "cloudwatch:PutDashboard",
      "ec2:DescribeInstances"
    ]

    resources = [
      "*",
    ]
  }
}


# cloudwatch rule/event to trigger the lambda

resource "aws_cloudwatch_event_rule" "Lambda-EC2DashboardUpdater" {
    name                 = "Lambda-EC2DashboardUpdater"
    description          = "Lambda-EC2DashboardUpdater"
    schedule_expression  = "cron(0 10 * * ? *)"
}

resource "aws_cloudwatch_event_target" "Lambda-EC2DashboardUpdater" {
    rule        = "${aws_cloudwatch_event_rule.Lambda-EC2DashboardUpdater.name}"
    target_id   = "SendToLambda"
    arn         = "${aws_lambda_function.EC2DashboardUpdater.arn}"
}
