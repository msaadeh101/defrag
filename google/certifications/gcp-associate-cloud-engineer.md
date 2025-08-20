# GCP ACE

## Basics

- [Github Study Guide](https://github.com/ullly/associate-cloud-engineer)

- Use the Pricing Calculator to estimate cloud costs and use similar instance sizes or best guesses.

- Google cloud resources are considered either `Global`, `Regional`, or `Zonal`. For example, images are global, but disks can be regional or zonal.
  - By adding a resource location constraint to your organizational policy, you may impact certain services.

### Main services

- Compute Services
  - Compute Engine
  - `App Engine`: Fully managed PaaS for web apps, supports multi-env, serverless, multi-language.
  - Cloud Functions: Event driven serverless compute
  - `Cloud Run`: Fully managed, **containerized** apps for stateless or auto-scaling apps.
- Storage and DB
  - Cloud Storage
  - Persistent Disks
  - Cloud SQL
  - Filestore/Datastore
  - `Cloud Bigtable`: Storing real-time NoSQL data or time-series data
- Networking
  - VPC
  - Cloud Load Balancing
  - Cloud NAT - Outbound 
  - Cloud DNS
  - Interconnect VPN
- IAM
  - IAM
  - Service Accounts
  - Cloud Identity
- Ops and Monitoring
  - Pub/Sub: Messaging/event ingestion, decoupling services. Has push and pull subscriptions.
  - Cloud Logging: Fully managed service that you can store/search/analayze/monitor/alert on logging data.
  - Cloud Monitoring
  - Error Reporting/Debugger/Trace
  - Alerting Policies: Conditions, Triggers, Notifications, Documentation, Auto-closing.
  - Cloud Profiler: Displays CPU time, Heap, Contention, Threads for Compute Engine, GKE, App Engine, etc.
- Deployment and DevOps
  - Cloud SDK (gcloud)
  - Cloud Build
  - Deployment Manager (Will be deprecated in 2025), use Infra manager, Type Provider (3rd parties)
  - Container/Artifact Registry
- Other
  - `BigQuery`: Fully managed Data warehuse (structured/semi-structured), includes LookerStudio (data analaysis/visualization)
    - INFORMATION_SCHEMA: views that are read-only (default queries/views)
  - Dataflow: Fully managed Data processing ETL engine
  - Billing Accounts
  - Cloud KMS (Manage encryption keys)
  - `Cloud Scheduler`: Fully managed cron job service for task execution. Can trigger other GCP services

### Billing

- A **Cloud Billing Account** (Cloud level resource, defines who pays for GCP resources) is connected to your `Google Payments Profile` (Google level resource, includes payment info). The billing account is direclty tied to your organization or root node of the google resources..

- Two Types of **Cloud Billing Accounts**:
  - `Self-serve` (Online):
    - Billable status: Free trial or Paid
    - Payment: Debit or Credit
  - `Invoiced` (Offline):
    - Billable status: Paid account
    - Payment: Can be check or wire transfer

- Subaccounts are intended for resellers for the purpose of chargebacks.

### Constraints
- A constraint is a type of restriction against GCP services or a LIST of GCP services.
- Values can be given a prefix like `prefix:value`
- Example: `constraints.compute.trustedImageProjects` takes a list of project ids in form of `projects/PROJECT_ID`
- Boolean constraints like: `constraints/compute.disableSerialPortAccess`
- Managed constraints have been built on custom organiztion policy platform. like: `iam.managed.disableServiceAccountCreation`
- Use parameters:
```yaml
name: organizations/1234567890123/policies/essentialcontacts.managed.allowedContactDomains
spec:
   rules:
     - enforce: true
       parameters:
          allowedDomains:
               - @example.com
               - @altostrat.com
```
- Possible to use a `dryRunSpec` with rules and values.
  - To update an existing policy in dry-run mode, use `--update-mask`
- `gcloud org-policies describe gcp.restrictServiceUsage --project=PROJECT`
- Delete a constraint: `gcloud org-policies delete CONSTRAINT_NAME --RESOURCE_TYPE=RESOURCE_ID`

### Tags vs Labels
- `Tags` have a max char limit of 256 and can be supported by IAM Policy.
- `Labels` are metadate for each resource, with a 63 char maximum. 

- You MUST delete existing tag attachments called `tag bindings` (tag hold) before deleting a tag itself.

In a policy:
```yaml
name: RESOURCE_TYPE/RESOURCE_ID/policies/gcp.resourceLocations
spec:
  rules:
  # As there is no condition specified, this allowedValue is enforced unconditionally.
  - values:
      allowedValues:
      - us-east1-locations
  # This condition applies to the values block.
  - condition:
      expression: "resource.matchTag('ORGANIZATION_ID/location', 'us-west1')"
    values:
      allowedValues:
      - us-west1-locations
```
- Then run `gcloud org-policies set-policy POLICY_PATH`
- For a boolean policy example: expression: `"resource.matchTag(\"ORGANIZATION_ID/disableSerialAccess\", \"yes\")"`
- You can restrict access to certain services in projects by adding a tag, i.e. `sqladmin=enabled` will allow `sqladmin.googleapis.com` on projects.

### Working with Organizational Policies
- Policy Details: List constraints, boolean constrains, custom constraints, values can be `is`, `under`, `in`,
- Enforcement
- Dry-run tab, (Manage/Edit dry run policy)
- Add a rule
  - Policy Values
- Override Parent's policy


## Google Cloud APIs

- Each Cloud API runs one or more subdomains of `googleapis.com`, for example, `pubsub.googleapis.com`.
- Two kinds of Google Cloud APIs:
    - Resource-based: use the project associated with resources being accessed for billing and quota.
    - Client-based: use the project associated with client accessing the resources for billing and quota.
- All APIs support HTTP, and most support gRPC for enhanced usability and performance.
- Google client libraries handle in-transit TLS encryption.
- Cloud APIs are shared among all developers, and thus there are *rate limits and quotas on usage*.
- Monitor your Cloud APIs usage with the `API Dashboard` in the console.

## Setting Up Cloud Environment

- All resources except for the highest resource in a hierarchy have exactly one parent.
- Both IAM and organizational policies are inherited through the hierarchy: **Organization -> Folders -> Projects -> Resources**
    - Some features of Resource Manager are unusable without an `organization`.
    - Organizations are necessary so that the resource owner is not a user.
    - Organization Admins have central control of all resources

- Organization resource json:
```json
{
  "creationTime": "2020-01-07T21:59:43.314Z",
  "displayName": "my-organization",
  "lifecycleState": "ACTIVE",
  "name": "organizations/34739118321",
  "owner": {
    "directoryCustomerId": "C012ba234"
  }
}
```
- A Google Workspace or Cloud Identity account can have exactly one organization resource provisioned with it.
- The **Google Workspace super admin** is the individual responsible for domain ownership verification and the contact in cases of recovery. 
- `Folders` can be seen as a sub-organizational grouping representing boundaries between projects.
- Folder resource json:
```json
{
  "createTime": "2030-01-07T21:59:43.314Z",
  "displayName": "Engineering",
  "lifecycleState": "ACTIVE",
  "name": "folders/634792535758",
  "parent": "organizations/34739118321"
}
```
- The `project` contains a Unique ID (`projectId`), and unique resource Number (`projectNumber`), with a mutable display name.
- Project name must be between 4-30 chars.
- After you create a project, the `Owner` role is assigned to you
- Project resource json:
```json
{
  "createTime": "2020-01-07T21:59:43.314Z",
  "lifecycleState": "ACTIVE",
  "name": "my-project",
  "parent": {
    "id": "634792535758",
    "type": "folder"
  },
  "projectId": "my-project",
  "labels": {
     "my-label": "prod"
  },
  "projectNumber": "464036093014"
}
```
- You can set IAM policies at the organization, folder, project levels, and sometimes the resource level.
    - The effective policy for a resource is the union of the policy set on the resource and the policy inherited from its ancestors.

- To create an Organization, you need either a:
    1) Google Workspace 
    or 
    2) Cloud Identity account associated with a domain.
