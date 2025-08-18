# Azure Virtual Desktop

## Key Concepts

- **Azure Virtual Desktop** is a desktop and application virtualization service that runs in Azure. Virtual Desktop Infrastructure is *VDI*.
- Works across `Windows`, `Mac`, `iOS`, `Android`, `Linux` with apps that you can use to access remote desktops and apps.

- Demand for Enterprise VDI (1000 VDs or above) comes from: security/regulatory needs, elastic workforce, mobile users and legacy apps.

- **Components Microsoft Manages**
    - `Web Access`: Web Access service lets users acess VDI and remote apps via *HTML5-compatible web browser* from anywhere on any device. Compatible with Entra MFA.
    - `Gateway`: The Remote Connection Gateway service connects remote users to VDI *from any internet-connected device* that can run the VD client.
    - `Connection Broker`: Connection broker service *manages user connections to virtual desktops and remote apps*. Provides load balancing and reconnection to existing sessions.
    - `Diagnostics`: *Event-based aggregator* that marks each user or admin action on the VDI deployment as a *success or failure*. Admins can query this.
    - `Extensibility Components`: Several provided, for example you can manage using Windows PowerShell or REST APIs.

- **Components Customer Manages**
    - `Azure Vnet`: VD **host pools** are connected to an AD domain, and you can define network topology to access from the *intranet* or *internet*, based on policy. You can connect AVD to on-prem network using VPN, or ExpressRoute to exend the on-prem network INTO the Azure cloud over a private connection.
    - `Microsoft Entra ID`: Entra is used by AVD for IAM for features like: Conditional access, MFA, and *Intelligent security graph*.
    - `AD DS`: AVDs **MUST** domain-join an AD DS service. You can use Entra Connect to associate AD DS with Entra ID.
    - `Azure Virtual Desktop session hosts`: A **host pool** can run on the below operating sysytems. Each session host has an **AVD agent** which registers the VM as part of the AVD workspace/tenant. Each host pool can have 1+ app groups (App groups: collections of remote apps/desktop sessions that users can access).
        - Windows 10/11 Enterprise
        - Windows 10/11 IoT Enterprise
        - Windows 10/11 Enterprise Multi-session
        - Windows Server 2016/2019/2022/2025
        - Custom Windows images
    - `Azure Virtual Desktop workspace`: An AVD workspace or tenant is a management construct to manage and publish host pool resources.

- **Host pools** are a collection of one or more identical VMs within an AVD environment. 
    - **Pooled** host pools are for several users to sign in and SHARE a VM. None of these users are typically admins. With this option, you can choose Windows 10/11 Enterprise multi-session (exlusive to AVD) or custom image. Assign users to whichever host is currently available (depending on the load balancing algorithm).
        - Pooled host pools have a `preferred application group type` that dictates whether users see RemoteApp or Desktop apps in their feed if both resources are published to the same user. (Prevents users from connecting to desktop and RemoteApps at same time in SAME host pool)
    - **Personal** host pools are where each user has a DEDICATED VM. These users are typically local admins. Sometimes called *persistent desktops*, always allow users to connect to the same session host. Ability to save files within the desktop env, customize it.
    - You can set up a host pool to be a **validation environment**, which lets you monitor service updates before applies to non-validation environments.
    - You can manage Scaling, RDP Properties, Scheduled agent updates, networking, Application groups, MSIX packages and session hosts from the Host Pool page.

- An **Application Group** controls access to a full desktop or logical grouping of apps on a host pool.
    - You publish applications by adding them to an application group.
    - Can be of type `Desktop` or `RemoteApp` (RemoteApp not supported for personal host pools).
        - For Desktop, you can only publish a full desktop and all apps in MSIX packages.
        - A Desktop application group `-DAG` is already created when you create the host pool.
    - You can assign *multiple RemoteApp application groups* to the same host pool. Only 1 single Desktop App group can exist in a single host pool.
    - Click `Add Applications` and choose application source as either: `Start menu`, `file path` or `MSIX package`.
    - After Applications, click `Assignments` and add your AD groups. You can then `Register` application group from the Workspace tab.

- A **Workspace** is a logical grouping of application groups. Each application group MUST be associated with a workspace.
    - An application group can only be assigned to a single workspace.

#### Azure Virtual Desktop Workspace Layout

- 📁 **Workspace: FinanceWorkspace**
- ├── 📦 App Group: FinanceDesktopAppGroup (Desktop)
- │   └── 🖥️ Host Pool: FinanceHostPool
- ├── 📦 App Group: FinanceRemoteApps
- │   └── 🖥️ Host Pool: FinanceHostPool

