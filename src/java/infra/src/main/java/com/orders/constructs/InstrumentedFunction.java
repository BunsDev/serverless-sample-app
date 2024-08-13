package com.orders.constructs;

import org.jetbrains.annotations.NotNull;
import software.amazon.awscdk.Duration;
import software.amazon.awscdk.services.lambda.*;
import software.amazon.awscdk.services.lambda.Runtime;
import software.amazon.awscdk.services.s3.Bucket;
import software.amazon.awscdk.services.s3.IBucket;
import software.amazon.awscdk.services.s3.assets.Asset;
import software.constructs.Construct;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class InstrumentedFunction extends Construct {
    private final IFunction function;
    private final IAlias alias;

    public InstrumentedFunction(@NotNull Construct scope, @NotNull String id, @NotNull InstrumentedFunctionProps props) {
        super(scope, id);

        Asset fileAsset = Asset.Builder.create(this, "LambdaFunctionJarS3Asset")
                .path("../application/target/com.orders.application-0.0.1-SNAPSHOT-aws.jar").build();

        Map<String, String> lambdaEnvironment = new HashMap<>();
        lambdaEnvironment.put("MAIN_CLASS", "com.orders.application.FunctionConfiguration");
        lambdaEnvironment.put("AWS_LAMBDA_EXEC_WRAPPER", "/opt/datadog_wrapper");
        lambdaEnvironment.put("DD_SITE", "datadoghq.eu");
        lambdaEnvironment.put("DD_SERVICE", props.getSharedProps().getService());
        lambdaEnvironment.put("DD_ENV", props.getSharedProps().getEnv());
        lambdaEnvironment.put("ENV", props.getSharedProps().getEnv());
        lambdaEnvironment.put("DD_VERSION", props.getSharedProps().getVersion());
        lambdaEnvironment.put("DD_API_KEY_SECRET_ARN", props.getSharedProps().getDdApiKeySecret().getSecretArn());
        lambdaEnvironment.put("DD_CAPTURE_LAMBDA_PAYLOAD", "true");
        lambdaEnvironment.put("spring_cloud_function_definition", props.getRoutingExpression());

        // Add custom environment variables to the default set.
        lambdaEnvironment.putAll(props.getEnvironmentVariables());

        List<ILayerVersion> layers = new ArrayList<>(2);
        layers.add(LayerVersion.fromLayerVersionArn(this, "DatadogJavaLayer", "arn:aws:lambda:eu-west-1:464622532012:layer:dd-trace-java:15"));
        layers.add(LayerVersion.fromLayerVersionArn(this, "DatadogLambdaExtension", "arn:aws:lambda:eu-west-1:464622532012:layer:Datadog-Extension:59"));

        IBucket bucket = Bucket.fromBucketName(this, "CDKBucket", fileAsset.getS3BucketName());

        // Create our basic function
        this.function = Function.Builder.create(this, "OrderConfirmedHandler")
                .functionName(id)
                .snapStart(SnapStartConf.ON_PUBLISHED_VERSIONS)
                .runtime(Runtime.JAVA_21)
                .memorySize(2048)
                .handler("org.springframework.cloud.function.adapter.aws.FunctionInvoker::handleRequest")
                .environment(lambdaEnvironment)
                .timeout(Duration.seconds(30))
                .code(Code.fromBucket(bucket, fileAsset.getS3ObjectKey()))
                .layers(layers)
                .build();

        var version = new Version(this, String.format("%sVersion", id), VersionProps.builder()
                .lambda(this.function)
                .build());
        
        this.alias = new Alias(this, String.format("%sAlias", id), AliasProps.builder()
                .aliasName("prod")
                .version(version)
                .build());

        props.getSharedProps().getDdApiKeySecret().grantRead(this.function);
    }

    public IFunction getFunction() {
        return function;
    }

    public IAlias getAlias() {
        return alias;
    }
}
