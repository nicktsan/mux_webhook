#SQS to receieve messages from api gateway
resource "aws_sqs_queue" "mux_webhook_sqs" {
  name                    = "mux-webhook-sqs"
  sqs_managed_sse_enabled = true
  tags = {
    Environment = var.environment
  }
}
#set up a policy for the first sqs to send dead letters to the dlq
resource "aws_sqs_queue_redrive_policy" "mux_webhook_sqs_redrive_policy" {
  queue_url = aws_sqs_queue.mux_webhook_sqs.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.mux_webhook_sqs_dlq.arn
    maxReceiveCount     = 4
  })
}
#SQS to receive dead letters
resource "aws_sqs_queue" "mux_webhook_sqs_dlq" {
  name                      = "mux-webhook-sqs-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags = {
    Environment = var.environment
  }
}
#policy to receieve dead letters from the original sqs
resource "aws_sqs_queue_redrive_allow_policy" "mux_webhook_sqs_dlq_redirve_allow_policy" {
  queue_url = aws_sqs_queue.mux_webhook_sqs_dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.mux_webhook_sqs.arn]
  })
}

#IAM Resource block for Lambda IAM role.
resource "aws_iam_role" "mux_webhook_sqs_to_lambda_to_eventbridge_role" {
  name               = var.mux_webhook_lambda_iam_role
  assume_role_policy = data.template_file.lambda_assume_role_policy.rendered
}

#attach both IAM Policy and IAM Role to each other:
resource "aws_iam_role_policy_attachment" "attach_cloudwatch_iam_policy_for_lambda" {
  role       = aws_iam_role.mux_webhook_sqs_to_lambda_to_eventbridge_role.name
  policy_arn = data.aws_iam_policy.cloudwatch_iam_policy_for_lambda.arn
}

#IAM policy to provide receive message, delete message, and read attribute access to SQS queues
resource "aws_iam_policy" "mux_webhook_sqs_to_lambda_policy" {
  name        = var.mux_webhook_sqs_to_lambda_policy_name
  path        = "/"
  description = "IAM policy to provide receive message, delete message, and read attribute access to SQS queues"
  policy      = data.template_file.mux_webhook_sqs_to_lambda_policy_template.rendered
  lifecycle {
    create_before_destroy = true
  }
}

#attach mux_webhook_sqs_to_lambda_policy to mux_webhook_sqs_to_lambda_to_eventbridge_role
resource "aws_iam_role_policy_attachment" "attach_mux_webhook_sqs_to_lambda_policy" {
  role       = aws_iam_role.mux_webhook_sqs_to_lambda_to_eventbridge_role.name
  policy_arn = aws_iam_policy.mux_webhook_sqs_to_lambda_policy.arn
}

# lambda to receive message from sqs
resource "aws_lambda_function" "mux_webhook_lambda" {
  filename      = data.archive_file.mux_webhook_lambda_zip.output_path
  function_name = "mux_webhook_lambda"
  role          = aws_iam_role.mux_webhook_sqs_to_lambda_to_eventbridge_role.arn
  handler       = "index.handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.mux_webhook_lambda_zip.output_base64sha256
  runtime          = var.lambda_runtime
  layers = [
    aws_lambda_layer_version.lambda_deps_layer.arn,
    aws_lambda_layer_version.lambda_utils_layer.arn
  ]

  environment {
    variables = {
      MUX_TOKEN_ID               = data.hcp_vault_secrets_secret.mux_access_token_id.secret_value
      MUX_TOKEN_SECRET           = data.hcp_vault_secrets_secret.mux_access_token_secret.secret_value
      MUX_WEBHOOK_SIGNING_SECRET = data.hcp_vault_secrets_secret.mux_webhook_signing_secret.secret_value
      MUX_EVENT_BUS              = var.event_bus_name
      MUX_LAMBDA_EVENT_SOURCE    = var.mux_lambda_event_source
    }
  }
}

resource "aws_lambda_layer_version" "lambda_deps_layer" {
  layer_name = "mux_webhook_shared_deps"
  s3_bucket  = aws_s3_bucket.dev_mux_webhook_bucket.id        #conflicts with filename
  s3_key     = aws_s3_object.lambda_deps_layer_s3_storage.key #conflicts with filename
  // If using s3_bucket or s3_key, do not use filename, as they conflict
  source_code_hash = data.archive_file.deps_layer_code_zip.output_base64sha256

  compatible_runtimes = [var.lambda_runtime]
  depends_on = [
    aws_s3_object.lambda_deps_layer_s3_storage,
  ]
}
# Create an s3 resource for storing the utils_layer
resource "aws_lambda_layer_version" "lambda_utils_layer" {
  layer_name       = "shared_utils"
  s3_bucket        = aws_s3_bucket.dev_mux_webhook_bucket.id         #conflicts with filename
  s3_key           = aws_s3_object.lambda_utils_layer_s3_storage.key #conflicts with filename
  source_code_hash = data.archive_file.utils_layer_code_zip.output_base64sha256

  compatible_runtimes = [var.lambda_runtime]
  depends_on = [
    aws_s3_object.lambda_utils_layer_s3_storage,
  ]
}

