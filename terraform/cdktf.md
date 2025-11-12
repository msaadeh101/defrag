# CDK for Terraform

## Background

**CDK for Terraform (CDKTF)** allows you to use programming languages to define and provision infrastructure, instead of writing HCL. You write TypeScript, Python, Java, C# or Go to bring in full IDE support, type safety, loops, conditionals and abstractions.

- **Type Safety**: Catch errors at compile time, not deployment time.
- **Abstraction**: Create reusable components and libraries.
- **Testing**: Unit test your infrastructure.
- **Dynamic Configuration**: Generate infrastructure based on runtime logic.
- **Better Refactoring**: IDE support for renaming, finding references, etc.

## TypeScript Fundamentals

### Type Annotations

```ts
// Basic types
const name: string = "my-resource";
const count: number = 3;
const enabled: boolean = true;

// Arrays, (Array<Type> for generics)
const regions: string[] = ["eastus", "westus"];
const sizes: Array<string> = ["Standard_B2s", "Standard_D2s_v3"];

// Objects
interface ResourceConfig {
    name: string;
    location: string;
    tags?: { [key: string]: string }; // Optional property
}

const config: ResourceConfig = {
    name: "my-vm",
    location: "eastus",
    tags: { environment: "dev" }
};
```

### Interfaces and Types

- TypeScript **interfaces** are type definitions, describing the **shape** an object must have. Supports c**ompile-time type safety**.

```ts
// Interface for configuration
interace NetworkConfig {
    vnetName: string;
    addressSpace: string[];
    subnets: SubnetConfig[];
}

interface SubnetConfig {
    name: string;
    addressPrefix: string;
}

// Type alias for union types
type Environment = "dev" | "staging" | "prod";
type ResourceSize = "small" | "medium" | "large";

// Generic Types
interface ResourceTags<T = string> {
    [key: string]: T;
}
```

### Classes and Inheritence

- `protected` properties are available within the base class and subclasses.
- The `constructor` method runs when a new object is created.

```ts
// Base class for Azure resources
class AzureResource {
    protected tags: { [key: string]: string };

    constructor(
        protected name: string,
        protected location: string
    ) {
        this.tags = {
            ManagedBy: "CDKTF",
            CreatedAt: new Date().toISOString()
        };
    }

    addTag(key: string, value: string): void {
        this.tags[key] = value;
    }

    getTags(): { [key: string]: string } {
        // Return a shallow copy ({...}) of the tags to prevent external modification
        return { ...this.tags };
    }
}

class VirtualMachine extends AzureResource {
    constructor(
        name: string,
        location: string,
        private size: string
    ) {
        super(name, location); // super is mandatory when subclass has own constructor
        this.addTag("ResourceType", "VirtualMachine");
    }

    getSize(): string {
        return this.size;
    }
}
```

### Functions and Arrow Functions

- With **Arrow functions** (`=>`), the `return` keyword and curly (`{}`) are implicit.

- A **Higher-Order Function (HOF)** is a function that takes 1+ functions as arguments and returns a function as a result.

- The `<T>` (Type) declares a variable type, making the function generic, a placeholder for any type.
    - Example usage: `getFirst<number>([1,2,4]) # returns 1`

```ts
// Traditional Function
function createResourceName(prefix: string, environment: string): string {
    // Template literal for string construction
    return `${prefix}-${environment}`;
}

// Arrow function aka Lambda, a constant variable that holds the function
const createResourceName = (prefix: string, env: string): string =>
    `${prefix}-${env}`;

// Higher-order functions
const applyTags = (
    resources: AzureResource[],       // Takes array of AzureResource(s)
    tagFn: (r: AzureResource) => void // tagFn is the 2nd arg, a function.
): void => {                          // accept a resource r and return nothing (void)
    resources.forEach(tagFn);
};

// Generic functions
function getFirst<T>(items: T[]): T | undefined { // Return value of type T or undefined
    return items[0];
}
```

### Async/Await and Promises

- A **Promise** is an object representing the eventual completion (or failure) of an asynchronous operation and its resulting value.

- `async` / `await` is syntax built on top of **Promises** to make the code look and behave more like synchronous code.

