# OpenShift Version Management Guide

This guide explains how to select and manage OpenShift versions in the UPI automation.

## Quick Reference

### Recommended Versions

| Use Case | Version | Why |
|----------|---------|-----|
| **Production** | `stable-4.17` | Latest stable, thoroughly tested |
| **Testing** | `latest-4.17` | Newest features, may include pre-release |
| **Consistency** | `4.17.1` | Pin to specific version across environments |
| **Long-term** | `stable-4.16` | Older but stable, longer support |

## Version Format Options

### 1. Stable Channel (Recommended)

```bash
OPENSHIFT_VERSION="stable-4.17"
```

**Pros:**
- ✅ Latest stable release in the channel
- ✅ Production-ready and tested
- ✅ Automatic minor updates
- ✅ Recommended by Red Hat

**Cons:**
- ❌ Version may change over time
- ❌ Less predictable for strict compliance

**Best for:** Production deployments, Cloudera Data Services

### 2. Specific Version

```bash
OPENSHIFT_VERSION="4.17.1"
```

**Pros:**
- ✅ Exact version, fully predictable
- ✅ Consistent across all environments
- ✅ Easier change management
- ✅ Good for compliance requirements

**Cons:**
- ❌ Must manually update for patches
- ❌ May miss important security updates
- ❌ Requires more maintenance

**Best for:** Strict version control, regulated environments

### 3. Latest Channel

```bash
OPENSHIFT_VERSION="latest-4.17"
```

**Pros:**
- ✅ Newest features immediately
- ✅ Early access to improvements
- ✅ Good for testing

**Cons:**
- ❌ May include pre-release versions
- ❌ Not recommended for production
- ❌ Potential stability issues

**Best for:** Development, testing, early adoption

## Finding Versions

### Method 1: Interactive Helper (Easiest)

```bash
# Run the interactive selector
make version-select

# Or directly
./openshift-version-helper.sh select
```

This will:
1. Ask about your deployment type (production/testing/specific)
2. Show available versions
3. Help you get the matching RHCOS AMI
4. Generate configuration for config.env

### Method 2: Command Line

```bash
# List all available versions
make version-list

# Show details for a specific version
make version-details VERSION=stable-4.17

# Get RHCOS AMI for your region
make version-ami VERSION=stable-4.17 REGION=us-east-1

# Validate a version before using
./openshift-version-helper.sh validate stable-4.17
```

### Method 3: Manual Research

**OpenShift Versions:**
- Browse: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/
- Look for directories like: `4.17.1/`, `stable-4.17/`, `latest-4.17/`

**RHCOS AMIs:**
- Browse: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/
- Download the JSON file for your version
- Extract AMI for your region

## RHCOS AMI Matching

**CRITICAL:** Each OpenShift version requires a matching RHCOS AMI.

### Automatic AMI Lookup

```bash
# Get AMI for your version and region
./openshift-version-helper.sh ami stable-4.17 us-east-1
```

### Manual AMI Lookup

1. Determine RHCOS version from OpenShift version:
   - OpenShift 4.17.x → RHCOS 4.17
   - OpenShift 4.16.x → RHCOS 4.16

2. Visit: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.17/latest/

3. Download: `rhcos-aws.x86_64.json`

4. Extract AMI for your region:
   ```bash
   jq -r '.amis["us-east-1"].hvm' rhcos-aws.x86_64.json
   ```

## Version Examples

### Example 1: Production Deployment

```bash
# config.env
OPENSHIFT_VERSION="stable-4.17"
RHCOS_AMI="ami-0abc123def456789"  # From version helper
CLUSTER_NAME="prod-ocp"
# ... rest of config
```

### Example 2: Multiple Environments

**Development:**
```bash
OPENSHIFT_VERSION="latest-4.17"
RHCOS_AMI="ami-0abc123def456789"
CLUSTER_NAME="dev-ocp"
USE_REGISTRY_EMPTYDIR="true"
```

**Staging:**
```bash
OPENSHIFT_VERSION="4.17.1"  # Pin to specific
RHCOS_AMI="ami-0abc123def456789"
CLUSTER_NAME="stage-ocp"
USE_REGISTRY_EMPTYDIR="false"
```

**Production:**
```bash
OPENSHIFT_VERSION="stable-4.17"
RHCOS_AMI="ami-0abc123def456789"
CLUSTER_NAME="prod-ocp"
USE_REGISTRY_EMPTYDIR="false"
```

### Example 3: Specific Version for Compliance

```bash
# Lock to exact version for compliance
OPENSHIFT_VERSION="4.17.1"
RHCOS_AMI="ami-0abc123def456789"

# Document in compliance records:
# OpenShift: 4.17.1
# RHCOS: 417.94.202403210100-0
# Kubernetes: 1.30.1
```

## Version Upgrade Strategy

### Planning an Upgrade

1. **Check Current Version:**
   ```bash
   oc get clusterversion
   ```