- Each Google Workspace or Cloud Identity account is associated with exactly ONE organization.
- Cloud Identity comes in Free and Premium.

- Related CLI commands need (`resourcemanager.organizations.get` permission):

```bash
# Check if a project is associated with an org
gcloud projects describe PROJECT_ID # output should include parent resource

# Check organizations
gcloud organizations list

# List projects within an organization
gcloud projects list --filter 'parent.id=[ORGANIZATION_ID] AND \
    parent.type=organization'
```
- When an organization is created, all users in domain are granted `roles/resourcemanager.projectCreator` and `roles/billing.creator` IAM roles at the org level.
    - The `Organization Administrator` can decide and change the default permissions.

### Verify domain
- Verify your domain with TXT record.
    - Go to admin.google.com and choose the correct admin account.
    - Click Verify Domain in the setup tool at the top.
    - In a new tab, go to your DNS registrar and paste:
        - The verification code
        - Create the TXT record (Name/Host/Alias, 1 Hour TTL)
        - May need to wait 1 hour for some registrars.

### Understanding Roles
- Three role types in IAM: Basic roles, Predefined roles, Custom roles.
- **Role Components**: Title, Name, ID, Description, `Stage`, Permissions
  - `Stage`: The stage of the custom role in launch lifecycle: `ALPHA` (still being tested), `BETA` (limited testing), `GA`(widely tested). These stages are informational
  

- Three basic roles: 
    - `roles/viewer`: read-only actions
    - `roles/editor`: all viewer permissions, plus modify state of existing resources.
    - `roles/owner`: All editor permissions, plus manage roles and permissions for project/resources/billing.

- In IAM, you can view by *principals* or by *roles*.
- Easily search roles with the [Roles/Permissions Index](https://cloud.google.com/iam/docs/roles-permissions)
- Built-in roles in the `roles/*` come with different built-in permissions for the job duty.

#### Common Roles
|Role Name|Description|Lowest-level resource to grant|
|--------------|-------------------|----------------------------|
|`roles/browser`| read access to browse org/folder/proj hierarchy | Project|
|`roles/iam.roleViewer`| read access to all custom roles in the project | Project|
|`roles/iam.securityReviewer`| List all resources AND allow policies | Project|
|`roles.logging.privateLogViewer`|Logs veiwer role plus read-only to private logs entries|Project|
|`roles/bigquery.dataViewer`|read Big Query data/metadata and list datasets|Table/View|
|`roles/storage.objectCreator`|allow write objects (not view/delete/overwrite)|Bucket|
|`roles/compute.admin`|Full control of GCE resources|disk/image/instance/template/node group|
|`roles/billing.projectManager`| Access to assign project billing account or disable|Project|
|`roles/monitoring.viewer`|read-only access on all monitoring data/configurations|Project|

### Transfer Services
- `Storage Transfer Service` , recommended for over 1TB of data, allows you to transfer data quickly from on-prem/third-party to Google with: Data encryption/validation, incremental transfer, metadata preservation.
- `Transfer Appliance` is a high-capacity storage device for transferring physical data. Suitable for if it would take over a week for network transfer.
- `BigQuery Data Transfer Service`: automate movement into BigQuery ina  scheduled/managed basis using the console, gcloud, and BigQuery Transfer Service API.


### Migrate projects
- From the console:
    - `IAM & Admin` -> `Manage Resources`
    - Click `No organiztion` from dropdown.
    - Select the Warning icon projects and click `Migrate`
    - Navigate back to IAM & Admin and assign IAM permissions for your org.
- **Note** project migration is IRREVERSIBLE.
- When you create a request for migration, the project/billing owners receive an email valid for 30 days.

- The `roles/project.mover` is needed to import and change IAM permissions on projects.
- IAM policies are moved with the migrated project.

### Managing Folders
- Related roles include: `roles/resourcemanager.folderAdmin`, `folderIamAdmin`, `folderCreator`, `folderMover`...
- You can nest up to 10 folders deep.
- Folder display names must be unique within the same level.

- Related gcloud commands:
```bash
# Grant folder admin role
gcloud organizations add-iam-policy-binding ORGANIZATION_ID \
    --member=user:USER_ID \
    --role=roles/resourcemanager.folderAdmin

# create a folder within an org
gcloud resource-manager folders create --display-name --organization=
# create a folder within another folder
gcloud resource-manager folders create --display-name --folder=

# Move a project
gcloud beta projects move PROJECT_ID --DESTINATION_TYPE (organization/folder) DESTINATION_ID
```

### Managing local gcloud Environment

- Use gcloud to create a configuration for each project you need to manage. 
  - `gcloud config configurations create PROJECT_A`
  - `gcloud config set project PROJECT_ID_A`
  - Set some custom config: `gcloud config set compute/region us-central1`
  - `gcloud auth login`
  - Repeat for other projects
- Switch between configurations/activate them.
  - `gcloud config configurations activate PROJECT_A`
  - Configs that may differ: proj, account, billing, service account, region

### Managing Organizations

- Use **Multiple Organizations** to separate users in Google Workspace/Cloud identities
  - No single user will have central visibility.
  - Sub-organization policies need to be manually replicated.
  - Moving folders from one org to another is NOT supported.
  - Every org requires a Google Workspace account.
  - To maintain central visibility, you need to have a PRIMARY Organization.
    - Choose an organization administrator for the organization resource.
    - Remove Project Creator role to ensure resources are not created in other org resources.
    - Grant folder administrator roles (folder editor/viewer): `gcloud resource-manager folders add-iam-policy-binding...` OR you can run `gcloud resource-manager folders set-iam-policy FOLDER_ID POLICY_FILE`

### Setting an organizational policy
1) Go to `Organizational polices`
2) Choose your project
3) Click `Google Cloud Platform - Define Resource Locations`, Click `Edit`.
4) Under `Applies to`, select `Customize`
5) Under `Policy Values`, select `Custom`
6) Under `Policy Type`, select `Allow`
7) In Policy value, `in:asia-locations`
  - in:asia-locations is a vlue group that includes every location in a region.
8) Click `Save`
- Will show up as a `contstraints/gcp.resourceLocations` if try to create outside value group.


- IAM focuses on WHO, and lets admins authorize, but Organization Policy Service focuses on what, and let's admins set restrictions to resources.
- Use the `Policy intelligence tools` (suite of tools to manage) to test and anlyze custom organization policies.
- An existing resource state will cause a policy violation, but not stop the original service behavior.
- `Tags` provide a way to enforce constraints conditionally on a specific tag.

- Example
```yaml
name: projects/841166443394/policies/gcp.resourceLocations
spec:
  etag: BwW5P5cEOGs= # unique string to manage concurrecny when updating policies
  inheritFromParent: true # this policy inherits constraints from a higher level resource
  rules: # condition based allow
  - condition:
      expression: resource.matchTagId("tagKeys/1111", "tagValues/2222") #  resource with tagKey:tagValue 1111:2222
    values:
      allowedValues:
      - in:us-east1-locations # can only be created in us-east1 locations
  - condition: # tag based allow
      expression: resource.matchTag("123/env", "prod") # under namespace 123, the user defined tag env=prod
    values:
      allowedValues:
      - in:us-west1-locations
  - values:
      deniedValues:
      - in:asia-south1-locations
  updateTime: '2021-01-19T12:00:51.095Z'
```

- Get effective/inherited policies: `gcloud org-policies describe constraints/compute.disableSerialPortAccess --effective --organization=ORGANIZATION_ID` or `constraints/compute.requireOsLogin` for example.