- 📁 **Workspace: HRWorkspace**
- ├── 📦 App Group: HRDesktopAppGroup (Desktop)
- │   └── 🖥️ Host Pool: HRHostPool
- ├── 📦 App Group: HRRemoteApps
- │   └── 🖥️ Host Pool: HRHostPool

- 📁 **Workspace: ITWorkspace**
- ├── 📦 App Group: ITToolsApps
- │   └── 🖥️ Host Pool: SharedHostPool

- Service Update options include:
    - `MCM Microsoft Configuration Manager`: updates server and desktop OS.
    - `Windows Updates for Business`:  updates desktop OS like Windows 10 multi-session.
    - `Azure Update Management`: updates server OS.
    - `Azure Log Analytics`: checks compliance.
    - **Deploy a new custom image to session hosts monthly**

- Limitations Table
i.e. You can create up to 1300 workspaces per entra tenant.

|AVD Object|Per parent container object|Service Limit|
|-----|-----|-----|
|Workspace|Entra Tenant|1300|
|HostPool|Workspace|400|
|Application Group| Entra Tenant|500|
|RemoteApp|Application Group|500|
|Role assignment|Any AVD object|200|
|Session host|HostPool|10,000|

- **Azure Recommendations**
    - Deploy no more than 5,000 VMs per subscription per region. For more, use multiple hub-spoke, peerings.
    - For automated session-host scaling tools, limit is 2,500 VMs per sub per region.
    - Can deploy up to 132 VMs in a single ARM template.
    - VM session-host name prefixes cannot exceed 11 characters.

- **Remote Desktop Protocol (RDP)** uses various techniques to perfect the server's remote graphics delivery to the client. RDP dynamically adjusts various parameters depending on use case, compute availability and network bandwidth to deliver the best performance.
    - RDP multiplexes multiple **Dynamic Virtual Channels (DVCs)** into a single data channel. (There are separate DVCs for graphics, input, device redirection, printing, etc)
    - Amount of data sent over RDP depends on user activity. (basic textual content in a session is minimal bandwidth, but printing a large amount of pages takes a lot)

- Estimating Bandwidth Utilization in RDP

