# Setup for mux webhook lambda
data "archive_file" "mux_webhook_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/handlers/mux_webhook_lambda/"
  output_path = "${path.module}/lambda/dist/mux_webhook_lambda.zip"
}

# Setup for util lambda layer
data "archive_file" "utils_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/layers/util-layer/"
  output_path = "${path.module}/lambda/dist/utils.zip"
}

# Setup for dependencies lambda layer
data "archive_file" "deps_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/layers/deps-layer/"
  output_path = "${path.module}/lambda/dist/deps.zip"
}

# The cloudwatch iam policy for lambda
data "aws_iam_policy" "cloudwatch_iam_policy_for_lambda" {
  name = var.cloudwatch_lambda_iam_policy
}

# template file to use for lambda
data "template_file" "lambda_assume_role_policy" {
  template = file("./template/mux_webhook_sqs_to_lambda_to_eventbridge_role.tpl")
}

# template file for policy for sqs to send messages to lambda
data "template_file" "mux_webhook_sqs_to_lambda_policy_template" {
  template = file("./template/mux_webhook_sqs_to_lambda_policy.tpl")

  vars = {
    sqsarn = aws_sqs_queue.mux_webhook_sqs.arn
  }
}

data "template_file" "event_bridge_put_events_policy_template" {
  template = file("./template/event_bridge_put_events_policy.tpl")

  vars = {
    eventBusArn = aws_cloudwatch_event_bus.mux_webhook_event_bus.arn
  }
}

# template file for IAM role to send messages from API gateway to SQS
data "template_file" "mux_webhook_APIGW_to_SQS_Role_template" {
  template = file("./template/mux_webhook_APIGW_to_SQS_Role.tpl")
}

# template file for IAM policy to send messages from API gateway to SQS
data "template_file" "mux_webhook_APIGW_to_SQS_Policy_template" {
  template = file("./template/mux_webhook_APIGW_to_SQS_Policy.tpl")

  vars = {
    sqsarn = aws_sqs_queue.mux_webhook_sqs.arn
  }
}

# initialize the current caller to get their account number information
data "aws_caller_identity" "current" {}

# template for the logging policy of API gateway
data "template_file" "mux_webhook_APIGW_logPolicy_template" {
  template = file("./template/mux_webhook_APIGW_logPolicy.tpl")

  vars = {
    logGroup = aws_cloudwatch_log_group.mux_webhook_APIGW_logGroup.arn
    apiarn   = aws_api_gateway_rest_api.mux_webhook_api.arn
  }
}

# data to grab the mux secret from hcp vault secrets
data "hcp_vault_secrets_secret" "mux_access_token_id" {
  app_name    = "movie-app"
  secret_name = var.mux_access_token_id
}

# data to grab the mux webhook signing secret from hcp vault secrets
data "hcp_vault_secrets_secret" "mux_access_token_secret" {
  app_name    = "movie-app"
  secret_name = var.mux_access_token_secret
}

data "hcp_vault_secrets_secret" "mux_webhook_signing_secret" {
  app_name    = "movie-app"
  secret_name = var.mux_webhook_signing_secret
}

# template for the cloudwatch logging policy for eventbridge
# data "template_file" "mux_webhook_eventbridge_log_groupPolicy_template" {
#   template = file("./template/mux_webhook_eventbridge_log_groupPolicy.tpl")
#   todo fix template to allow for logging
#   vars = {
#     logGroup     = aws_cloudwatch_log_group.mux_webhook_eventbridge_log_group.arn
#     eventRuleArn = aws_cloudwatch_event_rule.mux_webhook_eventbridge_event_rule.arn
#   }
# }

data "template_file" "mux_webhook_eventbridge_event_rule_pattern_template" {
  template = file("./template/mux_webhook_eventbridge_event_rule_pattern.tpl")

  vars = {
    # account_id  = data.aws_caller_identity.current.account_id
    eventSource = var.mux_lambda_event_source
  }
}