### Restricting identities by domain
- When domain restricted sharing is active, only principals that belong to the allowed domains/orgs can be granted IAM roles.
- Three types of organization policies that you can use to restrict identites by domain:
1) `iam.managed.allowedPolicyMembers` managed constraint.
```yaml
name: organizations/ORG_ID/policies/CONSTRAINT_NAME
spec:
rules:
 - enforce: true
 - parameters:
   allowedMemberSubjects:
     - ALLOWED_MEMBER_1
     - ALLOWED_MEMBER_2
   allowedPrincipalSets:
     - ALLOWED_PRINCIPAL_SET_1
     - ALLOWED_PRINCIPAL_SET_2
```
2) Custom organization policies referencing the `iam.googleapis.com/AllowPolicy` resource.
```yaml
name: organizations/ORG_ID/customConstraints/custom.allowInternalIdentitiesOnly
methodTypes:
  - CREATE
  - UPDATE
condition:
  "resource.bindings.all(
    binding,
    binding.members.all(member,
      MemberInPrincipalSet(member, ['//cloudresourcemanager.googleapis.com/organizations/ORG_ID'])
    ) # memberInPrincipalSet CEL function to restrict role grants
  )"
actionType: ALLOW
displayName: Only allow organization members to be granted roles
```
3) `iam.allowedPolicyMemberDomains` predefined constraint (**enforced by default**).
```yaml
name: organizations/ORGANIZATION_ID/policies/iam.allowedPolicyMemberDomains
spec:
  rules:
  - condition: # This condition applies to the values block.
      expression: "resource.matchTag('ORGANIZATION_ID/environment', 'dev')"
    values:
      allowedValues:
      - PRINCIPAL_SET
  - values:
      allowedValues:
      - PRINCIPAL_SET
```

- Configure exceptions, especially by certain accounts  like serviceAccounts: BigQuery, Firebase API, Pub/Sub.

### Service Accounts

- Prevent the Owner/Editor role from being granted to default service accounts, since these are `Priveledged Roles`. Use `iam.managed.preventPrivilegedBasicRolesForDefaultServiceAccounts`
- `iam.automaticIamRGrantsForDefaultServiceAccounts` bool constraint is automatically enforced.

- Enforcing a boolean account constraint:
1) Go to `Organization policies` page
2) Select org from project picker
3) Click one of the service account usage bool constraints.
4) Click `Manage Policy`.
5) Under `Applies to`, select `Override parent's policy`.
6) Click `Add a rule`.
7) Under `Enforcement`, select `On`.
8) To enforce, click `Set policy`.

- You can create an OAuth 2.0 access token, default max life is 1 hr, but can go up to 12 hours if `constraints/iam.allowServiceAccountCredentialLifetimeExtension`

- By Default, service account keys never expire, but you can set `constraints/iam.serviceAccountKeyExpiryHours` to specify when a newly created key is valid. (between 1h - 90 days)

- You can specify allowed external identity providers if you use workload identity federation. i.e. `constraints/iam.workloadIdentityPoolsAwsAccounts`.

- You can automatically disable **exposed** access keys with `iam.serviceAccountKeyExposureResponse`, it MAY detect a key in a public repository.
  - It accepts `ALLOW` values only, no DENY values: `DISABLE_KEY`, `WAIT_FOR_ABUSE`

### Permissions (General)

- To list all resource nodes, make sure that:
1) Grant `list` and `get` permissions for Organizations, Folders and Projects.
2) Specify the parent resource in the filter string
3) Run projects.list() method with this service account for each type of resource

- Reduce latency using filter for app scripts, which show up as a GCP project: `gcloud projects list --filter="NOT parent.id: 'APPS_SCRIPT_FOLDER_ID' "--page-size='30'`

- To manage access to a project, folder, org: need projects/folders/organizations get and set IAM Policy: `resourcemanager.projects.getIamPolicy`

- Remove a role: `gcloud RESOURCE_TYPE remove-iam-policy-binding RESOURCE_ID --member=PRINCIPAL --role=ROLE_NAME`

- Role Types:
  - Predefined roles: `roles/SERVICE.IDENTIFIER`
  - Project level custom roles: `projects/PROJECT_ID/roles/IDENTIFIER`
  - Org level custom roles: `organizations/ORG_ID/roles/IDENTIFIER`

- To edit an inherited role, you need to go to the resource where access was granted.

### Locations

- `multi-region`: includes more than one region. i.e. `us`, `asia`, `europe`, `global`
- `region`: geographically isolated from eachother. i.e. `us-west1`
- `Zone`: independent failure domain within a region. i.e. `us-east1-b`, `asia-northeast1-a`

```yaml
name: organizations/01234567890/policies/gcp.resourceLocations
spec:
  inheritFromParent: true
  rules:
  - values:
      deniedValues:
      - in:us-west1
```

- Value Groups are collectins of groups and locations curated by Google to define resource locations. Examples:
- Value Group: `Low carbon Europe`, Locations: `in:europe-low-carbon-locations`, Groups: `europe-north1/southwest1, etc-locations`,

### Licenses

- Google Workspace:
  - Business Starter/Standard/Plus (capped at 300 users)
  - Enterprise Standard/Plus/Essentials

- Cloud Identity (CI)
  - Cloud Identity Free
  - Cloud Identity Premium



### Manage Users/Groups/SSO in Cloud Identity

- `Cloud Identity` is an IDaaS and Enterprise Mobility management EMM product, provides identity service and endpoint administration available in Workspace as its own product.
  - Comes in Free edition and Premium edition for enterprise security and device management services.
- Administrator Controls include:
  - Device Management
  - Directory Management
  - Security
  - SSO and automated user provisioning
  - Reporting

- You can choose how your team is signed up: `Domain verified` or `Email verified`.

#### Set up SAML SSO
- Requirements from IdP: Sign-in page url, sign-out page URL, change password URL, certificate
1) Sign in with Administrator account/security settings admin priveleges
2) go to `Menu` -> `Security` -> `Authentication` -> `SSO with third party IdP`
3) Under `Third-party SSO profiles`, click `Add SAML profile`
  - Fill out the requirements
4) Click `Save`
5) In `SP Details`, copy and save `Entity ID` and `ACS URL`
6) Click `Generate certificate` under `SP Certificate`
7) Click `Save`

#### Add an account for a user
1) Go to `Google Admin Console` (need to be administrator)
2) Go to `Menu` -> `Directory` -> `Users`
3) `Add new user`
  - Include First/Last name
  - Email/password/photo

#### Create a group
1) Go to `Google Admin Console` (need to be a groups administrator)
2) Go to `Menu` -> `Directory` -> `Groups`
3) `Create group`:
  - Add group name (73 chars), email, owners
  - Click `Next`
4) Check `Security` box (optional - makes it a security group)
- Optionally, make an existing group a security group by going to `Group Information` -> `Labels` -> `Security` box checked - `Save`.
5) Choose Access type: `Public`, `Team`, `Announcement Only`, `Restricted`
6) Optionally, click customization options (Access settings, join settings, outside org)
7) Optionally, select `Restrict Membership`.
8) `Create group`.
- It can take up to 24 hours for a new group to appear in the groups directory.

#### Add members to group
1) Go to `Google Admin Console` (need to be administrator)
2) Go to `Menu` -> `Directory` -> `Users`
3) Find the uer and at top, click `Groups`
4) `Add user to groups`.
  - Find the group name
5) click `Add`.
- Optionally change the member role, click the arrow under `Role`
6) Click `Save`.

**Bulk upload** with a CSV is possible under `Groups` -> `Members` -> `Bulk upload members`.
  - Header: Group Email [Required], Member Email, Member Type, Member Role
  - Entry: yourgroup@email.com, membername@email.com, USER, MEMBER

**Groups for Business** license is required for Inviting or Responding to Google Group Invites.

#### Create a Dynamic Group

- You can populate groups based on department or other conditions. **Dynamic groups** can be used as Email/DLs, Collaborative inboxes, Security groups.
- To change membership of a Dynamic group, you need to change the `membership query`.
- Dynamic groups cannot be members, only users can be members.
- Dynamic group roles have restrictions.

