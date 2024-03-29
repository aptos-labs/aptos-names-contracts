# Aptos Naming Service

The Aptos Naming Service is a decentralized naming service for the Aptos blockchain.
At its core, the naming service is an on-chain contract that allows users to register domain and subdomain names, and
point them to an account. This allows users to have a human-readable name for their account, and to use it in place of
the long and un-ergonomic hex addresses that exist today.

For example, instead of sending a transaction to `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`,
you would send it to `max.apt` instead.

### Terms

- **Domain Name**: A domain name is a string of UTF8 characters.
- **Subdomain Name**: A domain name is a string of UTF8 characters.
- **Name**: When we refer to a `name` we mean either `subdomain_name` or `domain_name`.
  This is used when describing something that applies to both `Domains` _**and**_ `Subdomains`.
- **Character Set**: In order to allow for a safe rollout of names, we are breaking UTF8
- **Glyph**: A single character in a character set. For example, `a` is a single glyph in the `latin` character set,
  and `你好` is two glyphs in the `simplified_chinese` character set. We specifically use `glyph` instead of `letter` to
  help avoid confusion when dealing with character sets where the term `letter` is not applicable, such
  as `simplified_chinese`, or `emojis`, such as this unicorn: 🦄. Aptos is a unicorn-friendly zone. Neigh!

### Character Sets

With great UTF8 flexibility comes great UTF8 pain. In order to avoid this pain out of the gate, we are launching with a
limited character set, which parallels ASCII English letters and numbers with the characters it supports. We are
referring to
this character set as `latin`.
We will expand both the number of character sets we support, and the glyphs within each one, as quickly as possible to
do safely.

For languages where glyphs may have an upper and lower case, all names are only allowed to be registered using lower
case letters.

We will only allow registering domains which are compatible with [RFC 5890](https://www.rfc-editor.org/rfc/rfc5890).

Names are currently verified following the below rules:

1. characters `a-z`, `0-9`, and `-` are allowed.
2. Names may not begin or end with a `-`.
3. Names may not contain more than 63 characters.

### On-Chain Representation

`Domains` and `Subdomains` are represented on-chain in two ways:

As an `NFT`, following our [Digital Asset Standard](https://aptos.dev/standards/digital-asset). When a name is registered, an `NameRecord` object is created with a reference to represent the ownership. This NFT can be
bought, sold, or transferred to another account just like any other `Token`. Names are not permanent, however: much
like Web2 domains, the registration will expire after a period of time. Names are currently registrable for durations
with increments of 1 year, and the price increases both as the number of years registered increases, and number of
glyphs decreases. For more information on pricing, please see the [pricing](#pricing) section.

### Setting Domain/Subdomain Addresses

When a `Domain` or `Subdomain` is registered through the router, one can set the target address that the name points to, and can gift the name to another account. 
The owner can set the name to point to any arbitrary address.

The owner can also `clear` the name by
calling `router::clear_target_addr(user: &signer, domain_name: String,  subdomain_name: Option<String>)`. This will remove the address
from the mapping, but retain ownership. To help combat harassment, any account that this domain points to can also use
the same method to `clear` the name, removing the mapping.

### Pricing

In order to help deter spam, we will be charging a fee for registering a domain name, and a significantly lower fee for
subdomain names..
The fee is variable, depending on the length of the name, and the duration of the registration.
This fee is sent to an account controlled by the `Aptos Foundation`, and will be used to fund grants for the ecosystem.

Shorter names are more expensive than longer names, as they are rarer, and thus more valuable.
The price per year also increases as the number of years registered increases, to help disincentivize long-term domain
squatting and more quickly return 'lost' names to those who will use them.
The maximum number of years that a domain can be registered for (excluding renewals) is 2: we will be extending this as
pricing models are upgraded. Names will be renewable indefinitely.

### Governance

We are strongly against domain squatting, scams, impersonation, harassment, and other nefarious activities.

There is a capability for an admin account to intervene when necessary. This capability includes:

- Forcefully registering, or expiring a name. This is meant to be used in the case of a name being used for malicious
  purposes, such as racism, harassment, impersonation, or scams. This makes it possible to remove a name from the
  registerable pool, and prevent it from being registered again.
- Adjust pricing

These privileges will be used to manage names that are being used in a way that is harmful to others.
Additionally, the deploy signer is able to perform all admin actions as well.

Our goal is to move more governance on-chain over time.

### Primary Name
A user can set a name as primary name by calling `router::set_primary_name(user: &signer, domain_name: String, subdomain_name: Option<String>)` 
This name will be used as the default name when you send a transaction to another account.
If a user purchases a name without primary name set before, the purchased name will be set as the primary name automatically.

### Domain Renewal
A domain owner can renew the domain when in the 6-month window before the expiration date by calling `router::renew_domain(
user: &signer, domain_name: String, renewal_duration_secs: u64)`. If the auto-renewal flag is on for a subdomain, the subdomain 
expiration will be automatically extended as well.

### Subdomain Management
A domain owner can mint subdomains for free and transfer the ownership to other accounts. The expiration date of a subdomain 
can be set in three ways: 
- The domain owner can set the expiration date of a subdomain to be the same as the domain expiration date.
- The domain owner can manually set the expiration date of a subdomain to be any date before the domain expiration date. 
- The domain owner can change the expiration settings for a subdomain at any time.

A domain can also set the transferability of its subdomains by calling `router::domain_admin_set_subdomain_transferability(domain_admin: &signer, 
domain_name: String, subdomain_name: String, transferable: bool)` If the transferability is set to `false`, the subdomain owner 
won't be able to transfer the ownership of the subdomain to another account.
