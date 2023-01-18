# Aptos Names Bug Bounty

## Reporting a Security Concern

**DO NOT CREATE AN ISSUE** to report a security problem.

Send an email to [security@aptoslabs.com](mailto:security@aptoslabs.com) and provide your GitHub username. The team will create a new draft security advisory for further discussion.

For security reasons, DO NOT include attachments or provide detail sufficient for exploitation regarding the security issue in this email. Instead, wait for the advisory to be created, and **provide any sensitive details in the private GitHub advisory**.

If you haven't done so already, please **enable two-factor auth** in your GitHub account.

Send the email from an email domain that is less likely to get flagged for spam by gmail.

This is an actively monitored account, the team will quickly respond.

If you do not receive a response within 24 hours, please directly followup with the team in [Discord](https://discord.com/invite/petrawallet). by reaching out to anyone with the role “Aptos Labs”.

As above, please DO NOT include attachments or provide detail regarding the security issue in this email.

## Incident Response Process

1. Establish a new draft security advisory
    1. In response to an email to [security@aptoslabs.com](mailto:security@aptoslabs.com), a member of the Aptos Labs will create a new draft security advisory for the incident at [https://github.com/aptos-labs/aptos-names-contracts/security/policy.](https://github.com/aptos-labs/petra-wallet/security/policy)
    2. Add the reporter's GitHub account and relevant individuals to the draft security advisory.
    3. Respond to the reporter by email, sharing a link to the draft security advisory.
2. The reporter should add appropriate content to the draft security advisory. To be eligible for a bug bounty, this includes:
    1. A clear description of the issue and the impacted areas.
    2. The code and the methodology to reproduce the underlying issue.
    3. Discussion of potential remediations.
3. Aptos Labs team responder will triage:
    1. Validate the issue.
    2. Determine the criticality of the issue.
    3. If this is not a security issue but a bug, recommend that the submitter create an issue
4. Resolve by deploying the fix and pushing to affected entities.

## Bug Bounties

Aptos Labs offers bounties for security reports. Reports will be validated against the current deployed version of Aptos Names module, the web services used to query names , and the web site used to purchase Aptos Names.

Aptos Labs considers the following levels of severity:

### Module / Smart Contract —

****************Critical — Up to $250,000 USD in APT tokens (locked for 12 months)****************

- Name takeover
    - unauthorized overriding of target address for names
    - seizing name NFTs

**Other — Up to $50,000 USD in APT tokens (locked for 12 months)**

- Bypassing reCaptcha proof verification for minting
- Minting names without paying the intended $APT
- Changing funds address (where purchase payments go)

### Website — [https://www.aptosnames.com/](https://www.aptosnames.com/)

**Other — Up to $50,000 USD in APT tokens (locked for 12 months)**

- Retrieve sensitive data, files, or environment variables from a running service. Ex: database passwords, blockchain keys. This excludes non-sensitive environment variables, open-source code, or usernames.

### Web Services — [https://www.aptosnames.com/api](https://www.aptosnames.com/api)

**Other — Up to $50,000 USD in APT tokens (locked for 12 months)**

- Name/account takeover
- Forcing API to return an incorrect target address for a name

## **Payment of Bug Bounties**

- Bounties are currently awarded on a rolling/weekly basis and paid out within 30 days upon receipt of successful KYC and payment contract.
- The APT/USD conversion rate used for payments is the market price of APT (denominated in USD) at 11:59 PM PST the day that both KYC and the payment contract are completed.
- The reference for this price is the Closing Price given by Coingecko.com on that date given here: [https://www.coingecko.com/en/coins/aptos/historical_data#panel](https://www.coingecko.com/en/coins/aptos/historical_data#panel)
- Bug bounties that are paid out in APT are locked to the account provided by the reporter with a lockup expiring 12 months from the date of the delivery of APT.

## Duplicate Reports

Compensation for duplicate reports will be split among reporters with first to report taking priority using the following equation:

```
R: total reports
ri: report priority
bi: bounty share

bi = 2 ^ (R - ri) / ((2^R) - 1)
```

Where report priority derives from the set of integers beginning at 1, where the first reporter has `ri = 1`, the second reporter `ri = 2`, and so forth.

Note, reports that come in after the issue has been fully triaged and resolved will not be eligible for splitting.

## KYC Requirements

This bug bounty program is only open to individuals [outside the OFAC restricted countries](https://home.treasury.gov/policy-issues/financial-sanctions/sanctions-programs-and-country-information). Bug bounty hunters will be required to provide evidence that they are not a resident or citizen of these countries in case the submission is eligible for a reward. If the individual is a US person, tax information will be required, such as a W-9, in order to properly issue a 1099. Aptos requires KYC to be done for all bug bounty hunters submitting a report and wanting a reward. Form W-9 or Form W-8 is required for tax purposes. All bug bounty hunters are required to use Persona for KYC, links will be provided upon resolution of the issue The collection of this information will be done by the Aptos Labs.

If an impact can be caused to any other asset managed by Aptos that isn’t on this table but for which the impact is in the Impacts in Scope section below, you are encouraged to submit it for consideration by the project.

## Out of Scope

The following vulnerabilities are excluded from the rewards for this bug bounty program:

- Attacks that the reporter has already exploited themselves, leading to damage
- Attacks requiring access to leaked keys/credentials
- Attacks requiring access to privileged addresses (governance, strategist)
- Internally known issues, duplicate issues, or issues that have already been made public
- Email or mobile enumeration (Ex: identifying emails via password reset)
- Information disclosure with minimal security impact (Ex: stack traces, path disclosure, directory listing, logs)
- Tab-nabbing
- Vulnerabilities related to auto-fill web forms
- Vulnerabilities only exploitable on out-of-date browsers or platforms
- Attacks requiring physical / digital access to the victim device
- Vulnerabilities that require root/jailbreak
- Self-XSS
- Attacks that rely on social engineering
- Attacks that rely on access to the clipboard
- Attacks that rely on old versions of chrome or manifest versions
- Attacks on accompanying marketing sites, such as **[https://petra.app](https://petra.app/)**
- Theoretical vulnerabilities without any proof or demonstration
- Attacks requiring physical/complete digital access to the victim device
- Attacks requiring access to the local network of the victim
- Reflected plain text injection ex: url parameters, path, etc.
    - This does not exclude reflected HTML injection with or without javascript
    - This does not exclude persistent plain text injection
- Self-XSS
- Captcha bypass using OCR without impact demonstration
- CSRF with no state modifying security impact (ex: logout CSRF)
- Missing HTTP Security Headers (such as X-FRAME-OPTIONS) or cookie security flags (such as “httponly”) without demonstration of impact
- Server-side non-confidential information disclosure such as IPs, server names, and most stack traces
- Vulnerabilities used only to enumerate or confirm the existence of users or tenants
- Vulnerabilities requiring un-prompted, in-app user actions that are not part of the normal app workflows
- Lack of SSL/TLS best practices
- DDoS vulnerabilities
- Feature requests
- Issues related to the frontend without concrete impact and PoC
- Best practices issues without concrete impact and PoC
- Vulnerabilities primarily caused by browser/plugin defects
- Leakage of non sensitive api keys ex: etherscan, Infura, Alchemy, etc.
- Any vulnerability exploit requiring browser bugs for exploitation. ex: CSP bypass
- ********************************Smart contracts:********************************
    - Incorrect data supplied by third-party oracles (not to exclude oracle manipulation/flash loan attacks; use of such methods to generate critical impacts remain in-scope for this program).
    - Basic economic governance attacks (e.g., 51% attack).
    - Lack of liquidity.
    - Best practice critiques.
    - Missing or incorrect data in events.
    - Incorrect naming (but still correct data) in contracts.
    - Minor rounding errors that don’t lead to substantial loss of funds.
    - Incorrect data supplied by third party oracles
        - Not to exclude oracle manipulation/flash loan attacks

## Exclusions

The following activities are prohibited by this bug bounty program:

- Any testing with mainnet or public testnet contracts; all testing should be done on [private testnets](https://aptos.dev/nodes/local-testnet/local-testnet-index/)
- Any testing with pricing oracles or third party smart contracts
- Attempting phishing or other social engineering attacks against our employees and/or customers
- Any testing with third-party systems and applications (e.g., browser extensions) as well as websites (e.g., SSO providers, advertising networks)
- Any denial of service attacks
- Automated testing of services that generates significant amounts of traffic
- Public disclosure of an unpatched vulnerability in an embargoed bounty