1) Go to `Google Admin Console` (need to be a groups administrator)
2) Go to `Menu` -> `Directory` -> `Groups`
3) Click `Create dynamic group`.
4) Build membership query:
  - Condition list: For example, you can select `User Department`
  - Value field: must start with letters, underscore, number
5) Optional set inclusion/exclusion conditions.
6) Add Name, Description, Group Email
7) Click `Save`
8) Click `Done`

#### Group management with API

- There are two options for creating groups with API: 
  - Directory API: i.e. `PUT https://admin.googleapis.com/admin/directory/v1/groups/groupKey`
  - Cloud Identity API: `POST https://cloudidentity.googleapis.com/v1/groups`

- Export a your Oauth token: `export TOKEN="$(gcloud auth print-access-token)"`

```bash
# Directory api
POST https://cloudidentity.googleapis.com/v1/groups
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "groupKey": {
    "id": "devops-team@example.com"
  },
  "labels": {
    "cloudidentity.googleapis.com/groups.discussion_forum": ""
  },
  "parent": "customers/C12345678"
}
```

#### Remove User from Org
- Removing a user from org depends on Domain or email verified.

1) Transfer Important data to another user (Super admin)
2) Delete the user: Go to `Menu` -> `Directory` -> `Users`
3) Choose `Delete one user` or `Delete multiple users`
4) Choose a transfer option depending on privileges.
5) Reuse or reassign email/license.

- Flexible billing is prorated, Annual/Fixed billing isnt affected.
- You can restore a deleted account for up to 20 days.

### Create a VM Instance
1) Enable necessary APIs.
2) Search `VM Instances` page:
3) Click `Create instance`
4) In `Machine Configuration`: Name, Machine type
5) Verify the OS and Storage
6) Under `Networking`, you can select `Firewall`
6) Optional, verify that `Observability` displays `Install Ops Agent`
7) Click `Create`.

### Create an Email Notification Channel and Alerting policy
1) Go to Alerting page
2) In the search bar, search `Monitoring`
3) Select `Edit Notification Channels`
4) On the page, scroll to Email and click `Add new`.
5) Enter your email and click `Save`.
6) Under Monitoring again, click Create policy.
7) Select the timeseries: 
  - `Select a metric`
  - `VM instance`
  - `Active metric categories`, select `Apache`
  - `Active metrics`, select `workload/apache.traffic`
  - click `Apply`
8) `configure trigger` fields and set `Threshold Value`
9) Select `Notifications and name `fields and `Notification channels` menu
10) Click `create policy`.

### Working with Cloud Logging

- **Cloud Logging** Real-time log management system with storage, search, analaysis and monitoring support for GCP resources, on prem and other providers.
  - Logs Explorer: interface lets you view individual log entries, includes concept of an *error group*
  - Log Analytics: interface lets you query your log data with SQL, to find patterns.
- You can **route** or forward log entries to Log bucket, BigQuery dataset, GCS bucket, Pub/Sub topic, Gcloud project
- **Categories** of log data: `Plaform` (GCP services), `Component` (GCP components), `Security` (Who/What/When/Where), `User-written` (Ops agent or cloud logging API), `multi-cloud`, `hybrid-cloud`

#### Using Logging and gcloud
- Billing must be enabled.
1) Create the gcloud project `gcloud projects create PROJECT_ID/NAME` and set project `gcloud config set project PROJECT_ID/NAME`
2) Create a log entry: `gcloud logging write my-test-log "An entry"` or structured with `gcloud logging write --payload-type=json my-test-log '{ "message": "My second entry", "weather": "partly cloudy"}'`
3) Read the log `gcloud logging read 'resource.type=global'`

#### View logs entries in Logs Explorer
1) Go to `Logs Explorer` page and search `Logging`.
2) In `Resource` menu, select `Global`.
3) Click the selected log `> Menu`.
4) Optionally, query log entries, i.e. `jsonPayload.weather:partly`
5) Click `Run query`.
6) Cleanup the log entries: `gcloud logging logs delete my-test-log`

### Error Reporting and Notifications

1) Generate a sample error in Cloud Shell
2) Go to `Error Reporting` page
  - Errors will show if `Auto reload` is turned on
3) Click the error name to view details.
4) Enable email notifications by going to `More :` -> `Turn on new error notifications for project`.
5) Deploy an `App Engine` app with a python main.py, `gcloud app deploy` and `gcloud app browse`

### Create a GKE Cluster and view Traces
1) Enable GKE and Cloud Trace APIs (billing should be enabled)
2) Create the cluster: `gcloud container clusters create cloud-trace-demo --zone us-central1-c`
3) Configure kubectl to get credentials: `gcloud container get-credentials cloud-trace-demo --zone us-central1-c`
  - Verify access with `kubectl get nodes`
4) Deploy application
  - opentelemetry packages needs to be installed in the application for instrumentation
5) Create trace data: `curl $(kubectl get svc -o=jsonpath='{.items[?(@.metadata.name=="cloud-trace-demo-a")].status.loadBalancer.ingress[0].ip}')`
6) Go to Trace explorer page

### Manage Billing

- Permissions needed (general):
  - `billing.resourceAssociations.list/delete/create`
  - `resourcemanager.projects.get`
  - `resourcemanager.projects.createBillignAssignment`
1) In the Google Cloud Console: Manage billing accounts page.
2) Select My projects tab and the Cloud Billing Account.
  - Look for `Billing is disabled`
3) In project row, `Actions :` menu, `Change billing` -> `Cloud Billing account`
4) Click `Set account`.
5) Optionally you can `lock the link` to prevent moving of project.

### Manage Budgets
- Cloud Billing budgets track your actual cloud cost against planned costs. You can set a budget alert threshold and set email notifications.
- Permissions needed (general)
  - Billing Account Administrator, Billing Account Cost Manager
  - Project Owner/Editor
  - `billing.budgets.create/get/list`
  - `resourcemanager.projects.get`
  - `billing.resourcebudgets.read/write`
1) Go to Budgets and alerts page
2) Click Create budge
  - Enter a name
3) Optionally, select `Read-only for project users`
4) Go to `Scope`, and click `Next`, to set the budget scope.
  - Scopes can be services, projects, folders
5) Select `Amount`, and click `Next` to configure amounts.
6) Set `Actions` (thresholds) and click `Finish`.
7) Under` Percent of budget`, select the amount
8) Under `Trigger on`, select either `Actual` or `Forecasted`
9) Set `Manage notifications`, role-based email notifications or cloud monitoring notificaiton channels, or **programmatic notifications**
10) Click `Finish` to save the budget.

- Check your budget quota (Up to 50,000 budgets) from the `Quotas` page.

#### Setup Cloud Billing data export to BigQuery
- General permissions:
  - BigQuery User Role, BigQuery Admin role, Billing Account Administrator
  - `resourcemanager.organizations.get`
  - `resourcemanager.projects.create`
  - `resourcemanager.projects.update`
- Enable Cloud Billing Data to export to BigQuery
  - Select/Create project
  - Verify billing is enabled
  - Enable `BigQuery Data Transfer Service API`
  - Create a BigQuery Dataset:
1) Go to `BigQuery` page
2) Select the `project ID`
3) Under `View Actions :`, click `Create dataset`
  - Enter a Dataset ID/name
  - Set Data location (multi-region recommended)
  - Enable table expiration option == cleared.
  - Under `Advanced Options` -> `Encryption` -> `default google encryption key` or `CMEK`
  - Click `Create Dataset`
4) Enable Cloud Billing to export the BigQuery Dataset, under `Billing export page:`
5) Choose the cloud billing account
6) On `BigQuery export` tab, click `Edit settings` for each type of data (pricing, detailed usage cost, standard usage)
7) Select the project from `Projects` list.
8) Select `Dataset ID`
9) Click `Save`
- BigQuery supports Batch Load (GCS or local file) and Streaming Load (Custom streaming sources)

### Manage Labels

1) Go to `Labels` page
2) `Select a project` drop-down
3) Once you choose a project, `+ Add label`
4) Click `Save`
5) Optionally, for multiple resources, go to `Manage resources` -> `Labels` -> `+ Add label`

