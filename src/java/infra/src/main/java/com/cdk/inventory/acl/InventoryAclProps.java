package com.cdk.inventory.acl;

import com.cdk.constructs.SharedProps;
import software.amazon.awscdk.services.events.IEventBus;

public record InventoryAclProps(SharedProps sharedProps, IEventBus sharedEventBus) { }