```ts
// Promise-based function
// Return a promise that will resolve with a NetworkConfig object
function fetchConfiguration(): Promise<NetworkConfig> {
    return new Promise((resolve, reject) => {
        // Async operation
        resolve({
            vnetName: "my-vnet",
            addressSpace: ["10.0.0.0/16"],
            subnets: []
        });
    });
} // If the operation failes, reject(error) will be called

// Async/await usage
// An async function automatically returns a Promise
// Execution of initializeStack is paused until we get the config
async function initializeStack(): Promise<void> {
    const config = await fetchConfiguration();
    console.log('Loaded config for ${config.vnetName}');
}
```

### Destructuring and Spread

- The **Rest Operator** (`...rest`) is used to collect all remaining properties into a new object called `rest`.

- **Array Destructuring** allows you to unpack values from arrays into distinct variables based on position.

- The **Spread Operator** (`...`) expands an iterable (object or array) into its individual elements. Opposite of Rest.

```ts
// Object destructuring
const config = { name: "VM-01", location: "eastus", size: "Standard_D2s" };
const { name, location, ...rest } = config;

// Array destructuring
const regions = ["eastus", "westus", "centralus"];
const [primary, secondary, ...others] = regions; // primary gets value at index 0 (eastus)

// Spread operator, for merging copies/merging objects
const baseConfig = { environment: "dev", region: "eastus" };
const fullConfig = { ...baseConfig, tags: { owner: "team" } };

// Function parameter deconstructing
interface VMConfig { name: string; size: string; location: string; }

function createVM(
    // Parameter is an object that MUST conform to VMConfig above
    { name, size, location }: VMConfig
): void {
    // Use the parameters directly
    console.log(`Creating VM ${name} at ${location}`);
}
```

### Modules and Imports

- A `default` **export** is the primary "thing" that the module offers.

```ts
// Named exports
export interface Config { }
export class Resource { }
export const DEFAULT_LOCATION = "eastus";

// Default export
export default class MainStack { }

// Import examples
import { Config, Resource } from "./types"; // Using relative path
import MainStack from "./stacks/main";      // MainStack is a name chosen from importer
import * as Azure from "./azure";           // Import all named exports from ./azure
```

## CDKTF Core Concepts

### CDKTF Hierarchy

```txt
App
 ├── Stack (Environment: Dev)
 │    ├── Resource Group
 │    ├── Virtual Network
 │    └── Storage Account
 └── Stack (Environment: Prod)
      ├── Resource Group
      ├── Virtual Network
      └── Storage Account
```

### App

**App** is the top-level construct that contains all stacks. Typically one App per CDKTF project.

```ts
import { App } from "cdktf"; // App class from cdktf library
import { MainStack } from "./stacks/main-stack";

const app = new App();
new Mainstack(app, "dev"); // app is the scope, and dev is the uniqueId
new MainStack(app, "prod");
app.synth();  // Synth method is used to generate the final terraform JSON config file
```

### Stack

A **Stack** represents a collection of infrastructure that will be deployed together. Each stack generates a separate terraform configuration.

```ts
import { TerraformStack } from "cdktf";
import { Construct } from "constructs";  // CDK building blocks
import { AzurermProvider } from "@cdktf/provider-azurerm/lib/provider"; // Provider class

export class MainStack extends TerraformStack {
    constructor(scope: Construct, id: string) {
        super(scope, id); // Calls constructor of parent class - required for inheritence

        new AzurermProvider(this, "azure", {
            features: {}
        });

        // Resources go here
    }
}
```

### Constructs

**Constructs** are the basic building blocks. Everything in CDKTF is a construct (providers, resources, custom abstractions).

```ts
import { Construct } from "constructs";
import { ResourceGroup } from "@cdktf/provider-azurerm/lib/resource-group";
import { VirtualNetwork } from "@cdktf/provider-azurerm/lib/virtual-network";

export class NetworkConstruct extends Construct {
    public readonly vnet: VirtualNetwork;

    constructor(scope: Construct, id: string, resourceGroup: ResourceGroup) {
        super(scope, id);

        this.vnet = new VirtualNetwork(this, "vnet", {
            name: "main-vnet",
            location: resourceGroup.location,
            resourceGroupName: resourceGroup.name,
            addressSpace: ["10.0.0.0/16"]
        });
    }
}
```

### Providers

Providers are plugins that enable CDKTF to interact with Cloud, SaaS and other APIs.