### Using cloud SDK

- Initialize gcloud cli: `gcloud init` with optional `--console-only`, `--no-launch-browser`
  - choose a project where you have Owner, Editor, Viewer
  - lets you choose a default compute zone
- Improve screen reader: `gcloud config set accessibility/screen_reader true`
- List credentials stored on local system: `gcloud auth list`
- List config properties: `gcloud config list`
- General help: i.e. `gcloud help compute instances create`
- Authorize with service account instead of user account `gcloud auth activate-service-account`
- Access tokens:
  - Set the `CLOUDSDK_AUTH_ACCESS_TOKEN` env variable
  - set `--access-token-file` flag
  - Set access token path in `auth/access_token_file` property
- `gcloud auth login --cred-file=KEY_FILE`
- Switch an active account: `gcloud config set account ACCOUNT`
- Components of gcloud CLI:
  - `gcloud` for the default gcloud commands
  - `bq` for BigQuery command-line
  - `gsutil` (legacy), use `gcloud storage`
  - `core` gcloud core libraries
  - Use `gcloud components list` as well as `install`, `update` and `remove` gcloud components

#### Authenticate with Workforce Identity Federation

```bash
gcloud iam workforce-pools create-login-config \
    locations/global/workforcePools/WORKFORCE_POOL_ID/providers/PROVIDER_ID \
    --output-file=LOGIN_CONFIG_FILE_PATH

# use --activate when yhou craete the config file
gcloud config set auth/login_config_file
gcloud auth login --login-config=LOGIN_CONFIG_FILE_PATH
```

## Configuring Compute Resources

- **Machine Family**: General purpose, Storage-optimized, Accelerator-optimized, Memory-optimized, Compute-optimized.
- **Machine Types**: `highcpu`, `standard`, `highmem`, `megamem`, `hypermem`, `ultramem`
  - Also option for `-metal`, for bare metal machine type.
  
- **Custom Machine Types** can be created with N and E machine series. These are good for workloads requrigin more power/memory but not the whole next level, workloads that have per-CPU software license cost
  - To create, need generally: `compute.instances.setMachineType`, `compute.images.ReadOnly`, `compute.networks.use`, `compute.networks.useExternalIp`, `compute.disks.create`
  - Memory must be specified in 256 MB increments
  - N4, 80vCPU limit, 640 GB Memory limit


- Machine Family table:

|Size | vCPU | RAM | Use Case |
|-----|------|----|----------|
|e2-micro to e2-standard--32 |2-32|1-128GB|Cheapest option/cost-optimized, variable performance|
|n2-standard-2 to n2-highmem/cpu | 2-128|2-864GB|General purpose, Web servers, containerized apps|
|c2-standard-4 to c3-standard-60 |4-60+|4GB/vCPU|CPU-Bound workloads Intel Saphire rapids, ML inference|
|m3-ultramem-32 to m3-ultramem-176 |32-176|256 GB - 4 TB |Memory Intensive, SAP HANA, in-memory dbs, data analytics|
|a2-highgpu-1g to a23-megagpu-16g |12 - 96 |1 to 16 NVIDIA A100 |GPU heavy, deep learning|

- **Preemptible VM instances** are available at a 60-91% discount, but they get stopped after 24 hours. Your batch job will still run if stopped.
- **Spot VMs** (current) are more flexible, with no fixed limit but can be stopped. Use `--provisioning-model=SPOT`

### Use Cases
- HTTP Services and backend apps -> Cloud Run (Sudden scaling, pay for what you use, api endpoints)
- Event Driven/Data processing -> Cloud Run functions (even-driven workloads, sudden autoscaling, minimal configuration)
- Container-based apps/services -> Cloud Run (docker containres, autoscaling, custom API endpoint support)
- Monolithic workloads -> Compute Engine (OS level control, autoscaling support, custom machine support)

### GCP Decision Tree
```yaml
GCE   GKE,   App Engine,   Cloud Functions, Firebase
<-------Highly Customizable/Highly Managed---------->
```

- Firebase = mobile/HTML5 development
- Cloud Functions = Even-driven apps
- Compute Engine = Using specific OS/kernal, Using GPUs
- GKE/GCE = Container orchestration, hybrid or multi cloud, other than HTTPS protocols

### Apply backup plan during instance creation
https://cloud.google.com/compute/docs/instances/create-instance-with-gcbdr-backup-plan
1) Enable the Backup and DR Service API where the compute engine instance is
2) Create a backup vault
  - Need `roles/backupdr.backupvaultAdmin`
  - `backupdr.backupVaults.create/list/get/update/delete`
  - `backupdr.backupPlans.create/list/get/delete/associate`
  - `roles/compute.instanceAdmin.v1`
  - Go to `Backup vaults` page:
  - Enter `Name your backup vault` field
  - Click `Continue`
  - Choose `Location`
  - Click `Continue`
  - Select Minimum enforced retention policy between 1d-99y
  - `Define access to your backup vault` section, restrict access
  - Click `Create`.
  - COnfirm with: `gcloud backup-dr backup-vaults list ...`
3) Create a backup plan
  - Go to `Backup plans` page:
  - Click `Create Backup plan`
  - Select name and description, regions
  - From `Backup vault` section, choose the vault
  - Click `Add rule`
  - In `Add a backup plan rule`, fill out the details.
  - Click `Create`.
  - Verify with: `gcloud backup-dr backup-plans list...`
4) Go to `Create an Instance` page
  - Select your project
  - Go to `Machine configuration` page for name, region, zone, other settings.
5) Under `Backup plan` section, select `Select a plan`.
6) click `Apply`

### Create an Autopilot Cluster and deploy workload

- Billing should be enabled for your cloud account.
1) Visit `Kubernetes Engine` page, select a project, and enable the API.
2) Go to `Create an Autopilot cluster` page:
3) Fill out `Cluster basics`: Name
4) Go to `Workloads` on the GKE page.
5) Click `Deploy`
6) Fill out `Deployment name`
7) In `Kubernetes cluster`, select the one creasted in step 3.
8) Click `Next: Container details`: Existing container image, image path
9) Select `Next: Expose` (optional) to deploy as a service (port, target port...)
10) Click `Deploy`

### Cloud Run Basics

- **Cloud Run** is a fully managed service that lets you run containers based on any programming language
  - `Cloud Run services`: Used to run code that responds to web requests, events, functions.
  - `Cloud Run jobs`: Used to run code that performs a job then stops.
- Each Cloud Run service has an HTTP endpoint and unique `*.run.app` domain.
- Built-in traffic management
- Request-based autoscale and optional manual scaling.
  - Supports `scale to zero` if no incoming requests to service, or minimum number of instances.
- Instances in Cloud Run are disposable, each container has in-memory, writable filesystem that is not persisted.
  - To *persist files*, you can integrate Cloud Storage or mount a network filesystem (NFS)
- `IAP for Cloud Run`: Identity-Aware Proxy is a security feature that controls access by requiring Google Identities to authenticate. Acts as a gatekeeper for Cloud Run Services, provides fine grained IAM control. 
  - **Allows you to route traffic with a single click from all ingress paths.**
  - use `gcloud beta run deploy SERVICE_NAME ... --iap` flag

#### Deploy to Cloud Run
1) Go to the `Cloud Run` page:
2) Click `Deploy container` -> `Service`:
3) Under `Create service`, ensure `Deploy one revision from an existing container image` is selected.
4) In `Create service` page, click `Test with sample container for Container Image URL`
5) Enter a `Service name`
6) Select a `Region` from the list
7) Select `Authentication`
8) Click `Create` and copy the URL provided.

#### Cloud Run Functions

1) Enable Artifact Registry, Cloud Build, Cloud Run Admin API, Cloud Logging APIs
2) Add general permissions:
```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member=serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com \
    --role=roles/run.builder  
```
3) Go to `Cloud Run` page
4) Click `Write a function`
5) In `Service name` field, enter service name
6) Enter `Region`
7) Select `Runtime` version from list
8) Select `Allow unauthenticated invocations` from `Authentications` section.
9) Click `Create`. You can see the function in `Source` tab.

