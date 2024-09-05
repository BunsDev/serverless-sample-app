//
// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024 Datadog, Inc.
//

module "product_api_pricing_worker" {
  publish_directory = "../src/Product.Api/ProductApi.Adapters/bin/Release/net8.0/ProductApi.Adapters.zip"
  service_name   = "DotnetProductApi"
  source         = "../../modules/lambda-function"
  function_name  = "PriceCalculatedHandlerFunction"
  lambda_handler = "ProductApi.Adapters::ProductApi.Adapters.HandlerFunctions_HandlePricingUpdated_Generated::HandlePricingUpdated"
  environment_variables = {
    TABLE_NAME : data.aws_ssm_parameter.product_api_table_name.value
    DD_SERVICE_MAPPING : "lambda_sns:${data.aws_ssm_parameter.product_pricing_changed_topic_name.value}"
  }
  dd_api_key_secret_arn = var.dd_api_key_secret_arn
  dd_site = var.dd_site
}


resource "aws_iam_role_policy_attachment" "allow_dynamo_read_permission" {
  role       = module.product_api_pricing_worker.function_role_name
  policy_arn = aws_iam_policy.dynamo_db_read.arn
}
resource "aws_iam_role_policy_attachment" "allow_dynamo_write_permission" {
  role       = module.product_api_pricing_worker.function_role_name
  policy_arn = aws_iam_policy.dynamo_db_write.arn
}

resource "aws_lambda_permission" "product_pricing_changed_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = module.product_api_pricing_worker.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = data.aws_ssm_parameter.product_pricing_changed_topic.value
}


resource "aws_sns_topic_subscription" "product_created_sns_topic" {
  topic_arn = data.aws_ssm_parameter.product_pricing_changed_topic.value
  protocol  = "lambda"
  endpoint  = module.product_api_pricing_worker.function_arn
}