#create an s3 resource for storing the deps layer
resource "aws_s3_object" "lambda_deps_layer_s3_storage" {
  bucket = aws_s3_bucket.dev_mux_webhook_bucket.id
  key    = var.deps_layer_storage_key
  source = data.archive_file.deps_layer_code_zip.output_path

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = data.archive_file.deps_layer_code_zip.output_base64sha256
  depends_on = [
    data.archive_file.deps_layer_code_zip,
  ]
}

# create an s3 object for storing the utils layer
resource "aws_s3_object" "lambda_utils_layer_s3_storage" {
  bucket = aws_s3_bucket.dev_mux_webhook_bucket.id
  key    = var.utils_layer_storage_key
  source = data.archive_file.utils_layer_code_zip.output_path

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = data.archive_file.utils_layer_code_zip.output_base64sha256
  depends_on = [
    data.archive_file.utils_layer_code_zip,
  ]
}

resource "aws_s3_bucket" "dev_mux_webhook_bucket" {
  bucket = "movies-mux-webhook-bucket"

  tags = {
    Name        = "My mux_webhook dev bucket"
    Environment = "dev"
  }
}
//applies an s3 bucket acl resource to s3_backend
resource "aws_s3_bucket_acl" "s3_acl" {
  bucket     = aws_s3_bucket.dev_mux_webhook_bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.dev_mux_webhook_bucket_acl_ownership]
}
# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "dev_mux_webhook_bucket_acl_ownership" {
  bucket = aws_s3_bucket.dev_mux_webhook_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

#Allows lambdas to receive events from SQS
resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn        = aws_sqs_queue.mux_webhook_sqs.arn
  function_name           = aws_lambda_function.mux_webhook_lambda.arn
  function_response_types = ["ReportBatchItemFailures"]
}

# Create an IAM role for API Gateway
resource "aws_iam_role" "mux_webhook_APIGW_to_SQS_Role" {
  name               = var.mux_webhook_APIGW_to_SQS_Role_name
  assume_role_policy = data.template_file.mux_webhook_APIGW_to_SQS_Role_template.rendered
}

# Create an IAM policy for API Gateway to send messages to SQS
resource "aws_iam_policy" "mux_webhook_APIGW_to_SQS_Policy" {
  name        = var.mux_webhook_APIGW_to_SQS_Policy_name
  path        = "/"
  description = "IAM policy to for API Gateway to send messages to SQS"
  policy      = data.template_file.mux_webhook_APIGW_to_SQS_Policy_template.rendered
  lifecycle {
    create_before_destroy = true
  }
}

# Attach the IAM mux_webhook_APIGW_to_SQS_Policy to mux_webhook_APIGW_to_SQS_Role
resource "aws_iam_role_policy_attachment" "APIGWPolicyAttachment" {
  role       = aws_iam_role.mux_webhook_APIGW_to_SQS_Role.name
  policy_arn = aws_iam_policy.mux_webhook_APIGW_to_SQS_Policy.arn
}

# Create a REST API Gateway
resource "aws_api_gateway_rest_api" "mux_webhook_api" {
  name        = var.api_name
  description = "mux webhook"
}

#Configure API Gateway resource
resource "aws_api_gateway_resource" "mux_webhook_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.mux_webhook_api.id
  parent_id   = aws_api_gateway_rest_api.mux_webhook_api.root_resource_id
  path_part   = var.path
}

#Configure API Gateway method request
resource "aws_api_gateway_method" "mux_webhook_api_method" {
  rest_api_id   = aws_api_gateway_rest_api.mux_webhook_api.id
  resource_id   = aws_api_gateway_resource.mux_webhook_api_resource.id
  http_method   = "POST"
  authorization = "NONE"
  request_parameters = {
    "method.request.header.mux-signature" = true,
  }
}

#Configure API Gateway integration
resource "aws_api_gateway_integration" "mux_webhook_api_integration" {
  rest_api_id             = aws_api_gateway_rest_api.mux_webhook_api.id
  resource_id             = aws_api_gateway_resource.mux_webhook_api_resource.id
  http_method             = aws_api_gateway_method.mux_webhook_api_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = join("", ["arn:aws:apigateway:", var.region, ":sqs:path/", data.aws_caller_identity.current.account_id, "/", aws_sqs_queue.mux_webhook_sqs.name])
  credentials             = aws_iam_role.mux_webhook_APIGW_to_SQS_Role.arn
  request_parameters = {
    "integration.request.header.Content-Type"                              = "'application/x-www-form-urlencoded'"
    "integration.request.querystring.MessageAttribute.1.Name"              = "'muxSignature'"
    "integration.request.querystring.MessageAttribute.1.Value.DataType"    = "'String'"
    "integration.request.querystring.MessageAttribute.1.Value.StringValue" = "method.request.header.mux-signature"
  }
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
  }
  passthrough_behavior = "NEVER"
}

