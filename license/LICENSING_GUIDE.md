# Licensing Guide

## Overview

This OpenShift UPI Automation Framework is released under the **MIT License**, one of the most permissive open-source licenses.

## What This Means for You

### ✅ You CAN:

- **Use commercially** - Use this software in your company without restrictions
- **Modify** - Change the code to fit your needs
- **Distribute** - Share with others or clients
- **Sublicense** - Include in your own software with different licenses
- **Private use** - Use internally without sharing modifications
- **Use for free** - No licensing fees or royalties

### 📋 You MUST:

- **Include license** - Keep the MIT license and copyright notice in any copies
- **Include notices** - Keep the NOTICE file for attribution

### ❌ You CANNOT:

- **Hold liable** - The authors are not responsible for issues
- **Claim warranty** - Software is provided "as is"
- **Use trademarks** - Can't claim endorsement by Red Hat, Cloudera, etc.

## Required Third-Party Licenses

While this automation is MIT licensed, you MUST obtain separate licenses for:

### 1. Red Hat OpenShift (REQUIRED)

**What:** OpenShift Container Platform subscription
**Cost:** Commercial license required for production
**Why:** To legally run OpenShift clusters
**Get it:** https://www.redhat.com/en/technologies/cloud-computing/openshift

**Options:**
- **Production**: Full commercial subscription
- **Development**: Red Hat Developer Subscription (free for dev/test)
- **Trial**: 60-day evaluation available

**Typical Cost:** ~$50-100 per core/year (varies by support level)

### 2. Cloudera Data Services (If using Cloudera)

**What:** Cloudera Data Platform license
**Cost:** Commercial license required
**Why:** To run Cloudera workloads on OpenShift
**Get it:** https://www.cloudera.com/

**Contact Cloudera sales** for pricing based on your workload.

### 3. AWS Account (REQUIRED)

**What:** Amazon Web Services account
**Cost:** Pay-as-you-go for resources used
**Why:** To run infrastructure
**Get it:** https://aws.amazon.com/

**Typical Cost:** ~$3,500/month for the cluster configuration in this guide

## Third-Party Open Source Components

This automation uses these open-source tools (no additional licenses needed):

| Component | License | Usage |
|-----------|---------|-------|
| Terraform | MPL 2.0 | Infrastructure as Code |
| Terraform AWS Provider | MPL 2.0 | AWS resource management |
| OpenShift Installer | Apache 2.0 | Cluster installation |
| jq | MIT | JSON processing |

## License Compatibility

### ✅ Compatible With:

This MIT-licensed automation works with:
- Apache 2.0 (OpenShift Installer)
- MPL 2.0 (Terraform)
- GPL 2.0/3.0 (can be combined)
- Other permissive licenses

### Integration Examples:

```
Your Project
├── Your proprietary code (Any license)
├── OpenShift UPI Automation (MIT License)
├── Terraform modules (MPL 2.0)
└── OpenShift Installer (Apache 2.0)
```

All these can legally work together!

## Commercial Use

### Can I use this in my company?

**YES!** The MIT license explicitly allows commercial use.

**You can:**
- Deploy OpenShift for your company
- Use for client projects
- Include in managed services
- Modify for your specific needs
- Keep modifications private

**You must:**
- Have valid Red Hat subscriptions for OpenShift clusters
- Pay AWS for resources used
- Keep the MIT license file in the code

### Can I sell this?

**YES!** You can:
- Include in paid consulting services
- Use in managed service offerings
- Package with your products

**But remember:**
- You're selling your services/value-add, not the MIT-licensed code
- Clients also get the MIT license rights
- You can't claim exclusive rights to the MIT-licensed portions

## Modification and Distribution

### Modifying the Code

**You can freely modify:**
- Change any part of the automation
- Add new features
- Customize for your environment
- Create derivative works

**Best practices:**
- Keep the original MIT license
- Add your own copyright for modifications
- Document your changes

**Example:**
```
MIT License

Copyright (c) 2025 OpenShift UPI Automation Contributors
Copyright (c) 2025 Your Company Name (for modifications)

[Rest of MIT license text]
```

### Distributing Modified Versions

**You can:**
- Share on GitHub/GitLab
- Include in internal company repos
- Distribute to clients
- Create forks

**You must:**
- Include the original MIT license
- Include the NOTICE file
- Attribute the original authors

**Optional but nice:**
- Link back to original project
- Share improvements with community
- Document your changes

## Trademark Usage

### What You CANNOT Do:

❌ Claim this is "official" Red Hat software
❌ Use "OpenShift" as part of this project's name implying endorsement
❌ Use Red Hat, Cloudera, AWS logos without permission
❌ Suggest official relationship with trademark owners

### What You CAN Do:

✅ Say "automation for OpenShift installation"
✅ Reference "works with OpenShift Container Platform"
✅ Mention "integrates with Cloudera Data Services"
✅ Use descriptive phrases in documentation

## Legal Compliance Checklist

Before using this automation in production:

### Licensing
- [ ] Obtained Red Hat OpenShift subscription
- [ ] Have valid AWS account
- [ ] Have Cloudera license (if using Cloudera)
- [ ] Kept MIT license in code
- [ ] Included NOTICE file

### Security & Compliance
- [ ] Reviewed code for your security requirements
- [ ] Conducted security assessment
- [ ] Verified compliance with company policies
- [ ] Set up appropriate access controls
- [ ] Documented deployment

### Legal
- [ ] Reviewed export compliance requirements
- [ ] Ensured data residency compliance
- [ ] Verified contract terms with vendors
- [ ] Documented license inventory

## Frequently Asked Questions

### Q: Do I need to pay for this automation?

**A:** No! The automation itself is free under MIT license. However, you must pay for:
- Red Hat OpenShift subscriptions
- AWS infrastructure costs
- Cloudera licenses (if applicable)

### Q: Can I use this for my clients?

**A:** Yes! You can use this as part of consulting services, managed services, or client deployments.

### Q: Must I share my modifications?

**A:** No. MIT license allows private modifications. Sharing is optional but encouraged!

### Q: Can I remove the license file?

**A:** No. You must keep the MIT license and copyright notice in all copies.

### Q: What if I find a bug?

**A:** The MIT license provides no warranty, but you're welcome to:
- Fix it yourself (it's open source!)
- Share the fix with the community
- Hire someone to fix it

### Q: Can I get support?

**A:** The automation has no official support. However:
- Documentation is comprehensive
- Community may help with issues
- You can hire consultants
- Red Hat supports OpenShift itself

### Q: Is this approved by Red Hat?

**A:** No. This is a community tool. For official tooling, see Red Hat documentation.

### Q: Can I use this with OpenShift trial?

**A:** Yes! Great for evaluation. Just note 60-day limitation.

### Q: What about liability?

**A:** MIT license provides no warranty and no liability. Use at your own risk. Test thoroughly!

## Getting Proper Licenses

### Red Hat OpenShift

1. **Evaluation**: https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it
2. **Developer**: https://developers.redhat.com/products/openshift/overview
3. **Purchase**: Contact Red Hat sales

### Cloudera Data Platform

1. **Information**: https://www.cloudera.com/products/cloudera-data-platform.html
2. **Pricing**: Contact Cloudera sales
3. **Trial**: Available through Cloudera

### AWS Account

1. **Sign up**: https://aws.amazon.com/
2. **Free tier**: Available for some services
3. **Costs**: Pay for resources used

## Contributing

Contributions to this MIT-licensed project are welcome!

**By contributing, you agree:**
- Your contributions will be MIT licensed
- You have rights to contribute the code
- You accept the same "no warranty" terms

## Summary

| Aspect | Details |
|--------|---------|
| **This Automation** | MIT License - Free to use |
| **OpenShift** | Commercial license required |
| **Cloudera** | Commercial license required (if used) |
| **AWS** | Pay-as-you-go for resources |
| **Terraform** | Open source (MPL 2.0) - Free |
| **Commercial Use** | ✅ Allowed |
| **Modifications** | ✅ Allowed |
| **Distribution** | ✅ Allowed |
| **Warranty** | ❌ None provided |
| **Liability** | ❌ Authors not liable |

## Resources

- **MIT License**: https://opensource.org/licenses/MIT
- **OpenShift Licensing**: https://www.redhat.com/en/about/licensing
- **Cloudera Licensing**: https://www.cloudera.com/legal/policies.html
- **AWS Terms**: https://aws.amazon.com/terms/

## Questions?

For licensing questions:
- **This automation**: Review LICENSE and NOTICE files
- **Red Hat**: Contact Red Hat sales/support
- **Cloudera**: Contact Cloudera sales/support
- **AWS**: Review AWS terms of service

---

**Remember**: While this automation is free and open-source, the platforms it deploys (OpenShift, Cloudera, AWS) require proper licensing and payment. Always ensure compliance with all vendor terms and your organization's policies.