```ts
import { AzurermProvider } from "@cdktf/provider-azurerm/lib/provider";

new AzurermProvider(this, "azure", {
  features: {
    resourceGroup: {
      preventDeletionIfContainsResources: true
    },
    virtualMachine: {
      deleteOsDiskOnDeletion: true
    }
  },
  // Optional: specify subscription
  subscriptionId: process.env.ARM_SUBSCRIPTION_ID,
});
```

### Resources

Resources are the actual infra you create.

```ts
import { ResourceGroup } from "@cdktf/provider-azurerm/lib/resource-group";
import { StorageAccount } from "@cdktf/provider-azurerm/lib/storage-account";

const rg = new ResourceGroup(this, "rg", {
    name: "my-resource-group",
    location: "eastus",
    tags: {
        environment: "production"
    }
});

const storage = new StorageAccount(this, "storage", {
    name: "mystorageaccount",
    resourceGroupName: rg.name,
    location: rg.location,
    accountTier: "Standard",
    accountReplicationType: "LRS"
});
```

### Data Sources

Data sources allow you to fetch information about existing infra.

```ts
import { DataAzurermResourceGroup } from "@cdktf/provider-azurerm/lib/data-azurerm-resource-group";

const existingRg = new DataAzurermResourceGroup(this, "existing-rg", {
  name: "existing-resource-group"
});

// Use the data source
console.log(existingRg.location);
```

## CDK for Terraform: Azure

### Prerequisites

```bash
brew install node
node --version # v25.1.0
# Install CDKTF CLI
npm install -g cdktf-cli
az login
az account set --subscription "mysub"
```

### Initialization

```bash
# Create new CDKTF project
mkdir my-azure-infrastructure
cd my-azure-infrastructure

# intialize with TS template
cdktf init --template=typescript --local

# Install Azure provider
npm install @cdktf/provider-azurerm
```

### Generate Provider Bindings

- `cdktf.json`

```json
{
  "language": "typescript",
  "app": "npm run --silent compile && node main.js",
  "terraformProviders": [
    "azurerm@~> 3.0"
  ],
  "terraformModules": [],
  "context": {
    "excludeStackIdFromLogicalIds": "true",
    "allowSepCharsInLogicalIds": "true"
  }
}
```

```bash
# Generate bindings
cdktf get
```

### Basic Azure Stack Example

```ts
import { Construct } from "constructs";
import { App, TerraformStack, TerraformOutput } from "cdktf";
import { AzurermProvider } from "@cdktf/provider-azurerm/lib/provider";
import { ResourceGroup } from "@cdktf/provider-azurerm/lib/resource-group";
import { VirtualNetwork } from "@cdktf/provider-azurerm/lib/virtual-network";
import { Subnet } from "@cdktf/provider-azurerm/lib/subnet";

class AzureStack extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);

    // Configure Azure Provider
    new AzurermProvider(this, "azure", {
      features: {}
    });

    // Create Resource Group
    const rg = new ResourceGroup(this, "rg", {
      name: "my-resource-group",
      location: "eastus",
      tags: {
        environment: "dev",
        project: "cdktf-demo"
      }
    });

    // Create Virtual Network
    const vnet = new VirtualNetwork(this, "vnet", {
      name: "my-vnet",
      location: rg.location,
      resourceGroupName: rg.name,
      addressSpace: ["10.0.0.0/16"]
    });

    // Create Subnet
    const subnet = new Subnet(this, "subnet", {
      name: "default",
      resourceGroupName: rg.name,
      virtualNetworkName: vnet.name,
      addressPrefixes: ["10.0.1.0/24"]
    });

    // Output values
    new TerraformOutput(this, "resource-group-name", {
      value: rg.name
    });

    new TerraformOutput(this, "vnet-id", {
      value: vnet.id
    });
  }
}

const app = new App();
new AzureStack(app, "azure-dev");
app.synth();
```

### Deployment Commands

```bash
# Synthesize/Generate Terraform configuration
cdktf synth
# Plan deployment
cdktf plan
# Deploy Infra
cdktf deploy
# Destroy Infra
cdktf destroy
# View Outputs
cdktf output
```

## Project Structure and Organization