|Type of Data|Direction|How to estimate|
|----|----|----|
|Remote Graphics|Session host to client|[guidelines](https://learn.microsoft.com/en-us/azure/virtual-desktop/rdp-bandwidth#estimating-bandwidth-used-by-remote-graphics)|
|Heartbeats|Bidirectional|~20 bytes per 5 seconds|
|Input|Client to session host|based on user activity, generally under 100 bytes|
|File Transfers|Bidirectional|Use bulk compression, use .zip compression rates|
|Printing|Session Host to client|Depends on driver using bulk compression, use .zip compression rates|

- To reduce the amount of data transferred over the network, RDP uses the combination of techniques like:
    - Frame rate optimizations
    - Screen content classifications
    - Progressive image encoding
    - Client-side caching
    - RDP uses dynamic bandwidth allocation and allows it to use the full network pipe when available.

- General Bandwidth tips and facts:
    - Text and solid color areas consume less bandwidth.
    - Idle time in RDP means minimal screen updates and bandwidth usage.
    - Minimzed Windows don't send graphical updates.
    - Display resolution impacts network bandwidth.
    - Only changed parts of the screen are transmitted.
    - Video playback is essentially a slideshow (RDP dynamically uses video codecs)
    - Usually, you do not need to limit bandwidth utilization, instead specify a throttle rate in QoS Policy.

- You can use policy-based `Quality of Service (QoS)` within Group Policy to **set predefined outbound throttle rates**.

### Networking
- **RDP Shortpath for AVD** establishes direct UDP-based transport between the local device/app and the session host in AVD.
    - If the initial shorpath is successful, RDP data stream bypasses the AVD gateway afterwards.
    - By default, RDP establishes a UDP remote session for better reliability and latency consistency.
    - `TCP-based (443) reverse connect transport` has the highest success rate for RDP connections.
    - RDP Shortpath can be used in two ways:
        1. Managed Networks: direct connectivity between client and session host using a VPN for example. Two ways:
            - **Listener Mode**: Direct UDP 3390 between client and session host, *enable RDP shortpath listener on each session host*.
            - **STUN mode**: Direct UDP between client and session host, *using STUN (Simple Traversal Underneath NAT) protocol*. Inbound ports aren't required.
        2. Public Networks: direct connectivity between client and session host over public connection.
            - Direct UDP connection using *STUN protocol* between client and session host.
            - Indirect UDP connection using *TURN (Traversal Using Relay NAT) protocol* with relay between client and session host (*preview*).
    - Transport used for RDP Shortpath is based on `Universal Rate Control Protocol (URCP)`.
    - RDP Shortpath for public networks with TURN is **only available** in Azure Public Cloud (Not Govmt or China).
    - Benefits of RDP Shortpath:
        - Using URCP to enhance UDP achieves best performance.
        - Removal of extra relay points reduces round-trip time.
        - For managed networks: brings support for QoS priority connections, and throttle rate.

- **Required FQDNs and endpoints for Azure Virtual Desktop**:
    - `login.microsoftonline.com` over `TCP 443`, service tag is `AzureActiveDirectory`
    - `*.wvd.microsoft.com` over `TCP 443`, service tag is `WindowsVirtualDesktop`
    - `azkms.core.windows.net` over `TCP 1688`, service tag is `Internet`
- **Microsoft 365 Unified Domains**
    - ID: `184`, `*.cloud.microsoft`, `*.static.microsoft`, `*.usercontent.microsoft` over `TCP/UDP 443`
- `Microsoft.DesktopVirtualization` provider on the subscription needs to be registered before private links are created.

#### Shortpath for Managed Networks
- You can achieve direct line-of-sight connectivity (**No firewalls**) for RDP Shortpath with managed networks using:
    - ExpressRoute private peering
    - Azure VPN Gateway (Site-to-site or Point-to-site VPN IPsec)

- To use RDP Shortpath for managed networks in Listener Mode, you **MUST enable UDP listener on your session hosts**, by default port `3390` is used.

- Connection Sequence:
    - All *connections* begin by establishing a TCP-based (443) *reverse connect transport* over the AVD Gateway. 
    - Then, client + session host establish initial RDP transport negotiating capabilities.
    - Session host sends lists of its IPs to client.
    - Client establish parallel UDP-based transport directly to one of the IPs.
    - Client probes IP addresses.
    - Client establishes secure connection using TLS over reliable UDP.
    - After establishing the RDP shortpath transport, all Dynamic Virtual Channels (DVCs like remote graphics, input, device redirection) are moved to the new transport.
        - If firewall or network topology prevents client from direct UDP connectivity, RDP continues with reverse connect transport.

#### Shortpath for Public Networks
- To provide best chance of successful public UDP connection, there are direct and indirect types:
    - **Direct**: STUN is used to establish direct UDP connection between client and session host. If a firewall or network device blocks traffic, an indirect UDP connection will be tried.
    - **Indirect**: using TURN (Traversal Using Relay NAT) protocol with relay between client and session host (*preview*).
        - TURN is an extension of STUN, using TURN means the *public IP and port are known in advance*.
- When a connection is established, `Interactive Connectivity Establishment (ICE)` coordinates the management of STUN and TURN to optimize connections to preferred network protocols.
- Each RDP client session uses a dynamically assigned UDP port from `49152-65535` by default that accepts RDP Shortpath traffic (session host uses 3390).
- Because of *IP packet modification*, the recepient of traffic will see the public IP of the NAT gateway instead of actual sender.

- Connection Sequence:
    - All *connections* begin by establishing a TCP-based *reverse connect transport* over the AVD Gateway.
    - Then, client + session host establish initial RDP transport negotiating capabilities.
    - If RDP Shortpath for public networks is enabled on session host, `candidate gathering` is initiated.
        - Session host enumerates all NICs (including VPN and Taredo)
        - Windows TermService allocates UDP sockets and stores `IP:Port pairs` in candidate table as `local candidate`.
        - Remote Desktop Services service uses each UDP socket allocated to try and reach the AVD STUN Server via public internet over port `3478`.
        - If packet reaches STUN server, the response is stored as `reflexive candidate`.
        - Session host/client exhange candidate lists and attempt connections simulatneously, on both sides.
        - If STUN fails, an indirect conneciton is tried using TURN.
        - Client establishes secure TLS over reliable UDP
        - After establishing the RDP shortpath transport, all Dynamic Virtual Channels (DVCs like remote graphics, input, device redirection) are moved to the new transport.

- RDP Shortpath for managed networks provides a direct UDP-based transport between Remote Desktop Client and Session host, and also enables you to configure QoS policies for the RDP data.
- **QoS** is a network feature that helps ensure important traffic gets higher priority by **setting multiple network queues**.
- Quality of Service (QoS) policies help with:
    - `Jitter`: RDP packets arriving at different rates.
    - `Packet Loss`: dropped packets which result in retransmission.
    - `Delayed round-trip time (RTT)`: results in delays between input and reaction from remote app.

- The **LEAST** complicated way to address the above issues is to increase data connection's size, but costly. So its recommended to *first implement QoS, then, if necessary, increase bandwidth*.
- The shortest path to session host is best.
- Any obstacles in between such as proxies or packet inspection devices *ARE NOT* recommended.


### Monitoring
- Azure Monitor Network watcher consists of three sets of capabilities, (11 tools in total):
    - Monitoring: Connection Monitor, **Topology**.
    - Network Diagnostic tools: NSG Diags, Effective security rules, VPN Troubleshoot, **Connection Troubleshoot**, **IP Flow Verify**, Packet Capture, and **Next Hop**.
    - Traffic: Flow Logs, Traffic Analytics.

- **Azure Advisor** should be the first stop for AVD issues, from here you can see recommended solutions.
- AVD uses Azure Monitor for monitoring and alerts, each activity log for AVD is categorized as:
    - Management Activities
    - Feed
    - Connections
    - Host registration
    - Errors
    - Checkpoints
    - Agent Health Status
    - Network
    - Connection Graphics
    - Session Host Management Activity
    - Autoscale
    - **Note** that connections that don't reach AVD *will not* show up in diagnostics results.

### Identity and Security

- **Authentication**
- For users connecting to a remote session, there are THREE separate **authentication points**:
    1. `Service authentication to AVD`: retrieve list of resources user has access to from client.
        - To access AVD resources, you must first authenticate by signing-in with an Entra account.
        - Authentication happens when you subscribe to a workspace to retrieve resource and connect to apps/desktops.
        - Includes MFA, Passwordless (i.e. Hello for Business), Smart Card (certificate-based auth needs to be enabled for Smart Card).
    2. `Session host`: when starting a remote session. 
        - Username and password is required for a session host (seamless to user if SSO enabled).
        - ***Username and password* is supported authentication type for all types of clients**.
        - ***Entra Authentication* works for all EXCEPT *Remote Desktop app***
        - SSO allows the connection to skip the session host credential prompt and auto-sign the user in to Windows.
        - AVD supports both **NT Lan Manager** and **Kerberos** for session host authentication.
    3. `In-session authentication`: connecting to other resources *within* a remote session, prompted for authentication.
        - Passwordless authentication is enabled automatically if session host and local PC are:
            - Windows 11 single or Multi-session.
            - Windows 10 single or multi-session
            - Windows Server 2022

- Use **Microsoft Defender for Cloud's** Just-In-Time Access (JIT) to allow connection only needed ports for a period of time. NSG Is recommended first.
    - Microsoft Defender for Servers P2 license is minimum for JIT.

- Specific Roles:
    - `Desktop Virtualization Contributor`: Manage all your AVD resources (includes host pools, app groups, workspaces, etc.).
    - `Desktop Virtualization User`: Access and Use apps on a session host from an Application group as a non-admin user.
    - `Desktop Virtualization Host Pool Contributor`: Manage all aspects of host pool.
    - `Desktop Virtualization Application Group Contributor`: manage all aspects of an app group.
    - `Desktop Virtualization Workspace Contributor`: manage all aspects of workspaces.
    - `Desktop Virtualization User Session Operator`: allows for sending messages, disconnecting sessions, and using *logoff* function to sign users out.
    - `Desktop Virtualization Session Host Operator`: View and removing session hosts, change drain mode.
    - `Desktop Virtualization Power On Contributor`: allow AVD resource provider to start VMs.
    - `Desktop Virtualization Power On Off Contributor`: allow AVD resource provider to start/stop VMs.
    - `Desktop Virtualization Virtual Machine Contributor`: allows AVD resource provider to create/delete/update/start/stop VMs.

- `Virtual Machine User Login` is needed for users to login.

- Azure Virtual Desktop delagated access supports:
    - Security Principals: Users, User groups, SPNs.
    - Role Definitions: Built-in, Custom.
    - Scopes: Host pools, App groups, Workspaces.


- When a user connects to a remote session, they need to authenticate to the *(1) AVD service* and the *(2) session host*.
    - **When MFA is enabled, its used when connecting to the AVD service**.
- Entra P1 or P2 is needed as well as an Entra Group with AVD users assigned.

- To create a **Conditional Access Policy**:
    - Sign in to the `MSFT Entra admin center` as at least `Conditional Access Administrator`.
    - Browse Protection -> Conditional Access -> Policies -> New Policy
    - Assignments -> Users -> Select your group.
    - Assignments -> Target resources -> **No target resources**
    - Select what this policy applies to -> Cloud apps
    - Include -> Select apps -> None
    - In the new pane, you can search `Azure Virtual` to find the apps "Azure Virtual Desktop".
    - **Choose the client apps** the policy applies to (i.e. "Browser", "Mobile apps and desktop clients")

### FSLogix

- `FSLogix` is a profile container solution that simplifies and persists user profiles, ensures consistent and fast logins with AVD. At sign-in, the container is dynamically attached to the computing environment.
    - Roam user data between remote session hosts.
    - Minimize sign-in times
    - Application rule sets manage access to any items.
    - Stores user profiles as VHD/VHDX files on Azure file shares or Azure NetApp Files (ANF).

- Two container types of FSLogix:
    - `Profile container`: contains all related user profile data stored in VHD(x), stored in `C:\Users\%username%`. most commonly used container in FSLogix. There are some default **exclusions** in the `%userprofile%\AppData\Roaming and Local`
        - The profile container is a complete roaming profile solution for AVD.
        - REGEDIT location: `HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix\Profiles`
        - Need at least `Enabled` and `VHDLocations` registry settings configured.
        - verify with `frx list-redirects` from FSLogix apps directory.
    - `ODFC container`: stores profile content unique to Microsoft Office applications.
        - REGEDIT location: ` HKEY_LOCAL_MACHINE\SOFTWARE\Policies\FSLogix\ODFC`

- You can apply 4 types of FSLogix Apps Rule Sets which **DO NOT support Entra cloud-only accounts** (Only Hybrid or synced since need an AD DS)
    - Hiding Rule
    - Redirection rule
    - Specify value rule
    - App container (VHD) rule **RETIRED**

- Rule sets can be assigned to: User, Group, Process, IP, Computer, Dir, Environment Variable.

- 4 types of Windows Profile: Local user, Roaming user, Mandatory profile, Temporary profile.
    - FSLogix enables local profiles to act like Roaming profiles.

- The **FSLogix File Share** in the Storage Account must have `Azure Active Directory Domain Services (AD DS)` set up FROM the storage account. It implicitly domain joins the Storage account for all NEW and EXISTING file shares.
    - Create a transaction optimized tier fileshare named `userprofile`
    - Give Storage File SMB Data contributor to the `permissions - FsLogix Container` AD group.
    - Add File SMB Data Share Contributor to from the `IAM` of the file share for `permissions - FsLogix Container` assignment.
    - From each Session Host, `Run Command` and use Powershell to apply the FSLogix profile container to the file share, and copy the agent there.
    - Log off existing user and relogin to apply FSLogix changes. (When logging in, you will see `FSLogix is setting up..`)

- **Azure NetApp Files (ANF)** for AVD are used for low-latency FSLogix profile container storage.
    - Flow is: Create NetApp Files account -> Create Capacity Pool -> Create Files volume -> Configure profile containers.

- **Cloud Cache** is a feature that works with Profile and ODFC containers to provide resiliency and HA by using the locally mounted container to provide periodic updates to remote container.
    - Based on the order of entries in `CCDLocations`
    - Components of Cloud Cache: Local Cache, Proxy Files, Remote Storage Providers, Auxillary Files

### Backup and DR

- **AVD DOES NOT have native DR features**, but you can use: Availability Sets, AZs, `Azure Site Recovery`, and Azure Files redundancy in combination for user profiles and data.

## Scenarios

### Create HostPool
- When creating a **Host Pool**, among the parameters are:
    - `Subscription/Resource Group`
    - `Validation Environment`: Yes or No
    - `Preferred App Group Type`: Desktop or RemoteApp. When using the Azure portal, a Desktop appGroup is created automatically.
    - `Host Pool Type`: Pooled (Incudes Max session limit and load balanacing) or Personal
    - `Virtual Machines`: Yes or No
        - `Availability Options`: Availability Zones (Cheapest option for datacenter recovery) and Availability Set.
        - `Security Type`: 
            - Standard
            - Trusted Launch (Options for secure boot and vTPM)
            - Confidential (mandatory secure boot, vTPM, integrity monitoring).
        - `Image`: Select OS or choose from Compute Gallery or managed image.
        - `VM Size`: 
        - `Hibernate`: Available for personal host pools only. FSLogix DOES NOT support hibernate.
        - `Number of VMs`: Up to 400 session hosts.
        - `OS Disk Type` and `Size`: Premium SSD recommended.
        - `Confidential computing encryption`: Only if Confidential vm type.
        - `Boot Diagnostics`
        - `Virtual Network Options`
        - `Domain to join`
        - `Username/password`
    - `Workspace` (optional): Yes or No. can set up separately.
        - `Register desktop app group`: Yes or no to register default desktop applicaiton group to workspace.
        - `To this workspace`: Select existing or create new.
    - `Advanced`: Diagnostics and LA details are here.

- `New-AzWvdHostPool @parameters` to create a new host pool.
    - use `PersonalDesktopAssignmentType=Automatic` for personal host pools
- `Get-AzWvdHostPool` to get host pool info passing RG add pool name.

### Add Session Hosts to a Host pool
- If you created a VM outside of AVD and want to add it to a host pool:
    - Generate Registration key from Host Pool page Overview under `Regsitration Key` and `Generate new key`.
        - `New-AzWvdRegistrationInfo` also generates a token with an `-ExpirationTime`
    - Make sure VM is domain joined to Entra or AD DS (SSO should be enabled)
    - Install `Azure Virtual Desktop Agent` and `Azure Virtual Desktop Agent Boot Loader` on each VM. This process also installs Geneva and SxS Network Stack apps.
    - VMs Running *Windows Server* need the Remote Desktop Session Host (RDSH) role, `Install-WindowsFeature -name RDS-RD-Server -Restart`
    - Apply the `Windows_Client` License to each VM

- Identity parameters when deploying a session host: Domain name, Credentials to join session host to domain, OU (optional) 

### Customize RDP Properties for Host Pool
- Example Powershell `Set-RdsHostPool -CustomRdpProperty "audiocapturemode:i:1"` cmdlet and parameter.
- Default RDP file properties: 
    - Multi-monitor mode (Enabled)
    - Devide redirections enabled (drives, clipboards, printers)
    - Remote audio mode (play locally).

### Create a Workspace
- When creating a **Workspace**, the parameters include:
    - `Subscription/Resource Group`
    - `Workspace name`: i.e. workspace01
    - `Friendly name`: optional
    - `Location`: Azure region
    - `Application Groups`: Optional Yes or No
        - `Register application groups`: Add from here
    - `Advanced`: Diagnostics and LA details here.

- `New-AzWvdWorkspace @parameters` to create a new workspace in an azure region.
- `Get-AzWvdWorkspace` to get workspace info.

### Create Application Group
- When creating an **Application Group**, the parameters include:
    - `Subscription/Resource Group`
    - `Host pool`: Select a Host pool.
    - `Location`: Metadata is stored in same location as host pool.
    - `Application group type`: Desktop or RemoteApp. If RemoteApp optionally:
        - `Add applications`: At least one session host must be available.
            - `Assignments`: Add Entra users and groups.
        - `Workspace`: Optional, if Yes:
            - `Register application group`: to a workspace from the list.
    - `Application group name`: i.e. "Session Desktop"
    - `Advanced`: Diagnostics and LA details here.

- `New-AzWvdApplicationGroup @parameters` and include HostpoolArmPath, ApplicationGroupType, ApplicationGroupName, Location.
- `Get-AzWvdApplicationGroup`

### Add Application Group to Workspace
- Add an Application group to a workspace from the Workspace tab.
- `Update-AzWvdWorkspace -ApplicationGroupReference $appGroupPath` where appgrouppath is the `.Id` of the app group.

### Assign Users to an application group
- `Microsoft.Authorization/roleAssignments/write` permission (User Access Administrator or Owner) is needed.
- From the Applications groups tab, select `Assignments`.
- `NewAzRoleAssignment @parameters` where `-SignInName = $UserPrincipalName` and `-ResourceType = Microsoft.DesktopVirtualization/applicationGroups`
- Using `az desktopvirtualization application group show` to get the scope as `$appGroupPath`

### Configure FSLogix Profile Containers
- You need `AzFilesHybrid` PS module for your AD joined file share.
- Configure AD DS or Entra Domain services on the file share.
- Need Storage Account Owner, Contributor, or Owner and `Join-AzStorageAccount`
- With `Storage File Data SMB Share Contributor`, assign from **Storage Account -> IAM -> Users/Groups**.
- Configure profile settings of session host: 
    - Set **NTFS permissions for share** with `net use <DRIVE_LETTER>: \\storage1.file.core.windows.net.. <SA Access Key> /user:Azure\storage1`
    - `/ grant` domain groups and `/remove` BUILTin\Users
    - Run `FSLogixAppsSetup.exe` from elevated powershell with 
        - regpath: `HKLM:\SOFTWARE\FSLogix\profiles`
        - Name: VHDLocations
        - Type: DWORD
        - Pass UNC path to storage account/share-name
- Restart the session host/VM
- Validate by seeing "Please wait for the FSLogix Apps Sevices"
- Validate by viewing user profile in share.

### Install and Configure apps on a session host
- You can use **MSIX app attach or App Attach** to stream an app as a RemoteApp in an Application group or to appear in the start menu for a Desktop Application group.
- For RemoteApp applications:
    - You need an SMB file share in the *same azure region* as session hosts.
        - All session hosts need read acces.
    - For Entra joined hosts, you need `Reader and Data Access` on the `Azure Virtual Desktop` and `Azure Virtual Desktop ARM Provider` **Service Principals**.
    - `Desktop Virtualization Contributor` role on the RG/Sub.
    - Select `App attach` from the AVD left blade and `+ Create`
        - On `Basics` tab
            - choose Sub/RG
            - Host Pool
            - Location
    - `Image Path` tab:
        - `Image path`: select from Azure Files or Input UNC.
        - `File share`: choose share and directory
        - `Display name`
        - `version`
        - `registration type`: 
            - **On-demand** (partial registration at signin, full registration at start of app)
            - **Log on blocking** (registration happens while user signs in)
        - `State`: initial state for package, active/inactive.
        - `Health check status on failure`: AppAttachHealthCheck
    - Go to `application groups` from AVD overview
    - Choose the RemoteApp group you want.
    - Select `Applications`.
    - From `Basics`, and application source dropdown choose `App attach` (instead of `Start menu` or `File path`)
    - Choose the application.

- Use `New/Update/Remove-AzWvdAppAttachPackage` and `Import-AzWvdAppAttachPackageInfo`

### AVD Client Configuration
- Turn off automatic client notifications using: 
    - Key: `HKLM\Software\Microsoft\MSRDC\Policies`
    - Type: `REG_DWORD`
    - Name: `AutomaticUpdates`
    - Data: `0` (can be `1` or `2`)

### Configure Insider Group
- An Insider Group for early validation and to catch issues early.
- New version of the client is released every patch-Tuesday.
    - Key: `HKLM\Software\Microsoft\MSRDC\Policies`
    - Type: `REG_SZ`
    - Name: `ReleaseRing`
    - Data: `Insider`

### Create a Golden Image in Azure

Steps using the portal:
- Find a managed image by searching `Images` and select `Create virtual machine` from dropdown.
- Select a `size`
    - If using local (hyper-v manager), disable checkpoints.
    - If you create from existing VHD, it creates a dynamic disk by default, this needs to be changed with `Convert-VHD -VHDType Fixed` or `Edit Disk` from the portal.
- If created locally (hyper-v manager), upload to blob storage in azure as VHD Fixed.
- One managed image supports up to 20 simultaneous deployments (Use a `Shared Image Gallery` configured with 1 replica/20 concurrent deployments if you need more)

### Using Azure VM Image Builder and Distribute using Azure Compute Gallery
- Ensure using `Get-AzResourceProvider` that namespaces for `VirtualMachineImages`, Storage, Compute, KeyVault, ContainerInstance are registered.
- Specify a source for the image, a customization, and a published location.
- A *staging RG* is created for the image template resource `IT_\RG\TemplateName\GUID`
- VM Image Builder connects to VM using SSH or WinRM.
- Image builder supports a `customize` section in Bicep for your VM customizers, including shell, WindowsUpdate, File, etc.
- Extended support for `TrustedLaunchSupported` and `ConfidentialVMSupported` source images ONLY.
- Create an Azure Compute/Shared Image Gallery `New-AzGallery`
- Create a gallery definition: `New-AzGalleryImageDefinition -OsState generalized`
- Use `Get-AzImageBuilderTemplate` to check for errors with `.ProvisioningErrorMessage`
- Build the image using `Start-AzImageBuilderTemplate`
- Create the VM using `New-AzVM`

### Assign an App Attach package to Host Pool and Group/Users
- For **Host Pools**:
    - go to `App Attach` from AVD left blade.
    - Choose `Manage`: `Host pools`
    - find the name of the app and `+ Assign` to host pools.
- For **Groups and users**:
     - go to `App Attach` from AVD left blade.
     - Choose `Manage`: `Users`
     - `+ Add` Users and or groups.

- **Note** adding a package, setting active, assigning to host pool and users makes it available instantly on desktop sessions.

- Can use `Update-AzWvdAppAttachPackage -HostPoolReference <Host Pool IDs>`
- Use `Update-AzWvdAppAttachPackage -IsRegularRegistration $true` == "register at login".

### Publish an MSIX/Appx app to a RemoteApp application group
- From Applicaition groups in AVD, select the RemoteApp group you want.
- Select `Applications` and `+ Add`
    - `Application source`: App Attach
    - `Package`: Select package available from drop down
    - `Application`: choose one
    - `Application identifier`: unique
    - `Display name`: friendly name
- On `Icon` tab: 
    - Choose Azure Files or UNC path:
    - Choose Default or file path for custom Icon.

### Update an App attach package
- From the AVD overview, select App attach
    - Choose the package and select `Update`
    - Select `Host pool` to update the package for.
    - Choose `Storage` or `Input UNC` and choose path.
    - Press `Update`
- Using Powershell: `Import-AzWvdAppAttachPackageInfo -Path`

### Recommended to Disable automatic MSIX AppX updates

Update Session hosts registry values to disable the following:

- `HKLM\Software\Policies\Microsoft\WindowsStore`
    - Type: DWORD
    - Name: AutoDownload
    - Value: 2
- `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
    - Type: DWORD
    - Name: PreInstalledAppsEnabled
    - Value: 0
- `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Debug`
    - Type: DWORD
    - Name: ContentDeliveryAllowedOverride
    - Value: 2

- **Note** you can publish a `Windows Sandbox` to run apps in isolation.

### Implement and Manage OneDrive
- By default **OneDrive** syncs apps per-user, but there is a `per-machine installation` option.
- Download OneDriveSetup.exe and run `onedrivesetup.exe /allusers`
    - Onedrive is now installed under "Program Files" instead of localappdata.
- Verify with `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\OneDrive` Type `REG_SZ` registry detection rule.

### Implement Microsoft Teams for Remote Desktop
- Enable media optimization for teams:
    - Set registry value: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Teams`
        - Type: DWORD
        - Name: IsWVDEnvironment
    - Install Remote Desktop WebRTC Redirector service on each session host (socket service).
    - Install Teams on each session host (Pooled requires per-machine)
- To enable optional features, edit other Registry Keys
    - `HKCU\SOFTWARE\Microsoft\Terminal Server Client\Default\AddIns\WebRTC Redirector`
        - UseHardwareEncoding.
        - ShareClientDesktop.
        - DisableRAILScreensharing.
        - DisableRAILAppSharing.

### Configure Dynamic apps using App Attach
Prerequisites:
- Your host pool should be configured as a **Validation Environment**.
- Can be VHD, VHDX, or CIM (preferred) app attach disk image.
    - File formats supported are .msix, .msixbundle, .appx, .appxbundle
    - Use the MSIXMGR tool to create an MSIX image.
- Session Hosts need to be domain joined.
- You need an SMB file share in the *same azure region* as session hosts.
    - All session hosts need read acces.
    - `Reader and Data Access` role assigned to Azure Virtual Desktop and Azure Virtual Desktop ARM Provider *service principals*.
- You need `Desktop Virtualization Contributor` on at least the RG to add MSIX images.

Steps to add MSIX or AppX app attach package:
- Azure Virtual Desktop overview blade.
- Select `App Attach` and `+ Create`
- Under `Basics`:
    - `Subscription/RG`
    - `Host pool`
    - `Location`
- Select `Next`
    - `Image path`:
    - From here, assign to `Host pools` or `Groups/Users`

**Note**: A user gets an application when:
1) Application is assigned to host pool.
2) User is able to sign into session hosts.
3) Application is assigned to user/group.

