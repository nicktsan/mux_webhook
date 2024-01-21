variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "environment for code (ie: dev, prod)"
  type        = string
}

variable "lambda_runtime" {
  description = "runtime for lambda"
  type        = string
}

variable "mux_webhook_lambda_iam_role" {
  description = "Name of the IAM role for the lambda function"
  type        = string
}

variable "cloudwatch_lambda_iam_policy" {
  description = "Name of the cloudwatch policy for the lambda function"
  type        = string
}

variable "mux_webhook_sqs_to_lambda_policy_name" {
  description = "Name of the policy to provide receive message, delete message, and read attribute access to SQS queues"
  type        = string
}

variable "event_bridge_put_events_policy_name" {
  description = "Name of the policy to send messages to Eventbridge"
  type        = string
}

variable "mux_webhook_APIGW_to_SQS_Role_name" {
  description = "Name of the role for API Gateway to send messages to SQS"
  type        = string
}

variable "mux_webhook_APIGW_to_SQS_Policy_name" {
  description = "Name of the policy for API Gateway to send messages to SQS"
  type        = string
}

variable "apigwVersion" {
  description = "version of the mux webhook api"
  type        = string
}

variable "dev_mux_webhook_bucket_name" {
  description = "name of the dev_mux_webhook_bucket"
  type        = string
}

variable "deps_layer_storage_key" {
  description = "Key of the S3 Object that will store deps lambda layer"
  type        = string
}

variable "path" {
  description = "last part of the api gateway url"
  type        = string
}

variable "mux_access_token_id" {
  description = "access token id for mux stored in hcp vault secrets"
  type        = string
  sensitive   = true
}

variable "mux_access_token_secret" {
  description = "secret of the access token from mux stored in hcp vault secrets"
  type        = string
  sensitive   = true
}

variable "mux_webhook_signing_secret" {
  description = "signing secret of the mux webhook stored in hcp vault secrets"
  type        = string
  sensitive   = true
}

variable "utils_layer_storage_key" {
  description = "Key of the S3 object that will store utils lambda layer"
  type        = string
}

# variable "revision" {
#   description = "Revision of deployment"
#   type        = string
# }

variable "event_bus_name" {
  description = "Name of the Eventbridge event bus"
  type        = string
}

variable "mux_lambda_event_source" {
  description = "value of 'Source' parameter in index.ts"
  type        = string
}

variable "api_name" {
  description = "Name of the rest api"
  type        = string
}
# variable "detail_type" {
#   description = "DetailType in eventbridge message sent to eventbridge from lambda"
#   type        = string
# }

# variable "mux_webhook_eventbridge_event_rule_name" {
#   description = "Name of mux_webhook_eventbridge_event_rule"
#   type        = string
# }