2. **List Available Upgrades:**
   ```bash
   oc adm upgrade
   ```

3. **Select Target Version:**
   ```bash
   # Use the helper to validate
   ./openshift-version-helper.sh validate 4.17.2
   ```

4. **Update Configuration:**
   ```bash
   # In config.env
   OPENSHIFT_VERSION="4.17.2"  # New version
   RHCOS_AMI="ami-0xyz..."     # Updated AMI
   ```

5. **Perform Upgrade:**
   ```bash
   make upgrade VERSION=4.17.2
   # Or
   oc adm upgrade --to=4.17.2
   ```

### Upgrade Paths

**Within Minor Version (e.g., 4.17.0 → 4.17.2):**
- ✅ Direct upgrade supported
- ✅ Usually safe and quick
- ✅ No breaking changes

**Between Minor Versions (e.g., 4.16 → 4.17):**
- ⚠️ Must follow upgrade path
- ⚠️ Review release notes
- ⚠️ Test in non-production first
- ⚠️ May require multiple steps

**Skipping Versions:**
- ❌ Not recommended
- ❌ May cause issues
- ❌ Always follow sequential upgrade path

## Common Scenarios

### Scenario 1: "I want the latest stable OpenShift"

```bash
# Use stable channel
OPENSHIFT_VERSION="stable-4.17"

# Get matching AMI
make version-ami VERSION=stable-4.17 REGION=us-east-1
```

### Scenario 2: "I need to match another environment"

```bash
# Find exact version from other cluster
oc version  # On existing cluster

# Use that exact version
OPENSHIFT_VERSION="4.17.1"

# Get matching AMI
make version-ami VERSION=4.17.1 REGION=us-east-1
```

### Scenario 3: "I want to test new features"

```bash
# Use latest channel
OPENSHIFT_VERSION="latest-4.17"

# Get matching AMI
make version-ami VERSION=latest-4.17 REGION=us-east-1
```

### Scenario 4: "I need an older version for compatibility"

```bash
# List versions to find the one you need
make version-list

# Use specific older version
OPENSHIFT_VERSION="4.16.5"

# Get matching AMI
make version-ami VERSION=4.16.5 REGION=us-east-1
```

## Troubleshooting

### Error: "Version not found"

**Problem:** The specified version doesn't exist.

**Solution:**
```bash
# List available versions
make version-list

# Verify the version exists
make version-details VERSION=your-version
```

### Error: "RHCOS AMI not found"

**Problem:** AMI might not be available in your region.

**Solution:**
```bash
# Check available regions
./openshift-version-helper.sh ami your-version

# Choose a different region or
# Copy AMI to your region manually
```

### Error: "Version mismatch"

**Problem:** OpenShift version and RHCOS AMI don't match.

**Solution:**
```bash
# Always get AMI using the helper
make version-ami VERSION=your-version REGION=your-region

# Update config.env with both values
```

## Best Practices

1. **Production Deployments:**
   - ✅ Use `stable-X.Y` channels
   - ✅ Test in non-production first
   - ✅ Document versions in change management
   - ✅ Schedule upgrades during maintenance windows

2. **Development/Testing:**
   - ✅ Use `latest-X.Y` for early features
   - ✅ Keep development ahead of production
   - ✅ Test upgrade paths before production

3. **Version Control:**
   - ✅ Commit config.env to version control
   - ✅ Tag releases with OpenShift version
   - ✅ Document why specific versions are used

4. **Security:**
   - ✅ Monitor Red Hat security bulletins
   - ✅ Apply patches promptly
   - ✅ Keep versions reasonably current

5. **Cloudera Compatibility:**
   - ✅ Check Cloudera Data Services compatibility matrix
   - ✅ Ensure OpenShift version is supported
   - ✅ Test Cloudera workloads after upgrades

## References

- **OpenShift Versions:** https://mirror.openshift.com/pub/openshift-v4/clients/ocp/
- **RHCOS Images:** https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/
- **Release Notes:** https://docs.openshift.com/container-platform/4.17/release_notes/
- **Upgrade Docs:** https://docs.openshift.com/container-platform/4.17/updating/
- **Cloudera Compatibility:** https://docs.cloudera.com/

## Quick Command Reference

```bash
# Version Management
make version-select              # Interactive selector
make version-list                # List all versions
make version-details VERSION=X   # Show version details
make version-ami VERSION=X REGION=Y  # Get RHCOS AMI

# Helper Script
./openshift-version-helper.sh list      # List versions
./openshift-version-helper.sh details X # Version details
./openshift-version-helper.sh ami X Y   # Get AMI
./openshift-version-helper.sh validate X # Validate version
./openshift-version-helper.sh select    # Interactive

# Cluster Operations
make install                # Install with configured version
make upgrade VERSION=X      # Upgrade to version
oc get clusterversion       # Check current version
oc adm upgrade              # List available upgrades
```