#### App Engine
- Use **App Engine** as a fully managed PaaS offering where you do not manage any infra, even containers.
- Use for long running applications, full websites or even backend APIs
- GCP handles: Scaling, Load Balancing, Patching, Logging, Monitoring
- Built-In features: Scale to zero (for Standard ONLY), traffic splitting (gradual rollouts), versioning, security sandbox.
- Options for `Flexible` or `Standard` environment. Standard environments support faster startup time, but Flexible environments offer more flexibility.
- Flexible environment VMs are restarted weekly for patching.

## Configuring Data Storage

- Choosing the Database for your needs:
  - Firestore: Document DB
  - Cloud BigTable: Other non-relational
  - Cloud Memorystore: for in-memory store
  - `Cloud Spanner`: 99.999% availability, low latency and **global** consistency
  - BigQuery: workload analytics
  - Cloud SQL: ACID guarantees, fast queiries, multi table transactional updates.

### Cloud SQL

- **Cloud SQL** is a fully managed relational database for MySQL, PostgresSQL and SQL Server.
- The database is stored on a scalable, durable network storage device called a `persistent disk` on a VM.
- Native integration with BigQuery federation.
- Cloud SQL instance configuration updates are done by the user, and system updates are performed by Cloud SQL.
- Supports backups and read/ cross-region read replicas, Point-in-time recovery for MySQL and PostgreSQL.
- Use read replicas for read-heavy workloads to increase performance.
- Use` Cloud SQL Auth Proxy` to establish authorized, encrypted and secure connections to your instance, using **IAM database authentication**.

#### Create a Cloud SQL instance
1) Go to `SQL` page:
2) Click `+ Create Instance`
3) Choose your database engine (MySQL, PostGres, SQL Server)
4) Customize, by default its multi-zonal
5) Advanced configurations: CPU/Memory, SSD (recommended), Storage capacity (automatic storage increase)
6) `Networking`, select public IP/private IPs
7) `Backup`
8) `Maintenance`
- You can then create a database, and connect to `BigQuery` for federated queries. and connect to `Data Studio` for visualization
- You can set up a `Cloud SQL proxy` inside a GCE instance by ssh inside and use the `cloud_sql_proxy` executable/configuration. Connect to the psql client and start querying.

### BigQuery Overview

- **BigQuery** is a fully managed AI-ready data platform with built-in search, geospatial analysis and business intelligence. There is the storage layer that ingests/stores/optimizes data and the compute layer which that analyzes.
- There are types of `views` in BigQuery, `materialized view` (precomputed that periodically catches results) and `authorized view` (shares a subset of data from source dataset).
- A BigQuery `job` is created every time you load, export, query or copy data. The job automatically tracks the progress of the task (`PENDING`, `RUNNING`, `DONE`)
- Reservations let you switch between on-demand pricing and capacity-based pricing.
- General permissions: `bigquery.jobs.create/get/udpdate/listAll/delete`
- `bq` command-line tool: 

```bash
bq ls # list datasets in current project
bq mk [DATASET_ID] # create new dataset
bq rm -r -f [DATASET_ID] # recursively delete a dataset and contents

bq ls [DATASET_ID] # list tables in a dataset
bq show [DATASET_ID].[TABLE_ID] # show table info

bq load --source_format=CSV \  # load data from google storage bucket
  [DATASET_ID].[TABLE_ID] \
  gs://[BUCKET]/[FILE].csv \
  [schema]

# Schema generation
bq schema [LOCAL_FILE.csv] > schema.json
```

#### Use BigQuery to query a public dataset
1) Ensure billing is enabled and BigQuery API is enabled.
2) Go to `BigQuery` page.
3) `Add data` dialog -> `Filter By` pane -> click `Public datasets`.
4) Select a dataset, and click `View dataset`.
5) In `Explorer` pane, you can view details
6) Next, go back to BigQuery page and click `+ SQL Query`
7) Enter a SQL query and click `Run`.

### Firestore Overview

- **Firestore** is a highly scalable, serverless NoSQL document db.
- Features of Firestore: Serverless, GenAI, Query Engine, real-time synch and offline mode.

- `Firstore in Datastore mode` is a NoSQL document database for atomic transactions, HA read and writes, massive scalability. It is legacy, only use if upgrading from Datastore.

### Spanner Overview
- **Spanner** is an always-on database with virtually unlimited scale which includes: multi-modal (SQL and/or NoSQL), efforless scaling, always-on, consistent transactions, Point-in-time recovery.
- Strong-ACID transactions and TrueTime ordering, 99.999% SLA, automatic replication.

### Bigtable Overview

- **Bigtable** is a sparsely populated table, NoSQL database service, that can scale to billions of rows and thousands of columns, with the ability to store petabytes of data. Used for `low latency and high throughput`.
- Use Cases: `Time-series data (CPU usage over time)`, Marketing data (purchase histories), Financial data (transaction histories and stock prices)
- Each intersection of row and column can contain multiple cells.
- A Bigtable table is sharded into blocks called `tablets`, to help balance query workloads. Tablets are stored on `Colossus` (Google's filesystem).
- Columns that are unused in a BigTable row don't take up space in that row.
- `Colum qualifiers` take up space in that row. Use them as data for efficiency.
- Data compression happens automatically via intelligent algorithm. Patterned data is more effiently compressed.
- Enable Data Read/Data Write and Admin Read logs for an instance from the `Audit Logs` page.

### MemoryStore

- **Memorystore** is fully managed in-memory Valkey, Redis and Memcached service that offers sub millisecond data access, scalabvility.

### Disk Storage
- **Block storage**, or `disks`/`volumes` are offered by Compute Engine. Can be used for block storage for boot and data volumes for all compute instances.
- **Local SSD** is the temporary or ephemeral block storage offering.
- **Hyperdisk** and **Peristent Disk** `Durable`, or `persistent`, block storage is for data to be preserved after you stop, suspend, delete a VM or on failure.

- Can also use the distributed filesystem on GCE as NFSv3 and SMB3 capable file system.

### Storage Classes

- A Storage class is a piece of metadata that is used by every object, which affects its availability and pricing model.

- Available Storage Classes:

|Storage Class/API name| Min Storage duration|Retrieval fees| Availability |
|----------------------|---------------------|--------------|--------------|
|STANDARD|None|None|>99.99 multi region, 99.99 in regions| 
|NEARLINE|30 days|Yes|99.95 multi-region, 99.9 in regions|
|COLDLINE|90 days|Yes|99.95 multi-region, 99.9 in regions|
|ARCHIVE|365 days|Yes|99.95 multi-region, 99.9 in regions|

- Storage Locations: Regional, Dual-region, Multi-region.

## Configuring Network Resources

- `Private Google Access` is for VMs that have only internal IPs for them to reach external IPs of Google APIs and services (Almost all supported services)
- A `PSA (Private Service Access)` endpoint is a private IP based connection that allows the VPC to privately connect to GCP services. (not available for many services)
- Private Service Connect - accerss managed services from inside VPC network. Private Service Connect endpoints are internal IP addresses in the consumer VPC.

- For GCP Firewall, you can filter firewall rules by `Network tags` or `Service accounts` with `--target-service-accounts`

### Choosing a Load Balancer

- Use `Application Load Balancer` for flexible features for HTTP(S) traffic. 
- Use a `Network Load balancer` to implement a TCP proxy load balancing setup to backends in one + regions.
  - `Proxy LBs` terminate incoming client connections and open new connections.
  - `Passthrough LBs` don't terminate the connection, instead the packet source/dest/url etc are remained unchanged.
- Use `Premium tier` IPs for the load balancer so traffic traverses GCP's high-quality backbone.

### Cloud CDN

- **Cloud CDN** works with global external Application LBs and Classic Application LBs to deliver any cachable content to your users.
- Temporarily stores content (`.jpg`, `.css`, `.js`, `.mp4`, `PDFs` ) in a specialized memory/disk-backed cache edge location.
1) `Global Forwarding rule`: An IPv4 forwarding rule gets the request and routes it.
2) `Edge Cache check`: If unable to serve from cache, continue processing
3) `Target HTTP Proxy`: Sends request to target HTTP(S) proxy depending on the load balancer.
4) `URL Map routing`: Target proxy uses URL map to determine that a single backend service recieves the requests.
5) `Backend Service`: Load balancer determines that backend service has only one instance group and directs traffic.
6) `Backend Instance response`: That VM in the instance group serves the content.