```txt
my-azure-infrastructure/
├── src/
│   ├── main.ts                 # Application entry point
│   ├── config/
│   │   ├── environments.ts     # Environment configurations
│   │   ├── constants.ts        # Global constants
│   │   └── types.ts            # Shared type definitions
│   ├── stacks/
│   │   ├── base-stack.ts       # Abstract base stack
│   │   ├── network-stack.ts    # Network infrastructure
│   │   ├── compute-stack.ts    # Compute resources
│   │   └── data-stack.ts       # Data/storage resources
│   ├── constructs/
│   │   ├── atoms/              # Atomic components
│   │   │   ├── resource-group.ts
│   │   │   ├── virtual-network.ts
│   │   │   └── storage-account.ts
│   │   ├── molecules/          # Composed components
│   │   │   ├── network-security.ts
│   │   │   ├── vm-with-disk.ts
│   │   │   └── app-service-plan.ts
│   │   └── organisms/          # Complex components
│   │       ├── aks-cluster.ts
│   │       ├── three-tier-app.ts
│   │       └── hub-spoke-network.ts
│   ├── utils/
│   │   ├── naming.ts           # Resource naming utilities
│   │   ├── tagging.ts          # Tagging utilities
│   │   └── validation.ts       # Validation functions
│   └── interfaces/
│       ├── base-config.ts      # Base configuration interface
│       └── resource-configs.ts # Resource-specific configs
├── test/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── .gitignore
├── cdktf.json
├── package.json
├── tsconfig.json
└── README.md
```

### Configuration Management

- Environments here is a dictionary that implements an `EnvironmentConfig`

```ts
// config/environment.ts
export interface EnvironmentConfig {
  name: string;
  location: string;
  addressSpace: string;
  tags: { [key: string]: string };
  vmSize: string;
  enableMonitoring: boolean;
}

export const environments: { [key: string]: EnvironmentConfig } = {
  dev: {
    name: "dev",
    location: "eastus",
    addressSpace: "10.0.0.0/16",
    tags: {
      environment: "development",
      costCenter: "engineering"
    },
    vmSize: "Standard_B2s",
    enableMonitoring: false
  },
  staging: {
    name: "staging",
    location: "eastus2",
    addressSpace: "10.1.0.0/16",
    tags: {
      environment: "staging",
      costCenter: "engineering"
    },
    vmSize: "Standard_D2s_v3",
    enableMonitoring: true
  },
  prod: {
    name: "prod",
    location: "eastus",
    addressSpace: "10.2.0.0/16",
    tags: {
      environment: "production",
      costCenter: "operations"
    },
    vmSize: "Standard_D4s_v3",
    enableMonitoring: true
  }
};
```

- Use the `constants.ts` as the **centralized, type-safe repository** for fixed configuration values.
    - The keyword `as const` tells the compiler that these are **literal, read-only types**.

```ts
// config/constants.ts
// AZURE_REGIONS.EAST_US for easy reference
export const AZURE_REGIONS = {
  EAST_US: "eastus",
  EAST_US_2: "eastus2",
  WEST_US: "westus",
  WEST_US_2: "westus2",
  CENTRAL_US: "centralus"
} as const; // ensure type safety

export const RESOURCE_PREFIXES = {
  RESOURCE_GROUP: "rg",
  VIRTUAL_NETWORK: "vnet",
  SUBNET: "snet",
  NETWORK_SECURITY_GROUP: "nsg",
  STORAGE_ACCOUNT: "st",
  KEY_VAULT: "kv",
  VIRTUAL_MACHINE: "vm",
  AKS_CLUSTER: "aks"
} as const;

export const DEFAULT_TAGS = {
  ManagedBy: "CDKTF",
  IaC: "Terraform"
} as const;
```

## Atomic Design Principles

### Level 1: Atoms

**Atoms** are the individual Azure resources within minimal abstraction.

```ts
import { Construct } from "constructs";
import { VirtualNetwork } from "@cdktf/provider-azurerm/lib/virtual-network";

export interface VirtualNetworkConfig {
  name: string;
  location: string;
  resourceGroupName: string;
  addressSpace: string[];
  tags?: { [key: string]: string };
}

export class VirtualNetworkAtom extends Construct {
  public readonly vnet: VirtualNetwork;

  constructor(scope: Construct, id: string, config: VirtualNetworkConfig) {
    super(scope, id);

    this.vnet = new VirtualNetwork(this, "vnet", {
      name: config.name,
      location: config.location,
      resourceGroupName: config.resourceGroupName,
      addressSpace: config.addressSpace,
      tags: config.tags
    });
  }
}
```

### Level 2: Molecules

**Molecules** combine atoms into simple, functional groups.

