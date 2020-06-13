---
type: howto
---

# Installing GitLab HA on Amazon Web Services (AWS)

DANGER: **Danger:** This guide is under review and the steps below will be revised and updated in due time. For more detail, please see [this epic](https://gitlab.com/groups/gitlab-org/-/epics/912).

This page offers a walkthrough of a common HA (Highly Available) configuration
for GitLab on AWS. You should customize it to accommodate your needs.

NOTE: **Note**
For organizations with 300 users or less, the recommended AWS installation method is to launch an EC2 single box [Omnibus Installation](https://about.gitlab.com/install/) and implement a snapshot strategy for backing up the data.

## Introduction

GitLab on AWS can leverage many of the services that are already
configurable with GitLab High Availability (HA). These services offer a great deal of
flexibility and can be adapted to the needs of most companies, while enabling the
automation of both vertical and horizontal scaling.

In this guide, we'll go through a basic HA setup where we'll start by
configuring our Virtual Private Cloud and subnets to later integrate
services such as RDS for our database server and ElastiCache as a Redis
cluster to finally manage them within an auto scaling group with custom
scaling policies.

## Requirements

In addition to having a basic familiarity with [AWS](https://docs.aws.amazon.com/) and [Amazon EC2](https://docs.aws.amazon.com/ec2/), you will need:

- [An AWS account](https://console.aws.amazon.com/console/home)
- [To create or upload an SSH key](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
  to connect to the instance via SSH
- A domain name for the GitLab instance
- An SSL/TLS certificate to secure your domain. If you do not already own one, you can provision a free public SSL/TLS certificate through [AWS Certificate Manager](https://aws.amazon.com/certificate-manager/)(ACM) for use with the [Elastic Load Balancer](#load-balancer) we'll create.

NOTE: **Note:** It can take a few hours to validate a certificate provisioned through ACM. To avoid delays later, request your certificate as soon as possible.

## Architecture

Below is a diagram of the recommended architecture.

![AWS architecture diagram](img/aws_ha_architecture_diagram.png)

## AWS costs

Here's a list of the AWS services we will use, with links to pricing information:

- **EC2**: GitLab will deployed on shared hardware which means
  [on-demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
  will apply. If you want to run it on a dedicated or reserved instance,
  consult the [EC2 pricing page](https://aws.amazon.com/ec2/pricing/) for more
  information on the cost.
- **S3**: We will use S3 to store backups, artifacts, LFS objects, etc. See the
  [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/).
- **ELB**: A Classic Load Balancer will be used to route requests to the
  GitLab instances. See the [Amazon ELB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/).
- **RDS**: An Amazon Relational Database Service using PostgreSQL will be used
  to provide a High Availability database configuration. See the
  [Amazon RDS pricing](https://aws.amazon.com/rds/postgresql/pricing/).
- **ElastiCache**: An in-memory cache environment will be used to provide a
  High Availability Redis configuration. See the
  [Amazon ElastiCache pricing](https://aws.amazon.com/elasticache/pricing/).

NOTE: **Note:** Please note that while we will be using EBS for storage, we do not recommend using EFS as it may negatively impact GitLab's performance. You can review the [relevant documentation](../../administration/high_availability/nfs.md#avoid-using-awss-elastic-file-system-efs) for more details.

## Creating an IAM EC2 instance role and profile

To minimize the permissions of the user, we'll create a new [IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
role with limited access:

1. Navigate to the IAM dashboard <https://console.aws.amazon.com/iam/home> and
   click **Create role**.
1. Create a new role by selecting **AWS service > EC2**, then click
   **Next: Permissions**.
1. Choose **AmazonEC2FullAccess** and **AmazonS3FullAccess**, then click **Next: Review**.
1. Give the role the name `GitLabAdmin` and click **Create role**.

## Configuring the network

We'll start by creating a VPC for our GitLab cloud infrastructure, then
we can create subnets to have public and private instances in at least
two [Availability Zones (AZs)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html). Public subnets will require a Route Table keep and an associated
Internet Gateway.

### Creating the Virtual Private Cloud (VPC)

We'll now create a VPC, a virtual networking environment that you'll control:

1. Navigate to <https://console.aws.amazon.com/vpc/home>.
1. Select **Your VPCs** from the left menu and then click **Create VPC**.
   At the "Name tag" enter `gitlab-vpc` and at the "IPv4 CIDR block" enter
   `10.0.0.0/16`. If you don't require dedicated hardware, you can leave
   "Tenancy" as default. Click **Yes, Create** when ready.

   ![Create VPC](img/create_vpc.png)

### Subnets

Now, let's create some subnets in different Availability Zones. Make sure
that each subnet is associated to the VPC we just created and
that CIDR blocks don't overlap. This will also
allow us to enable multi AZ for redundancy.

We will create private and public subnets to match load balancers and
RDS instances as well:

1. Select **Subnets** from the left menu.
1. Click **Create subnet**. Give it a descriptive name tag based on the IP,
   for example `gitlab-public-10.0.0.0`, select the VPC we created previously,
   and at the IPv4 CIDR block let's give it a 24 subnet `10.0.0.0/24`:

   ![Create subnet](img/create_subnet.png)

1. Follow the same steps to create all subnets:

   | Name tag                  | Type    | Availability Zone | CIDR block |
   | ------------------------- | ------- | ----------------- | ---------- |
   | `gitlab-public-10.0.0.0`  | public  | `us-west-2a`      | `10.0.0.0` |
   | `gitlab-private-10.0.1.0` | private | `us-west-2a`      | `10.0.1.0` |
   | `gitlab-public-10.0.2.0`  | public  | `us-west-2b`      | `10.0.2.0` |
   | `gitlab-private-10.0.3.0` | private | `us-west-2b`      | `10.0.3.0` |

### Route Table

Up to now all our subnets are private. We need to create a Route Table
to associate an Internet Gateway. On the same VPC dashboard:

1. Select **Route Tables** from the left menu.
1. Click **Create Route Table**.
1. At the "Name tag" enter `gitlab-public` and choose `gitlab-vpc` under "VPC".
1. Hit **Yes, Create**.

### Internet Gateway

Now, still on the same dashboard, go to Internet Gateways and
create a new one:

1. Select **Internet Gateways** from the left menu.
1. Click **Create internet gateway**, give it the name `gitlab-gateway` and
   click **Create**.
1. Select it from the table, and then under the **Actions** dropdown choose
   "Attach to VPC".

   ![Create gateway](img/create_gateway.png)

1. Choose `gitlab-vpc` from the list and hit **Attach**.

### Configuring subnets

We now need to add a new target which will be our Internet Gateway and have
it receive traffic from any destination.

1. Select **Route Tables** from the left menu and select the `gitlab-public`
   route to show the options at the bottom.
1. Select the **Routes** tab, hit **Edit > Add another route** and set `0.0.0.0/0`
   as destination. In the target, select the `gitlab-gateway` we created previously.
   Hit **Save** once done.

   ![Associate subnet with gateway](img/associate_subnet_gateway.png)

Next, we must associate the **public** subnets to the route table:

1. Select the **Subnet Associations** tab and hit **Edit**.
1. Check only the public subnet and hit **Save**.

   ![Associate subnet with gateway](img/associate_subnet_gateway_2.png)

---

Now that we're done with the network, let's create a security group.

## Creating a security group

The security group is basically the firewall:

1. Select **Security Groups** from the left menu.
1. Click **Create Security Group** and fill in the details. Give it a name,
   add a description, and choose the VPC we created previously
1. Select the security group from the list and at the bottom select the
   Inbound Rules tab. You will need to open the SSH, HTTP, and HTTPS ports. Set
   the source to `0.0.0.0/0`.

   ![Create security group](img/create_security_group.png)

   TIP: **Tip:**
   Based on best practices, you should allow SSH traffic from only a known
   host or CIDR block. In that case, change the SSH source to be custom and give
   it the IP you want to SSH from.

1. When done, click **Save**.

## PostgreSQL with RDS

For our database server we will use Amazon RDS which offers Multi AZ
for redundancy. Let's start by creating a subnet group and then we'll
create the actual RDS instance.

### RDS Subnet Group

1. Navigate to the RDS dashboard and select **Subnet Groups** from the left menu.
1. Click on **Create DB Subnet Group**.
1. Under **Subnet group details**, enter a name (we'll use `gitlab-rds-group`), a description, and choose the `gitlab-vpc` from the VPC dropdown.
1. Under **Add subnets**, click **Add all the subnets related to this VPC** and remove the public ones, we only want the **private subnets**. In the end, you should see `10.0.1.0/24` and `10.0.3.0/24` (as we defined them in the [subnets section](#subnets)).
1. Click **Create** when ready.

   ![RDS Subnet Group](img/rds_subnet_group.png)

### Creating the database

Now, it's time to create the database:

1. Select **Databases** from the left menu and click **Create database**.
1. Select **Standard Create** for the database creation method.
1. Select **PostgreSQL** as the database engine and select **PostgreSQL 10.9-R1** from the version dropdown menu (check the [database requirements](../../install/requirements.md#postgresql-requirements) to see if there are any updates on this for your chosen version of GitLab).
1. Since this is a production server, let's choose **Production** from the **Templates** section.
1. Under **Settings**, set a DB instance identifier, a master username, and a master password. We'll use `gitlab-db-ha`, `gitlab`, and a very secure password respectively. Make a note of these as we'll need them later.
1. For the DB instance size, select **Standard classes** and select an instance size that meets your requirements from the dropdown menu. We'll use a `db.m4.large` instance.
1. Under **Storage**, configure the following:
   1. Select **Provisioned IOPS (SSD)** from the storage type dropdown menu. Provisioned IOPS (SSD) storage is best suited for HA (though you can choose General Purpose (SSD) to reduce the costs). Read more about it at [Storage for Amazon RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html).
   1. Allocate storage and set provisioned IOPS. We'll use the minimum values, `100` and `1000`, respectively.
   1. Enable storage autoscaling (optional) and set a maximum storage threshold.
1. Under **Availability & durability**, select **Create a standby instance** to have a standby RDS instance provisioned in a different Availability Zone. Read more at [High Availability (Multi-AZ)](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html).
1. Under **Connectivity**, configure the following:
   1. Select the VPC we created earlier (`gitlab-vpc`) from the **Virtual Private Cloud (VPC)** dropdown menu.
   1. Expand the **Additional connectivity configuration** section and select the subnet group (`gitlab-rds-group`) we created earlier.
   1. Set public accessibility to **No**.
   1. Under **VPC security group**, select **Create new** and enter a name. We'll use `gitlab-rds-sec-group`.
   1. Leave the database port as the default `5432`.
1. For **Database authentication**, select **Password authentication**.
1. Expand the **Additional configuration** section and complete the following:
   1. The initial database name. We'll use `gitlabhq_production`.
   1. Configure your preferred backup settings.
   1. The only other change we'll make here is to disable auto minor version updates under **Maintenance**.
   1. Leave all the other settings as is or tweak according to your needs.
   1. Once you're happy, click **Create database**.

Now that the database is created, let's move on to setting up Redis with ElastiCache.

## Redis with ElastiCache

ElastiCache is an in-memory hosted caching solution. Redis maintains its own
persistence and is used for certain types of the GitLab application.

To set up Redis:

1. Navigate to the ElastiCache dashboard from your AWS console.
1. Go to **Subnet Groups** in the left menu, and create a new subnet group.
   Make sure to select our VPC and its [private subnets](#subnets). Click
   **Create** when ready.

   ![ElastiCache subnet](img/ec_subnet.png)

1. Select **Redis** on the left menu and click **Create** to create a new
   Redis cluster. Depending on your load, you can choose whether to enable
   cluster mode or not. Even without cluster mode on, you still get the
   chance to deploy Redis in multi availability zones. In this guide, we chose
   not to enable it.
1. In the settings section:
   1. Give the cluster a name (`gitlab-redis`) and a description.
   1. For the version, select the latest of `3.2` series (e.g., `3.2.10`).
   1. Select the node type and the number of replicas.
1. In the advanced settings section:
   1. Select the multi-AZ auto-failover option.
   1. Select the subnet group we created previously.
   1. Manually select the preferred availability zones, and under "Replica 2"
      choose a different zone than the other two.

      ![Redis availability zones](img/ec_az.png)

1. In the security settings, edit the security groups and choose the
   `gitlab-security-group` we had previously created.
1. Leave the rest of the settings to their default values or edit to your liking.
1. When done, click **Create**.

## RDS and Redis Security Group

Let's navigate to our EC2 security groups and add a small change for our EC2
instances to be able to connect to RDS. First, copy the security group name we
defined, namely `gitlab-security-group`, select the RDS security group and edit the
inbound rules. Choose the rule type to be PostgreSQL and paste the name under
source.

Similar to the above, jump to the `gitlab-security-group` group
and add a custom TCP rule for port `6379` accessible within itself.

## Load Balancer

On the EC2 dashboard, look for Load Balancer in the left navigation bar:

1. Click the **Create Load Balancer** button.
   1. Choose the **Classic Load Balancer**.
   1. Give it a name (we'll use `gitlab-loadbalancer`) and for the **Create LB Inside** option, select `gitlab-vpc` from the dropdown menu.
   1. In the **Listeners** section, set HTTP port 80, HTTPS port 443, and TCP port 22 for both load balancer and instance protocols and ports.
   1. In the **Select Subnets** section, select both public subnets from the list.
1. Click **Assign Security Groups** and select **Create a new security group**, give it a name
   (we'll use `gitlab-loadbalancer-sec-group`) and description, and allow both HTTP and HTTPS traffic
   from anywhere (`0.0.0.0/0, ::/0`).
1. Click **Configure Security Settings** and select an SSL/TLS certificate from ACM or upload a certificate to IAM.
1. Click **Configure Health Check** and set up a health check for your EC2 instances.
   1. For **Ping Protocol**, select HTTP.
   1. For **Ping Port**, enter 80.
   1. For **Ping Path**, enter `/explore`. (We use `/explore` as it's a public endpoint that does
   not require authorization.)
   1. Keep the default **Advanced Details** or adjust them according to your needs.
1. Click **Add EC2 Instances** but, as we don't have any instances to add yet, come back
to your load balancer after creating your GitLab instances and add them.
1. Click **Add Tags** and add any tags you need.
1. Click **Review and Create**, review all your settings, and click **Create** if you're happy.

After the Load Balancer is up and running, you can revisit your Security
Groups to refine the access only through the ELB and any other requirements
you might have.

### Configure DNS for Load Balancer

On the Route 53 dashboard, click **Hosted zones** in the left navigation bar:

1. Select an existing hosted zone or, if you do not already have one for your domain, click **Create Hosted Zone**, enter your domain name, and click **Create**.
1. Click **Create Record Set** and provide the following values:
    1. **Name:** Use the domain name (the default value) or enter a subdomain.
    1. **Type:** Select **A - IPv4 address**.
    1. **Alias Target:** Find the **ELB Classic Load Balancers** section and select the classic load balancer we created earlier.
    1. **Routing Policy:** We'll use **Simple** but you can choose a different policy based on your use case.
    1. **Evaluate Target Health:** We'll set this to **No** but you can choose to have the load balancer route traffic based on target health.
    1. Click **Create**.
1. Update your DNS records with your domain registrar. The steps for doing this vary depending on which registrar you use and is beyond the scope of this guide.

## Setting up Bastion Hosts

Since our GitLab instances will be in private subnets, we need a way to connect to these instances via SSH to make configuration changes, perform upgrades, etc. One way of doing this is via a [bastion host](https://en.wikipedia.org/wiki/Bastion_host), sometimes also referred to as a jump box.

TIP: **Tip:** If you do not want to maintain bastion hosts, you can set up [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) for access to instances. This is beyond the scope of this document.

### Create Bastion Host A

1. Navigate to the EC2 Dashboard and click on **Launch instance**.
1. Select the **Ubuntu Server 18.04 LTS (HVM)** AMI.
1. Choose an instance type. We'll use a `t2.micro` as we'll only use the bastion host to SSH into our other instances.
1. Click **Configure Instance Details**.
   1. Under **Network**, select the `gitlab-vpc` from the dropdown menu.
   1. Under **Subnet**, select the public subnet we created earlier (`gitlab-public-10.0.0.0`).
   1. Double check that under **Auto-assign Public IP** you have **Use subnet setting (Enable)** selected.
   1. Leave everything else as default and click **Add Storage**.
1. For storage, we'll leave everything as default and only add an 8GB root volume. We won't store anything on this instance.
1. Click **Add Tags** and on the next screen click **Add Tag**.
   1. We’ll only set `Key: Name` and `Value: Bastion Host A`.
1. Click **Configure Security Group**.
   1. Select **Create a new security group**, enter a **Security group name** (we'll use `bastion-sec-group`), and add a description.
   1. We'll enable SSH access from anywhere (`0.0.0.0/0`). If you want stricter security, specify a single IP address or an IP address range in CIDR notation.
   1. Click **Review and Launch**
1. Review all your settings and, if you're happy, click **Launch**.
1. Acknowledge that you have access to an existing key pair or create a new one. Click **Launch Instance**.

Confirm that you can SSH into the instance:

1. On the EC2 Dashboard, click on **Instances** in the left menu.
1. Select **Bastion Host A** from your list of instances.
1. Click **Connect** and follow the connection instructions.
1. If you are able to connect successfully, let's move on to setting up our second bastion host for redundancy.

### Create Bastion Host B

1. Create an EC2 instance following the same steps as above with the following changes:
   1. For the **Subnet**, select the second public subnet we created earlier (`gitlab-public-10.0.2.0`).
   1. Under the **Add Tags** section, we’ll set `Key: Name` and `Value: Bastion Host B` so that we can easily identify our two instances.
   1. For the security group, select the existing `bastion-sec-group` we created above.

### Use SSH Agent Forwarding

EC2 instances running Linux use private key files for SSH authentication. You'll connect to your bastion host using an SSH client and the private key file stored on your client. Since the private key file is not present on the bastion host, you will not be able to connect to your instances in private subnets.

Storing private key files on your bastion host is a bad idea. To get around this, use SSH agent forwarding on your client. See [Securely Connect to Linux Instances Running in a Private Amazon VPC](https://aws.amazon.com/blogs/security/securely-connect-to-linux-instances-running-in-a-private-amazon-vpc/) for a step-by-step guide on how to use SSH agent forwarding.

## Deploying GitLab inside an auto scaling group

We'll use AWS's wizard to deploy GitLab and then SSH into the instance to
configure the PostgreSQL and Redis connections.

The Auto Scaling Group option is available through the EC2 dashboard on the left
sidebar.

1. Click **Create Auto Scaling group**.
1. Create a new launch configuration.

### Choose the AMI

Choose the AMI:

1. Go to the Community AMIs and search for `GitLab EE <version>`
   where `<version>` the latest version as seen on the
   [releases page](https://about.gitlab.com/releases/).

   ![Choose AMI](img/choose_ami.png)

### Choose an instance type

You should choose an instance type based on your workload. Consult
[the hardware requirements](../requirements.md#hardware-requirements) to choose
one that fits your needs (at least `c5.xlarge`, which is enough to accommodate 100 users):

1. Choose the your instance type.
1. Click **Next: Configure Instance Details**.

### Configure details

In this step we'll configure some details:

1. Enter a name (`gitlab-autoscaling`).
1. Select the IAM role we created.
1. Optionally, enable CloudWatch and the EBS-optimized instance settings.
1. In the "Advanced Details" section, set the IP address type to
   "Do not assign a public IP address to any instances."
1. Click **Next: Add Storage**.

### Add storage

The root volume is 8GB by default and should be enough given that we won't store any data there.

### Configure security group

As a last step, configure the security group:

1. Select the existing load balancer security group we have [created](#load-balancer).
1. Select **Review**.

### Review and launch

Now is a good time to review all the previous settings. When ready, click
**Create launch configuration** and select the SSH key pair with which you will
connect to the instance.

### Create Auto Scaling Group

We are now able to start creating our Auto Scaling Group:

1. Give it a group name.
1. Set the group size to 2 as we want to always start with two instances.
1. Assign it our network VPC and add the **private subnets**.
1. In the "Advanced Details" section, choose to receive traffic from ELBs
   and select our ELB.
1. Choose the ELB health check.
1. Click **Next: Configure scaling policies**.

This is the really great part of Auto Scaling; we get to choose when AWS
launches new instances and when it removes them. For this group we'll
scale between 2 and 4 instances where one instance will be added if CPU
utilization is greater than 60% and one instance is removed if it falls
to less than 45%.

![Auto scaling group policies](img/policies.png)

Finally, configure notifications and tags as you see fit, and create the
auto scaling group.

You'll notice that after we save the configuration, AWS starts launching our two
instances in different AZs and without a public IP which is exactly what
we intended.

## After deployment

After a few minutes, the instances should be up and accessible via the internet.
Let's connect to the primary and configure some things before logging in.

### Installing the `pg_trgm` extension for PostgreSQL

Connect to the RDS instance to verify access and to install the required `pg_trgm` extension.

To find the host or endpoint, naviagate to **Amazon RDS > Databases** and click on the database you created earlier. Look for the endpoint under the **Connectivity & security** tab.

Do not to include the colon and port number:

```shell
sudo /opt/gitlab/embedded/bin/psql -U gitlab -h <rds-endpoint> -d gitlabhq_production
```

At the psql prompt create the extension and then quit the session:

```shell
psql (10.9)
Type "help" for help.

gitlab=# CREATE EXTENSION pg_trgm;
gitlab=# \q
```

---

### Configuring GitLab to connect with postgres and Redis

Edit the `gitlab.rb` file at `/etc/gitlab/gitlab.rb`
find the `external_url 'http://gitlab.example.com'` option and change it
to the domain you will be using or the public IP address of the current
instance to test the configuration.

For a more detailed description about configuring GitLab, see [Configuring GitLab for HA](../../administration/high_availability/gitlab.md)

Now look for the GitLab database settings and uncomment as necessary. In
our current case we'll specify the database adapter, encoding, host, name,
username, and password:

```ruby
# Disable the built-in Postgres
postgresql['enable'] = false

# Fill in the connection details
gitlab_rails['db_adapter'] = "postgresql"
gitlab_rails['db_encoding'] = "unicode"
gitlab_rails['db_database'] = "gitlabhq_production"
gitlab_rails['db_username'] = "gitlab"
gitlab_rails['db_password'] = "mypassword"
gitlab_rails['db_host'] = "<rds-endpoint>"
```

Next, we need to configure the Redis section by adding the host and
uncommenting the port:

```ruby
# Disable the built-in Redis
redis['enable'] = false

# Fill in the connection details
gitlab_rails['redis_host'] = "<redis-endpoint>"
gitlab_rails['redis_port'] = 6379
```

Finally, reconfigure GitLab for the change to take effect:

```shell
sudo gitlab-ctl reconfigure
```

You might also find it useful to run a check and a service status to make sure
everything has been setup correctly:

```shell
sudo gitlab-rake gitlab:check
sudo gitlab-ctl status
```

If everything looks good, you should be able to reach GitLab in your browser.

### Setting up Gitaly

CAUTION: **Caution:** In this architecture, having a single Gitaly server creates a single point of failure. This limitation will be removed once [Gitaly HA](https://gitlab.com/groups/gitlab-org/-/epics/842) is released.

Gitaly is a service that provides high-level RPC access to Git repositories.
It should be enabled and configured on a separate EC2 instance in one of the
[private subnets](#subnets) we configured previously.

Let's create an EC2 instance where we'll install Gitaly:

1. From the EC2 dashboard, click **Launch instance**.
1. Choose an AMI. In this example, we'll select the **Ubuntu Server 18.04 LTS (HVM), SSD Volume Type**.
1. Choose an instance type. We'll pick a **c5.xlarge**.
1. Click **Configure Instance Details**.
   1. In the **Network** dropdown, select `gitlab-vpc`, the VPC we created earlier.
   1. In the **Subnet** dropdown, select `gitlab-private-10.0.1.0` from the list of subnets we created earlier.
   1. Double check that **Auto-assign Public IP** is set to `Use subnet setting (Disable)`.
   1. Click **Add Storage**.
1. Increase the Root volume size to `20 GiB` and change the **Volume Type** to `Provisoned IOPS SSD (io1)`. (This is an arbitrary size. Create a volume big enough for your repository storage requirements.)
   1. For **IOPS** set `1000` (20 GiB x 50 IOPS). You can provision up to 50 IOPS per GiB. If you select a larger volume, increase the IOPS accordingly. Workloads where many small files are written in a serialized manner, like `git`, requires performant storage, hence the choice of `Provisoned IOPS SSD (io1)`.
1. Click on **Add Tags** and add your tags. In our case, we'll only set `Key: Name` and `Value: Gitaly`.
1. Click on **Configure Security Group** and let's **Create a new security group**.
   1. Give your security group a name and description. We'll use `gitlab-gitaly-sec-group` for both.
   1. Create a **Custom TCP** rule and add port `8075` to the **Port Range**. For the **Source**, select the `gitlab-loadbalancer-sec-group`.
1. Click **Review and launch** followed by **Launch** if you're happy with your settings.
1. Finally, acknowledge that you have access to the selected private key file or create a new one. Click **Launch Instances**.

  > **Optional:** Instead of storing configuration _and_ repository data on the root volume, you can also choose to add an additional EBS volume for repository storage. Follow the same guidance as above. See the [Amazon EBS pricing](https://aws.amazon.com/ebs/pricing/).

Now that we have our EC2 instance ready, follow the [documentation to install GitLab and set up Gitaly on its own server](../../administration/gitaly/index.md#running-gitaly-on-its-own-server).

### Using Amazon S3 object storage

GitLab stores many objects outside the Git repository, many of which can be
uploaded to S3. That way, you can offload the root disk volume of these objects
which would otherwise take much space.

In particular, you can store in S3:

- [The Git LFS objects](../../administration/lfs/lfs_administration.md#s3-for-omnibus-installations) ((Omnibus GitLab installations))
- [The Container Registry images](../../administration/packages/container_registry.md#container-registry-storage-driver) (Omnibus GitLab installations)
- [The GitLab CI/CD job artifacts](../../administration/job_artifacts.md#using-object-storage) (Omnibus GitLab installations)

### Setting up a domain name

After you SSH into the instance, configure the domain name:

1. Open `/etc/gitlab/gitlab.rb` with your preferred editor.
1. Edit the `external_url` value:

   ```ruby
   external_url 'http://example.com'
   ```

1. Reconfigure GitLab:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

You should now be able to reach GitLab at the URL you defined. To use HTTPS
(recommended), see the [HTTPS documentation](https://docs.gitlab.com/omnibus/settings/nginx.html#enable-https).

### Logging in for the first time

If you followed the previous section, you should be now able to visit GitLab
in your browser. The very first time, you will be asked to set up a password
for the `root` user which has admin privileges on the GitLab instance.

After you set it up, login with username `root` and the newly created password.

## Health check and monitoring with Prometheus

Apart from Amazon's Cloudwatch which you can enable on various services,
GitLab provides its own integrated monitoring solution based on Prometheus.
For more information on how to set it up, visit the
[GitLab Prometheus documentation](../../administration/monitoring/prometheus/index.md)

GitLab also has various [health check endpoints](../..//user/admin_area/monitoring/health_check.md)
that you can ping and get reports.

## GitLab Runners

If you want to take advantage of [GitLab CI/CD](../../ci/README.md), you have to
set up at least one [GitLab Runner](https://docs.gitlab.com/runner/).

Read more on configuring an
[autoscaling GitLab Runner on AWS](https://docs.gitlab.com/runner/configuration/runner_autoscale_aws/).

## Backup and restore

GitLab provides [a tool to backup](../../raketasks/backup_restore.md#creating-a-backup-of-the-gitlab-system)
and restore its Git data, database, attachments, LFS objects, etc.

Some important things to know:

- The backup/restore tool **does not** store some configuration files, like secrets; you'll
  need to [configure this yourself](../../raketasks/backup_restore.md#storing-configuration-files).
- By default, the backup files are stored locally, but you can
  [backup GitLab using S3](../../raketasks/backup_restore.md#using-amazon-s3).
- You can [exclude specific directories form the backup](../../raketasks/backup_restore.md#excluding-specific-directories-from-the-backup).

### Backing up GitLab

To back up GitLab:

1. SSH into your instance.
1. Take a backup:

   ```shell
   sudo gitlab-backup create
   ```

NOTE: **Note**
For GitLab 12.1 and earlier, use `gitlab-rake gitlab:backup:create`.

### Restoring GitLab from a backup

To restore GitLab, first review the [restore documentation](../../raketasks/backup_restore.md#restore),
and primarily the restore prerequisites. Then, follow the steps under the
[Omnibus installations section](../../raketasks/backup_restore.md#restore-for-omnibus-gitlab-installations).

## Updating GitLab

GitLab releases a new version every month on the 22nd. Whenever a new version is
released, you can update your GitLab instance:

1. SSH into your instance
1. Take a backup:

   ```shell
   sudo gitlab-backup create
   ```

NOTE: **Note**
For GitLab 12.1 and earlier, use `gitlab-rake gitlab:backup:create`.

1. Update the repositories and install GitLab:

   ```shell
   sudo apt update
   sudo apt install gitlab-ee
   ```

After a few minutes, the new version should be up and running.

## Conclusion

In this guide, we went mostly through scaling and some redundancy options,
your mileage may vary.

Keep in mind that all Highly Available solutions come with a trade-off between
cost/complexity and uptime. The more uptime you want, the more complex the solution.
And the more complex the solution, the more work is involved in setting up and
maintaining it.

Have a read through these other resources and feel free to
[open an issue](https://gitlab.com/gitlab-org/gitlab/issues/new)
to request additional material:

- [GitLab High Availability](../../administration/high_availability/README.md):
  GitLab supports several different types of clustering and high-availability.
- [Geo replication](../../administration/geo/replication/index.md):
  Geo is the solution for widely distributed development teams.
- [Omnibus GitLab](https://docs.gitlab.com/omnibus/) - Everything you need to know
  about administering your GitLab instance.
- [Upload a license](../../user/admin_area/license.md):
  Activate all GitLab Enterprise Edition functionality with a license.
- [Pricing](https://about.gitlab.com/pricing/): Pricing for the different tiers.

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