#### Set up a Managed Instance Group Backend

- A **managed instance group (MIG)** is a group of VMs you treat as one. Each VM in a MIG is based on an instance template.
  - You should NOT rely on attached disks in a MIG, use another centralized location, like Cloud Storage or add stateful disks.
  - `Instance templates` are IMMUTABLE, so you can not modify or update them.
  - When you create an instance, a boot disk with the same name is created.

- General permissions: Instance Admin, Security Admin, Network Admin, Project Creator
1) Set up an SSL Certificate for an HTTPS load balancer.
2) Go to `VPC networks` page to configure the network:
3) Click `Create VPC Network`
  - Provide Name, custom subnet, region, IP stack, IP range
4) Click `Done` and `Create`.
5) Go to `Instance Templates` page to create a managed Instance group.
6) Click `Create instance template`
  - Enter a Name, and boot disk
7) Expand `Networking` to configure NIC/network tags
8) Click `Done`.
9) Expand `Management` and enter a `Startup Script`.
10) Click `Create`.
11) Go to `Instance Groups` page
12) Click `Create Instance group`
  - Choose `New managed instance group (stateless)`
  - Enter Name, location, region, zone
13) Choose your template under `Instance template`.
14) Configure `Autoscaling mode` and click `Create`.
15) Add a named port in the `Port mapping` section and click `Save`.
16) Go to `Firewall policies` page and click `Create firewall rule`
  - Configure name, select network, Under targets, select specified targets.
17) Go to `External IP addresses` page to reserve an IP to reach your load balancer.
18) Set up the load balancer in the `Load Balancing` page.
  - Select an External facing Application LB
  - Configure the backend for the LB, and pay attention to the `X-Forwarded-For` IP address.
19) Select `Enable Cloud CDN`

### VPC networks

- A **VPC** is a virtual physical network that is inside Andromeda (Google's network)
- VPC networks, including associated routes and firewall rules are `global resources`, but the subnets are regional, and spans the Zones within the region.
- When you create an `auto mode VPC network`, one subnet from each region is auto-created within it within the `10.128.0.0/9` block.
- When you create a `custom mode VPC network`, no subnets are created automatically.
- You can switch an auto-mode VPC network to custom mode, but NOT vice versa.

#### Firewall rules
- `VPC Firewall rules` are applied to ingress OR egress, and IPv4 or IPv6 but not both.
  - Each rule is stateful, and the order/priority matters.
  - Each rule allows or denies traffic, but can be disabled for troubleshooting.
- *Hierarchical Firewall policies* are created at the organization or folder leve, but only are applied when associated. Use this to block all traffic that should never be accepted.
- There are certain exceptions to hierarchical and VPC firewall rules surrounding Google Cloud metadata packets.

- There are **two implied firewall rules**:
1) Implied Ipv4 allow egress rule, allow 0.0.0.0/0
2) Implied IPv4 deny ingress rule, deny source 0.0.0.0/0

### Set up DNS records with Cloud DNS
- **Requirements** are:
  - domain name  through a valid registrar
  - A VM instance
  - An IP address to point the A record of the zone to.
  - BIlling is enabled for project
  - DNS API enabled
1) Go to `Create a DNS zone` page
  - for `Zone type`, choose `Public`.
  - Enter the `DNS name`
  - Select `Off` in `DNSSEC` drop-down.
2) Click `Create`. (Zone details displayed)
3) Go to `Cloud DNS` page.
4) Click the Zone to add the record to
5) Click `Add standard`.
6) For `resource record Type`, create an `A` record.
7) Select the IP Address
8) Click `Create`.
9) Similarly, add a `CNAME` to the domain and click `Create`.
10) **Update your domain name servers to use Cloud DNS**.

- An A record maps a domain name to an IP address
- A CNAME maps a domain name to another domain name. CNAMES are NOT used for root domains, thats an A record.

#### Create a Private DNS Zone

```bash
gcloud dns managed-zones create NAME \
    --description=DESCRIPTION \
    --dns-name=DNS_SUFFIX \
    --networks=VPC_NETWORK_LIST \
    --labels=LABELS \
    --visibility=private
```

#### Other DNS info
- A `Forwarding Zone` is used to send DNS queries for a specific domain to a custom server.

- Create a dns record set:
```bash
gcloud dns record-sets create RRSET_NAME \ # DNS name that matches incoming queries
    --rrdatas=RR_DATA \  # arbitrary value
    --ttl=TTL \ # seconds that resolver caches this record set
    --type=RRSET_TYPE \ # example, A, CNAME
    --zone=MANAGED_ZONE # managed zone name
```

## Scenarios

### Creating and Using Service Accounts

- A `service account` is an identity used by apps, VMs and services to authenticate with GCP resources. The `Service account key` is the private json file key.

1) Enable `IAM API`
2) Go to `Service accounts` page.
  - Select your project.
  - Choose name/description
  - Click `Create and continue` to continue setup.
  - (Optionally) Choose one or more `IAM roles` to grant
  - Click `Continue`.
  - (Optionally) fill in SA users and admin roles
  - Click `Done`
3) From the `Service accounts` page again, click the `Keys` tab.
  - Click email address of SA to create a key for
  - Click `Add key` and `Create new Key`
  - Select `JSON` as the `Key Type`
  - Click `Create`

Example Private_key:

```json
{
  "type": "service_account",
  "project_id": "PROJECT_ID",
  "private_key_id": "KEY_ID",
  "private_key": "-----BEGIN PRIVATE KEY-----\nPRIVATE_KEY\n-----END PRIVATE KEY-----\n",
  "client_email": "SERVICE_ACCOUNT_EMAIL",
  "client_id": "CLIENT_ID",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://accounts.google.com/o/oauth2/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/SERVICE_ACCOUNT_EMAIL"
}
```
- **Use the SA key**: `export GOOGLE_APPLICATION_CREDENTIALS=path/to/private_key.json`

### Setting a maintenance window
1) While creating instance from `Create an instance` page:
2) Go to `Provisioning model` -> `VM provisioning model advanced settings`
  - Use `On host maintenance` to set behavior during maintenance events
    - `Migrate VM Instance` (recommended) or `Terminate VM Instance`
  - Use `Host error timeout` to set timeout for unresponsive VMs
  - Use `Automatic restart` option (`On` - recommended, or `Off`)
  - Click `Create`

OR set a bulk policy:
```bash
gcloud compute instances bulk create \
    --count=COUNT \
    --host-error-timeout-seconds=ERROR_DETECTION_TIMEOUT \
    --local-ssd-recovery-timeout=LOCAL_SSD_RECOVERY_TIMEOUT \
    --machine-type=MACHINE_TYPE \
    --maintenance-policy=MAINTENANCE_POLICY \
    --name-pattern=NAME_PATTERN \
    --restart-on-failure \
    --zone=ZONE
```

### Sole tenant nodes

- Use **sole-tenant nodes** when you need to have complete control over the physical VM.
  - Gaming workloads, finance workloads, ML workloads reserving GPU
  - `CPU Overcommit` hels you reduce per-VM costs by spreading cost of sole-tenant node across more VMs. Good for underutlized workloads that may have bursts.

