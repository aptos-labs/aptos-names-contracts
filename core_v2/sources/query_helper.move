#[test_only]
module aptos_names_v2::query_helper {
    use aptos_names_v2::v2_domains;
    use std::option::{Self, Option};
    use std::string::{String};

    #[view]
    /// Returns (expiration time, target address) given the domain
    public fun get_domain_props(
        domain: String,
    ): (u64, Option<address>) {
        v2_domains::get_name_record_props_for_name(option::none(), domain)
    }

    #[view]
    /// Returns (expiration time, target address) given the subdomain
    public fun get_subdomain_props(
        subdomain: String,
        domain: String,
    ): (u64, Option<address>) {
        v2_domains::get_name_record_props_for_name(option::some(subdomain), domain)
    }

    #[view]
    /// Returns (subdomain_name, domain_name) if address has a reverse lookup (primary name) setup
    public fun get_reverse_lookup_name(
        account_addr: address
    ): (Option<String>, Option<String>) {
        let reverse_record_address = v2_domains::get_reverse_lookup(account_addr);
        if (option::is_some(&reverse_record_address)) {
            let address = option::borrow(&reverse_record_address);
            let (subdomain_name, domain_name) = v2_domains::get_record_props_from_token_addr(*address);
            (subdomain_name, option::some(domain_name))
        } else {
            (option::none(), option::none())
        }
    }

    #[view]
    /// Returns true if domain is not registered OR (name is registered AND is expired)
    public fun domain_name_is_expired(domain_name: String): bool {
        v2_domains::is_name_expired(domain_name, option::none())
    }

    #[view]
    /// Returns true if subdomain is not registered OR (name is registered AND is expired)
    public fun subdomain_name_is_expired(
        subdomain_name: String,
        domain_name: String
    ): bool {
        v2_domains::is_name_expired(domain_name, option::some(subdomain_name))
    }

    #[view]
    /// Returns true if domain exists AND the owner is not the `token_resource` account
    public fun domain_name_is_registered(
        domain_name: String
    ): bool {
        v2_domains::is_name_registered(domain_name, option::none())
    }

    #[view]
    /// Returns true if subdomain exists AND the owner is not the `token_resource` account
    public fun subdomain_name_is_registered(
        subdomain_name: String,
        domain_name: String
    ): bool {
        v2_domains::is_name_registered(domain_name, option::some(subdomain_name))
    }

    #[view]
    /// gets the address pointed to by a given domain name
    /// Is `Option<address>` because the name may not be registered, or it may not have an address associated with it
    public fun domain_name_resolved_address(
        domain_name: String
    ): Option<address> {
        v2_domains::get_name_resolved_address(option::none(), domain_name)
    }

    #[view]
    /// gets the address pointed to by a given subdomain name
    /// Is `Option<address>` because the name may not be registered, or it may not have an address associated with it
    public fun subdomain_name_resolved_address(
        subdomain_name: String,
        domain_name: String
    ): Option<address> {
        v2_domains::get_name_resolved_address(option::some(subdomain_name), domain_name)
    }
}