```ts
// constructs/molecules/network-with-subnets.ts
import { Construct } from "constructs";
import { VirtualNetwork } from "@cdktf/provider-azurerm/lib/virtual-network";
import { Subnet } from "@cdktf/provider-azurerm/lib/subnet";

export interface SubnetConfig {
  name: string;
  addressPrefix: string;
  serviceEndpoints?: string[];
}

export interface NetworkWithSubnetsConfig {
  name: string;
  location: string;
  resourceGroupName: string;
  addressSpace: string[];
  subnets: SubnetConfig[];
  tags?: { [key: string]: string };
}

export class NetworkWithSubnetsMolecule extends Construct {
  public readonly vnet: VirtualNetwork;
  public readonly subnets: Map<string, Subnet>;

  constructor(scope: Construct, id: string, config: NetworkWithSubnetsConfig) {
    super(scope, id);

    this.vnet = new VirtualNetwork(this, "vnet", {
      name: config.name,
      location: config.location,
      resourceGroupName: config.resourceGroupName,
      addressSpace: config.addressSpace,
      tags: config.tags
    });

    this.subnets = new Map();

    config.subnets.forEach((subnetConfig, index) => {
      const subnet = new Subnet(this, `subnet-${index}`, {
        name: subnetConfig.name,
        resourceGroupName: config.resourceGroupName,
        virtualNetworkName: this.vnet.name,
        addressPrefixes: [subnetConfig.addressPrefix],
        serviceEndpoints: subnetConfig.serviceEndpoints
      });

      this.subnets.set(subnetConfig.name, subnet);
    });
  }

  getSubnet(name: string): Subnet | undefined {
    return this.subnets.get(name);
  }
}
```

- Another molecule example would be `StorageWithContainersMolecule` class.

### Level 3: Organisms

**Organisms** are complex components composed of molecules and atoms.

```ts
// constructs/organisms/aks-cluster.ts
import { Construct } from "constructs";
import { KubernetesCluster } from "@cdktf/provider-azurerm/lib/kubernetes-cluster";
import { ResourceGroup } from "@cdktf/provider-azurerm/lib/resource-group";
import { VirtualNetwork } from "@cdktf/provider-azurerm/lib/virtual-network";
import { Subnet } from "@cdktf/provider-azurerm/lib/subnet";
import { LogAnalyticsWorkspace } from "@cdktf/provider-azurerm/lib/log-analytics-workspace";

export interface AksClusterConfig {
  name: string;
  resourceGroup: ResourceGroup;
  subnet: Subnet;
  nodeCount: number;
  nodeSize: string;
  enableMonitoring: boolean;
  tags?: { [key: string]: string };
}

export class AksClusterOrganism extends Construct {
  public readonly cluster: KubernetesCluster;
  public readonly logAnalytics?: LogAnalyticsWorkspace;

  constructor(scope: Construct, id: string, config: AksClusterConfig) {
    super(scope, id);

    // Create Log Analytics if monitoring is enabled
    if (config.enableMonitoring) {
      this.logAnalytics = new LogAnalyticsWorkspace(this, "logs", {
        name: `${config.name}-logs`,
        location: config.resourceGroup.location,
        resourceGroupName: config.resourceGroup.name,
        sku: "PerGB2018",
        retentionInDays: 30,
        tags: config.tags
      });
    }

    this.cluster = new KubernetesCluster(this, "aks", {
      name: config.name,
      location: config.resourceGroup.location,
      resourceGroupName: config.resourceGroup.name,
      dnsPrefix: config.name,
      
      defaultNodePool: {
        name: "default",
        nodeCount: config.nodeCount,
        vmSize: config.nodeSize,
        vnetSubnetId: config.subnet.id,
        enableAutoScaling: true,
        minCount: 1,
        maxCount: config.nodeCount * 2
      },

      identity: {
        type: "SystemAssigned"
      },

      networkProfile: {
        networkPlugin: "azure",
        networkPolicy: "calico",
        loadBalancerSku: "standard"
      },

      omsAgent: config.enableMonitoring && this.logAnalytics ? {
        logAnalyticsWorkspaceId: this.logAnalytics.id
      } : undefined,

      tags: config.tags
    });
  }
}
```

### Level 4: Templates

**Templates** combine organisms, molecules, and atoms into complete deployment patterns.