### Using Instance templates
- An **instance template** is a way to save VM configuration including machine type, boot disk image, labels, startup scripts, etc.
- Understand regional vs Global instance templates, Google recommends regional instance templates.
- No Additional cost to using instance templates.
- For instance templates, you can modify the number of GPUs in `Machine Configuration`.

- Create a regional instance template:
```bash
 gcloud compute instance-templates create INSTANCE_TEMPLATE_NAME \
     --source-instance=SOURCE_INSTANCE \
     --source-instance-zone=SOURCE_INSTANCE_ZONE \
     --instance-template-region=REGION
```

### Access VM
- You can access your Linux VMs by:
1) OS Login: 
  - Needs OS Login and 2FA enabled on domain/account
  - requires `roles/compute.osLogin` or `roles/compute.osAdminLogin` and others.
  - Enable OS login with project metadata values `enable-oslogin=TRUE`, `enable-oslogin-2fa=TRUE`
2) Managing SSH keys in metadata:
  - All users have sudo access
  - Need to keep track of expired keys
  - Use ssh-keygen to generate ssh keys
  - `gcloud compute os-login ssh-keys add --key-file=PATH --project=PROJECT --ttl=EXPIRY`
  - Remove an ssh key: `gcloud compute os-login ssh-keys remove --key=KEY`
  - You can block ssh key creation: `--metadata block-project-ssh-keys=TRUE`
3) Temporarily grant user access to instance:
  - Grant a principal, like a user/service account, access as an identity
  - `gcloud compute RESOURCE_TYPE add-iam-policy-binding RESOURCE_NAME --member=PRINCIPAL --role=ROLE`

### Manage Quotas

1) Go to `Quotas` page:
2) CLick `Filter` list and select:
  - `Service` -> `Compute Engine API`
  - `Type` -> `Quota`
  - `Name` -> `VM instances`
  - (Optionally), For `Metric` select any CPU/Commited CPU quota name
  - (Optionally), sort by `Dimensions` (locations).
3) Click `Edit` and complete form to choose regions whose quotas to change.
4) Click `Submit Request`

### GKE Configure Cluster Access
1) `Enable Kubernetes Engine API`
2) Install kubectl and related components
  - `gcloud components update`
  - `gcloud components install kubectl` verify with `kubectl version --client`
  - `gcloud components install gke-gcloud-auth-plugin`
3) Update kubectl configuration to use plugin:
  - `gcloud container clusters get-credentials CLUSTER_NAME --location=CONTROL_PLANE_LOCATION`
4) Verify connection: `kubectl get namespaces`

### Enable Node Auto Provisioning
- `Node Auto Provisioning` can help with creating new nodes based on your workloads needs. Works with both standard and auto-pilot.
1) Ensure your cluster has autoscaling with `gcloud container clusters update MY_CLUSTER --enable-autoscaling`
2) Update the cluster to enable node auto-provisioning with allowed values
```bash
gcloud container clusters update CLUSTER_NAME \
  --enable-autoprovisioning \
  --min-cpu 1 \
  --max-cpu 100 \
  --min-memory 1 \
  --max-memory 512 \
  --location=LOCATION
```

### Google Cloud Metrics
- In Console, you can go to the `Metrics Management` page
- Metric Types: `DELTA` (Change in time interval), `GAUGE` (value Over-time, up or down), `CUMULATIVE` (Counter, increases over time)
  - An identifier for example: `storage.googleapis.com/api/request_count`
- Metric Values: `BOOL`, `INT64`, `DOUBLE`, `STRING`, `DISTRIBUTION`
- String values in custom metrics are not supported, but you can replicate the functinality by external translation.


### Deploy an App to GKE by gcloud
1) Enable Artifact Registry and Google Kubernetes Engine API
2) Set project `gcloud config set project PROJECT_ID`
3) Create auto pilot cluster: `gcloud container clusters create-auto my-cluster --location=us-central1`
4) Get credentials: `gcloud container clusters get-credentials my-cluster --location=us-central1`
5) Create deployment: `kubectl create deployment hello-server --image=docker.pkg.dev/google-samples/hello:1.0`
6) Expose the service to internet: `kubectl expose deployment hello-server --type LoadBalancer --port 80 --target-port 8080`

### Deploy a GKE stateful app
- Key here is the Statefulset kind and PVC
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: <STATEFULSET_NAME>
spec:
  selector:
    matchLabels:
      app: <APP_NAME>
  serviceName: "SERVICE_NAME"
  replicas: 3
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: <APP_NAME>
    spec:
      containers:
      - name: <CONTAINER_NAME>
        image: ...
        ports:
        - containerPort: 80
          name: <PORT_NAME>
        volumeMounts:
        - name: <PVC_NAME>
          mountPath: ...
  volumeClaimTemplates:
  - metadata:
      name: <PVC_NAME>
      annotations:
        ...
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```
- Inspect statefulset: `kubectl rollout status statefulset STATEFULSET_NAME`
- Scale statefulset: `kubectl scale statefulset STATEFULSET_NAME --replicas NUM_REPLICAS`


### GKE DNS or IP based endpoints/Authentication
- **DNS-based endpoint**: Access to control plane depends on DNS resolution of source traffic
  - Allows for dynamic access policy based on IAM policies
  - Access control plan from external locations without bastion/proxy nodes.
- **IP-based endpoint**: Access to control plane depends on source IP address, controlled by YOUR authorized networks.
  - IP-based limitations include subnet expansion challenges and integration with VPC Service Controls.

- You can create a cluster with a private endpoint with `--enable-private-endpoint` or which will allow access at `cluster-name.private.googleapis.com`

- `controlPlaneEndpointsConfig` block describes Control Plane network definition:
```yaml
controlPlaneEndpointsConfig:
dnsEndpointConfig:
  allowExternalTraffic: true # below is dns endpoint of cluster
  endpoint: gke-dc6d549babec45f49a431dc9ca926da159ca-518563762004.us-central1-c.autopush.gke.goog
ipEndpointsConfig:
  authorizedNetworksConfig:
    cidrBlocks: # only below cidrs allowed to access public endpoint (if enabled)
    - cidrBlock: 8.8.8.8/32
    - cidrBlock: 8.8.8.0/24
    enabled: true # enable IP-based ACLs
    gcpPublicCidrsAccessEnabled: false
    privateEndpointEnforcementEnabled: true # enforce private endpoint connection for all access
  enablePublicEndpoint: false # No public endpoint exposed
  enabled: true
  globalAccess: true
  privateEndpoint: 10.128.0.13
  # This DOES NOT prevent exposing apps to public internet
  # Only Load balancer/VPC/Firewall configs
```

### Creating a firewall rule

- Allow port 80 to VMS with tag web-server
```bash
gcloud compute firewall-rules create allow-http \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:80 \
  --target-tags=web-server \
  --source-ranges=0.0.0.0/0
```

### Create a custom image
- You can create `custom images` from *source disks*, *images*, *snapshots*, or *Cloud storage* stored images. From these images you can create custom VMs.

1) Prepare your VM for an image
  - Stop the VM and pause apps, use app flush, stop apps from writing to persisitent disk
  - Disable auto-delete for disk so in case of deletion afterwards.
  - `gcloud compute instances set-disk-auto-delete .. --no-auto-delete --disk=source_disk`
2) Create the image: `gcloud compute images create IMAGE --source-disk --force`
  - `use --source-snapashot` for snapshot
  - Enable guest OS features: `--guest-os-features=FEATURES`, several options for FEATURES

### Build and Push a docker image to Artifact registry
1) Enable services: `gcloud services enable artifactregistry.googleapis.com cloudbuild.googleapis.com`
2) Create artifact registry repo: `gcloud artifacts repositories create my-repo --repository=format=docker --location=us-central1`
3) Authenticate to docker registry: `gcloud auth configure-docker us-central1-docker.pkg.dev`
4) Build and push: `gcloud builds submit --tag us-central1-docker.pkg.dev/PROJECT_ID/my-docker-repo/my-image`
- (Optionally), use custom cloud build config: `gcloud builds submit --config cloudbuild.yaml`