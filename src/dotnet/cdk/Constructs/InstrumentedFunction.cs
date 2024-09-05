using System;
using System.Collections.Generic;
using System.Linq;
using Amazon.CDK;
using Amazon.CDK.AWS.Lambda;
using Amazon.CDK.AWS.Lambda.DotNet;
using Amazon.CDK.AWS.Logs;
using Amazon.CDK.AWS.SecretsManager;
using Constructs;

namespace ServerlessGettingStarted.CDK.Constructs;

public record FunctionProps(SharedProps Shared, string FunctionName, string ProjectPath, string Handler, Dictionary<string, string> EnvironmentVariables, ISecret DdApiKeySecret);

public class InstrumentedFunction : Construct
{
    public IFunction Function { get; private set; }
    
    public InstrumentedFunction(Construct scope, string id, FunctionProps props) : base(scope, id)
    {
        if (props.Handler.Length > 128)
        {
            throw new Exception(
                "Function handler cannot be greater than 128 chars. https://docs.aws.amazon.com/lambda/latest/api/API_CreateFunction.html#lambda-CreateFunction-request-Handler");
        }
        var functionName = $"{props.Shared.ServiceName}-{props.FunctionName}-{props.Shared.Env}";

        var defaultEnvironmentVariables = new Dictionary<string, string>()
        {
            { "POWERTOOLS_SERVICE_NAME", props.Shared.ServiceName },
            { "POWERTOOLS_LOG_LEVEL", "DEBUG" },
            { "AWS_LAMBDA_EXEC_WRAPPER", "/opt/datadog_wrapper" }, 
            { "DD_SITE", System.Environment.GetEnvironmentVariable("DD_SITE") },
            { "DD_ENV", props.Shared.Env },
            { "ENV", props.Shared.Env },
            { "DD_VERSION", props.Shared.Version },
            { "DD_SERVICE", props.Shared.ServiceName },
            { "DD_API_KEY_SECRET_ARN", props.DdApiKeySecret.SecretArn },
            { "DD_CAPTURE_LAMBDA_PAYLOAD", "true" },
        };
        
        Function = new DotNetFunction(this, id,
            new DotNetFunctionProps
            {
                ProjectDir = props.ProjectPath,
                Handler = props.Handler,
                MemorySize = 1024,
                Timeout = Duration.Seconds(29),
                Runtime = Runtime.DOTNET_8,
                Environment = defaultEnvironmentVariables.Union(props.EnvironmentVariables).ToDictionary(x => x.Key, x => x.Value),
                Architecture = Architecture.ARM_64,
                FunctionName = functionName,
                LogRetention = RetentionDays.ONE_DAY,
                Layers =
                [
                    LayerVersion.FromLayerVersionArn(this, "DDExtension", "arn:aws:lambda:eu-west-1:464622532012:layer:Datadog-Extension-ARM:64"),
                    LayerVersion.FromLayerVersionArn(this, "DDTrace", "arn:aws:lambda:eu-west-1:464622532012:layer:dd-trace-dotnet-ARM:15"),
                ],
            });

        props.DdApiKeySecret.GrantRead(Function);
    }
}