```ts
// constructs/templates/web-application-template.ts
import { Construct } from "constructs";
import { ResourceGroup } from "@cdktf/provider-azurerm/lib/resource-group";
import { NetworkWithSubnetsMolecule } from "../molecules/network-with-subnets";
import { ThreeTierAppOrganism } from "../organisms/three-tier-app";
import { StorageWithContainersMolecule } from "../molecules/storage-with-containers";

export interface WebApplicationTemplateConfig {
  name: string;
  location: string;
  environment: string;
  tags?: { [key: string]: string };
}

export class WebApplicationTemplate extends Construct {
  public readonly resourceGroup: ResourceGroup;
  public readonly network: NetworkWithSubnetsMolecule;
  public readonly application: ThreeTierAppOrganism;
  public readonly storage: StorageWithContainersMolecule;

  constructor(scope: Construct, id: string, config: WebApplicationTemplateConfig) {
    super(scope, id);

    // Resource Group
    this.resourceGroup = new ResourceGroup(this, "rg", {
      name: `${config.name}-rg`,
      location: config.location,
      tags: { ...config.tags, environment: config.environment }
    });

    // Network
    this.network = new NetworkWithSubnetsMolecule(this, "network", {
      name: `${config.name}-vnet`,
      location: this.resourceGroup.location,
      resourceGroupName: this.resourceGroup.name,
      addressSpace: ["10.0.0.0/16"],
      subnets: [
        {
          name: "webapp-subnet",
          addressPrefix: "10.0.1.0/24",
          serviceEndpoints: ["Microsoft.Web", "Microsoft.Sql"]
        },
        {
          name: "data-subnet",
          addressPrefix: "10.0.2.0/24",
          serviceEndpoints: ["Microsoft.Sql", "Microsoft.Storage"]
        }
      ],
      tags: config.tags
    });

    // Storage
    this.storage = new StorageWithContainersMolecule(this, "storage", {
      name: `${config.name.replace(/-/g, "")}st`,
      resourceGroupName: this.resourceGroup.name,
      location: this.resourceGroup.location,
      accountTier: "Standard",
      accountReplicationType: "LRS",
      containers: [
        { name: "uploads", containerAccessType: "private" },
        { name: "logs", containerAccessType: "private" }
      ],
      tags: config.tags
    });

    // Application
    this.application = new ThreeTierAppOrganism(this, "app", {
      name: `${config.name}-app`,
      resourceGroup: this.resourceGroup,
      appServiceSku: config.environment === "prod" ? "P1v3" : "B1",
      databaseSku: config.environment === "prod" ? "S1" : "Basic",
      sqlAdminUsername: "sqladmin",
      sqlAdminother: process.env.SQL_ADMIN_OTHER || "somephrase",
      tags: config.tags
    });
  }
}
```

### Level 5: Stacks and Environments

Create an abstract base **stack** that all **environment stacks** inherit from.

```ts
// stacks/base-stack.ts
import { Construct } from "constructs";
import { TerraformStack, TerraformOutput } from "cdktf";
import { AzurermProvider } from "@cdktf/provider-azurerm/lib/provider";

export interface BaseStackConfig {
  environment: string;
  location: string;
  subscriptionId?: string;
  tags?: { [key: string]: string };
}

export abstract class BaseStack extends TerraformStack {
  protected readonly environment: string;
  protected readonly location: string;
  protected readonly tags: { [key: string]: string };

  constructor(scope: Construct, id: string, config: BaseStackConfig) {
    super(scope, id);

    this.environment = config.environment;
    this.location = config.location;
    this.tags = {
      Environment: config.environment,
      ManagedBy: "CDKTF",
      Terraform: "true",
      ...config.tags
    };

    // Configure Azure Provider
    new AzurermProvider(this, "azure", {
      features: {
        resourceGroup: {
          preventDeletionIfContainsResources: true
        },
        keyVault: {
          purgeProtectionOnDelete: true,
          recoverSoftDeletedKeyVaults: true
        }
      },
      subscriptionId: config.subscriptionId
    });

    // Setup common outputs
    this.setupOutputs();
  }

  protected abstract setupOutputs(): void;

  protected addOutput(name: string, value: string, sensitive: boolean = false): void {
    new TerraformOutput(this, name, {
      value,
      sensitive
    });
  }
}
```

#### Environment Specific (Network) Stack

- This would be the stacks/network-stack.ts