# Configure API Gateway to push all logs to CloudWatch Logs
resource "aws_api_gateway_method_settings" "muxWebhookGatewaySettings" {
  rest_api_id = aws_api_gateway_rest_api.mux_webhook_api.id
  stage_name  = aws_api_gateway_stage.muxWebhookGatewayStage.stage_name
  method_path = "*/*"

  settings {
    # Enable CloudWatch logging and metrics
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

# Configure API Gateway integration response
resource "aws_api_gateway_integration_response" "mux_webhook_api_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.mux_webhook_api.id
  resource_id = aws_api_gateway_resource.mux_webhook_api_resource.id
  http_method = aws_api_gateway_method.mux_webhook_api_method.http_method
  status_code = aws_api_gateway_method_response.mux_webhook_api_method_response.status_code
}

# Configure API Gateway method response
resource "aws_api_gateway_method_response" "mux_webhook_api_method_response" {
  rest_api_id = aws_api_gateway_rest_api.mux_webhook_api.id
  resource_id = aws_api_gateway_resource.mux_webhook_api_resource.id
  http_method = aws_api_gateway_method.mux_webhook_api_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

# Create a new API Gateway deployment for the created rest api
resource "aws_api_gateway_deployment" "mux_webhook_api_deployment" {
  depends_on  = [aws_api_gateway_integration.mux_webhook_api_integration]
  rest_api_id = aws_api_gateway_rest_api.mux_webhook_api.id

  #Trigger API Gateway redeployment based on changes to the following resources
  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.mux_webhook_api_resource.id,
      aws_api_gateway_method.mux_webhook_api_method.id,
      aws_api_gateway_integration.mux_webhook_api_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
    # replace_triggered_by  = [terraform_data.mux_webhook_api_deployment_replacement]
  }
}

# Create a Log Group for API Gateway to push logs to
resource "aws_cloudwatch_log_group" "mux_webhook_APIGW_logGroup" {
  name_prefix = "/aws/mux-webhook-APIGW/terraform"
}

# Create a Log Policy to allow Cloudwatch to Create log streams and put logs
resource "aws_cloudwatch_log_resource_policy" "mux_webhook_APIGW_logPolicy" {
  policy_name     = "Terraform-mux_webhook_APIGW_logPolicy-${data.aws_caller_identity.current.account_id}"
  policy_document = data.template_file.mux_webhook_APIGW_logPolicy_template.rendered
}


# Create a new API Gateway stage with logging enabled
resource "aws_api_gateway_stage" "muxWebhookGatewayStage" {
  deployment_id = aws_api_gateway_deployment.mux_webhook_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.mux_webhook_api.id
  stage_name    = "default"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.mux_webhook_APIGW_logGroup.arn
    format = join(", ", ["{ \"requestId\":\"$context.requestId\"",
      "\"ip\":\"$context.identity.sourceIp\"",
      "\"requestTime\":\"$context.requestTime\"",
      "\"httpMethod\":\"$context.httpMethod\"",
      "\"routeKey\":\"$context.routeKey\"",
      "\"status\":\"$context.status\",\"protocol\":\"$context.protocol\"",
      "\"responseLength\":\"$context.responseLength\"",
      "\"authorizererror\":\"$context.authorizer.error\"",
      "\"errormessage\":\"$context.error.message\"",
      "\"errormessageString\":\"$context.error.messageString\"",
      "\"errorresponseType\":\"$context.error.responseType\"",
      "\"integrationerror\":\"$context.integration.error\"",
    "\"integrationErrorMessage\":\"$context.integrationErrorMessage\" }"])
  }
}

# Create the custom Eventbridge event bus
resource "aws_cloudwatch_event_bus" "mux_webhook_event_bus" {
  name = var.event_bus_name
}

#IAM policy for Lambda to send events to eventbridge
resource "aws_iam_policy" "event_bridge_put_events_policy" {
  name        = var.event_bridge_put_events_policy_name
  path        = "/"
  description = "IAM policy to send events to eventbridge"
  policy      = data.template_file.event_bridge_put_events_policy_template.rendered
  lifecycle {
    create_before_destroy = true
  }
}

#attach both IAM Policy and IAM Role to each other:
resource "aws_iam_role_policy_attachment" "attach_event_bridge_put_events_policy_for_lambda" {
  role       = aws_iam_role.mux_webhook_sqs_to_lambda_to_eventbridge_role.name
  policy_arn = aws_iam_policy.event_bridge_put_events_policy.arn
}

#TODO implement alarm for DLQ
