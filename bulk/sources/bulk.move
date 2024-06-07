module bulk::bulk {
    use std::error;
    use std::option;
    use std::option::Option;
    use std::string::String;
    use std::vector;
    use router::router;

    /// For bulk migrate endpoint, domain names vector must have same length as subdomain names vector
    const EDOMAIN_AND_SUBDOMAIN_MUST_HAVE_SAME_LENGTH: u64 = 1;
    /// For bulk renew, domain names vector must have same length as renewal duration vector
    const EDOMAIN_AND_RENEWAL_DURATION_MUST_HAVE_SAME_LENGTH: u64 = 2;

    // ==== Migrate ====

    /// Domains only
    public entry fun bulk_migrate_domain(
        user: &signer, domain_names: vector<String>
    ) {
        let idx = 0;
        while (idx < vector::length(&domain_names)) {
            let domain_name = *vector::borrow(&domain_names, idx);
            router::migrate_name(user, domain_name, option::none());
            idx = idx + 1
        }
    }

    /// Subdomains only
    public entry fun bulk_migrate_subdomain(
        user: &signer, domain_names: vector<String>, subdomain_names: vector<Option<String>>,
    ) {
        assert!(vector::length(&domain_names)
            == vector::length(&subdomain_names),
            error::invalid_argument(EDOMAIN_AND_SUBDOMAIN_MUST_HAVE_SAME_LENGTH));
        let idx = 0;
        while (idx < vector::length(&domain_names)) {
            let domain_name = *vector::borrow(&domain_names, idx);
            let subdomain_name = *vector::borrow(&subdomain_names, idx);
            router::migrate_name(user, domain_name, subdomain_name);
            idx = idx + 1
        }
    }

    // ==== Renewal ====

    /// Domains only
    public entry fun bulk_renew_domain(
        user: &signer, domain_names: vector<String>, renewal_duration_secs: vector<u64>,
    ) {
        assert!(vector::length(&domain_names)
            == vector::length(&renewal_duration_secs),
            error::invalid_argument(EDOMAIN_AND_RENEWAL_DURATION_MUST_HAVE_SAME_LENGTH));
        let idx = 0;
        while (idx < vector::length(&domain_names)) {
            let domain_name = *vector::borrow(&domain_names, idx);
            let renewal_duration_sec = *vector::borrow(&renewal_duration_secs, idx);
            router::renew_domain(user, domain_name, renewal_duration_sec);
            idx = idx + 1
        }
    }

    // ==== Renewal and Migration ====

    /// Domains only
    public entry fun bulk_migrate_and_renew_domain(
        user: &signer,
        migrate_domain_names: vector<String>,
        renew_domain_names: vector<String>,
        renewal_duration_secs: vector<u64>,
    ) {
        bulk_migrate_domain(user, migrate_domain_names);
        bulk_renew_domain(user, renew_domain_names, renewal_duration_secs);
    }

    // ==== Registration ====

    /// Subdomains only
    public entry fun bulk_register_subdomain(
        domain_admin: &signer,
        domain_names: vector<String>,
        subdomain_names: vector<String>,
        expiration_time_secs: vector<u64>,
        expiration_policies: vector<u8>,
        transferrable: vector<bool>,
        target_addrs: vector<address>,
        to_addrs: vector<address>,
    ) {
        let idx = 0;
        while (idx < vector::length(&domain_names)) {
            router::register_subdomain(domain_admin,
                *vector::borrow(&domain_names, idx),
                *vector::borrow(&subdomain_names, idx),
                *vector::borrow(&expiration_time_secs, idx),
                *vector::borrow(&expiration_policies, idx),
                *vector::borrow(&transferrable, idx),
                option::some(*vector::borrow(&target_addrs, idx)),
                option::some(*vector::borrow(&to_addrs, idx)),);
            idx = idx + 1
        }
    }
}