### Install Language packs
- Custom image from Windows 10/11 Enterprise multi-session is required to add multiple languages.
- You need the `Language ISO`, `Feature on Demand (FOD) Disk 1`, `Inbox Apps ISO`
- `Azure Files Share` OR a `Windows File Server VM` (must be accessible from VM you plan to create your custom image from)
    - Disable Language pack cleanup with `Disable-ScheduledTask ... -TaskName "Pre-staged app cleanup"`
    - After downloading the apps and language packs, copy content from `LocalExperiencePacks` and `x64\langpacks` folders into file share.
    - Set permissions on the language content repository for read access from VM that you will build custom image with.
    - Finish customization with `sysprep tool`: `sysprep.exe /oobe /generalize /shutdown`.
    - Stop the VM then `capture` it. (must be generalized for host pool)
- Verify with `Get-WinUserLanguageList` and `Set-WinUserLanguageList` with options like `"es-es"`, `"fr-fr"`.

### Subscribe to a workspace from Remote Desktop Client
- From Web browser, `https://client.wvd.microsoft.com/arm/webclient`
- Open `Remote Desktop` app on your device.
    - `Subscribe` or `Subscribe with URL`: either input `user@domain.com` or `https://rdweb.wvd.microsoft.com`
- Once subscribed, its content will be updated automatically.