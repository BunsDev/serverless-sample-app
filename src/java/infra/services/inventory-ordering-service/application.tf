//
// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024 Datadog, Inc.
//

module "inventory_ordering_service" {
  service_name   = "JavaInventoryOrderingService"
  package_name = "com.inventory.ordering"
  source         = "../../modules/lambda-function"
  jar_file       = "../inventory-ordering-service/target/com.inventory.ordering-0.0.1-SNAPSHOT-aws.jar"
  function_name  = "InventoryOrderingService"
  lambda_handler = "handleNewProductAdded"
  environment_variables = {
    ORDERING_SERVICE_WORKFLOW_ARN : aws_sfn_state_machine.inventory_ordering_state_machine.arn
    DD_SERVICE_MAPPING : "lambda_sns:${data.aws_ssm_parameter.product_added_topic.value}"
  }
  dd_api_key_secret_arn = var.dd_api_key_secret_arn
  dd_site = var.dd_site
  env = var.env
  app_version = var.app_version
}

resource "aws_iam_role_policy_attachment" "product_created_handler_sqs_receive_permission" {
  role       = module.inventory_ordering_service.function_role_name
  policy_arn = aws_iam_policy.sfn_start_execution.arn
}

resource "aws_lambda_permission" "product_created_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = module.inventory_ordering_service.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = data.aws_ssm_parameter.product_added_topic.value
}

resource "aws_sns_topic_subscription" "product_created_sns_topic" {
  topic_arn = data.aws_ssm_parameter.product_added_topic.value
  protocol  = "lambda"
  endpoint  = module.inventory_ordering_service.function_arn
}

resource "aws_cloudwatch_log_group" "sfn_log_group" {
  name              = "/aws/vendedlogs/states/JavaTfInventoryOrderingServiceLogGroup-${var.env}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}


resource "aws_sfn_state_machine" "inventory_ordering_state_machine" {
  name     = "java-tf-inventory-ordering-service-${var.env}"
  role_arn = aws_iam_role.invetory_ordering_sfn_role.arn
  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_log_group.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  definition = file("${path.module}/../../../cdk/src/main/java/com/cdk/inventory/ordering/workflows/workflow.sample.asl.json")
  tags = {
    DD_ENHANCED_METRICS : "true"
    DD_TRACE_ENABLED : "true"
  }
}

resource "aws_ssm_parameter" "api_endpoint" {
  name  = "/java/${var.env}/inventory-ordering/state-machine-arn"
  type  = "String"
  value = aws_sfn_state_machine.inventory_ordering_state_machine.arn
}
