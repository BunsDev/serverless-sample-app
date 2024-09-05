// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024 Datadog, Inc.

namespace ProductEventPublisher.Core.InternalEvents;

public record ProductUpdatedEvent
{
    public string ProductId { get; set; } = "";

    public PriceDetails Updated { get; set; } = new();
}

public record PriceDetails
{
    public decimal Price { get; set; } = 0M;
}