```ts
import { Construct } from "constructs";
import { BaseStack, BaseStackConfig } from "./base-stack";
import { ResourceGroup } from "@cdktf/provider-azurerm/lib/resource-group";
import { NetworkWithSubnetsMolecule } from "../constructs/molecules/network-with-subnets";

export interface NetworkStackConfig extends BaseStackConfig {
  addressSpace: string;
}

export class NetworkStack extends BaseStack {
  public readonly resourceGroup: ResourceGroup;
  public readonly network: NetworkWithSubnetsMolecule;

  constructor(scope: Construct, id: string, config: NetworkStackConfig) {
    super(scope, id, config);

    // Resource Group
    this.resourceGroup = new ResourceGroup(this, "network-rg", {
      name: `network-${this.environment}-rg`,
      location: this.location,
      tags: this.tags
    });

    // Virtual Network with Subnets
    this.network = new NetworkWithSubnetsMolecule(this, "network", {
      name: `vnet-${this.environment}`,
      location: this.resourceGroup.location,
      resourceGroupName: this.resourceGroup.name,
      addressSpace: [config.addressSpace],
      subnets: [
        {
          name: "frontend",
          addressPrefix: this.getSubnetPrefix(config.addressSpace, 1),
          serviceEndpoints: ["Microsoft.Web"]
        },
        {
          name: "backend",
          addressPrefix: this.getSubnetPrefix(config.addressSpace, 2),
          serviceEndpoints: ["Microsoft.Web", "Microsoft.Sql"]
        },
        {
          name: "data",
          addressPrefix: this.getSubnetPrefix(config.addressSpace, 3),
          serviceEndpoints: ["Microsoft.Sql", "Microsoft.Storage"]
        }
      ],
      tags: this.tags
    });
  }

  protected setupOutputs(): void {
    this.addOutput("network-resource-group-name", this.resourceGroup.name);
    this.addOutput("vnet-id", this.network.vnet.id);
    this.addOutput("vnet-name", this.network.vnet.name);
  }

  private getSubnetPrefix(addressSpace: string, subnetNumber: number): string {
    const [network, mask] = addressSpace.split("/");
    const octets = network.split(".");
    octets[2] = subnetNumber.toString();
    return `${octets.join(".")}/24`;
  }
}
```

### Stack Dependencies

- Using `TerraformRemoteState` when stacks depend on each other.

```ts
/ Reference network stack outputs
    const networkState = new DataTerraformRemoteState(this, "network", {
      backend: "azurerm",
      config: {
        resourceGroupName: "terraform-state-rg",
        storageAccountName: "tfstatestorage",
        containerName: "tfstate",
        key: `network-${environment}.tfstate`
      }
    });
```

## Best Practices

### Naming Conventions

Use a **naming utility** to create and validate resource names.

```ts
import { RESOURCE_PREFIXES } from "../config/constants";

export interface ResourceNamingConfig {
  resourceType: keyof typeof RESOURCE_PREFIXES;
  name: string;
  environment: string;
  region?: string;
  instance?: number;
}

export class NamingService {
  private static readonly MAX_LENGTH: { [key: string]: number } = {
    storageAccount: 24,
    keyVault: 24,
    containerRegistry: 50
  };

  static generateResourceName(config: ResourceNamingConfig): string {
    const parts = [
      RESOURCE_PREFIXES[config.resourceType],
      config.name,
      config.environment
    ];

    if (config.region) {
      parts.push(this.abbreviateRegion(config.region));
    }

    if (config.instance !== undefined) {
      parts.push(config.instance.toString().padStart(2, "0"));
    }

    let name = parts.join("-");

    // Handle resources with special naming requirements
    if (config.resourceType === "STORAGE_ACCOUNT") {
      name = name.replace(/-/g, "").toLowerCase();
      const maxLen = this.MAX_LENGTH.storageAccount;
      if (name.length > maxLen) {
        name = name.substring(0, maxLen);
      }
    }

    return name;
  }

  private static abbreviateRegion(region: string): string {
    const abbreviations: { [key: string]: string } = {
      eastus: "eus",
      eastus2: "eus2",
      westus: "wus",
      westus2: "wus2",
      centralus: "cus",
      northeurope: "neu",
      westeurope: "weu"
    };

    return abbreviations[region] || region;
  }

  static validateResourceName(name: string, resourceType: string): boolean {
    const maxLength = this.MAX_LENGTH[resourceType];
    if (maxLength && name.length > maxLength) {
      return false;
    }

    // Add more validation rules as needed
    return true;
  }
}
```

- Usage of naming:

```ts
const storageAccountName = NamingService.generateResourceName({
  resourceType: "STORAGE_ACCOUNT",
  name: "data",
  environment: "prod",
  region: "eastus"
});
// Result: "stdataprodeus"
```

### Resource Lifecycle Management

```ts
import { Construct } from "constructs";
import { TerraformResource } from "cdktf";

export interface LifecycleConfig {
  createBeforeDestroy?: boolean;
  preventDestroy?: boolean;
  ignoreChanges?: string[];
}

export function applyLifecycle(
  resource: TerraformResource,
  config: LifecycleConfig
): void {
  resource.addOverride("lifecycle", config);
}

// Usage
const rg = new ResourceGroup(this, "rg", {
  name: "my-rg",
  location: "eastus"
});

applyLifecycle(rg, {
  preventDestroy: true,
  ignoreChanges: ["tags"]
});
```

### Cost Optimzation

```ts
export interface CostOptimizationConfig {
  environment: string;
  enableAutoShutdown?: boolean;
  shutdownTime?: string;
  enableAutoscaling?: boolean;
}

export class CostOptimizer {
  static getOptimalVmSize(environment: string, workload: string): string {
    const sizing: { [key: string]: { [key: string]: string } } = {
      dev: {
        web: "Standard_B2s",
        api: "Standard_B2ms",
        database: "Standard_B2s"
      },
      prod: {
        web: "Standard_D4s_v3",
        api: "Standard_D4s_v3",
        database: "Standard_E4s_v3"
      }
    };

    return sizing[environment]?.[workload] || "Standard_B2s";
  }

  static getOptimalStorageTier(
    accessFrequency: "hot" | "cool" | "archive"
  ): string {
    return accessFrequency === "hot" ? "Standard" : "Standard";
  }

  static shouldEnableReservedInstances(environment: string): boolean {
    return environment === "prod";
  }
}
```

## Alternative Patterns

1. **Factory Pattern**: A function or class that encapsulates the logic for creating different objects based on input parameters, hiding complexity from the caller.
2. **Builder Pattern**: A fluent interface that constructs complex objects step-by-step via chained method calls.
3. **Strategy Pattern**: Define family of interchangeable algorithms to be set at runtime, allowing variation between clients.
4. **Mixin Pattern**: A way to add reusable functionality to classes by mixing in methods from other classes.
5. **Dependcy Injection**: Dependencies are provided from the outside, making the code more testable and loosely coupled.

## Testing Strategies

1. Unit Testing (Jest)
2. Integration Testing

## CICD

`.github/workflows/terraform.yaml`

```yaml
name: Terraform CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
  ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run linter
        run: npm run lint
      
      - name: Run unit tests
        run: npm test
      
      - name: Build project
        run: npm run build

  plan:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    strategy:
      matrix:
        environment: [dev, staging]
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: CDKTF Synth
        run: npx cdktf synth
      
      - name: Terraform Plan
        run: |
          cd cdktf.out/stacks/${{ matrix.environment }}
          terraform init
          terraform plan -out=tfplan
      
      - name: Upload plan
        uses: actions/upload-artifact@v3
        with:
          name: tfplan-${{ matrix.environment }}
          path: cdktf.out/stacks/${{ matrix.environment }}/tfplan

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    strategy:
      matrix:
        environment: [dev, staging, prod]
    environment:
      name: ${{ matrix.environment }}
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: CDKTF Deploy
        run: npx cdktf deploy ${{ matrix.environment }} --auto-approve
      
      - name: Run smoke tests
        run: npm run test:smoke -- --environment ${{ matrix.environment }}
```

## Troubleshooting

1. **Resource Naming Conflicts**: Import existing resource or use Data source.
2. **State Lock Issue**: TF Force unlock, or add a lock-timeout.
3. **Dependency Issues**: Associate resources separately.
4. **Type Errors with Providers**: Regen provider bindings or specify particular version.
5. **Memory Issues**: Increate Node.js heap size.
6. **Terraform Drift**: Refresh state or Import the resource, OR taint/reapply resource.

```bash
# List all stacks
cdktf list

# Show stack outputs
cdktf output your-stack

# Diff changes
cdktf diff your-stack

# Validate configuration
cd cdktf.out/stacks/your-stack
terraform validate
```