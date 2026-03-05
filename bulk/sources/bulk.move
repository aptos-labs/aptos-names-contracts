module bulk::bulk {
    use std::error;
    use std::option;
    use std::option::Option;
    use std::string::String;
    use router::router;

    /// For bulk migrate endpoint, domain names vector must have same length as subdomain names vector
    const EDOMAIN_AND_SUBDOMAIN_MUST_HAVE_SAME_LENGTH: u64 = 1;
    /// For bulk renew, domain names vector must have same length as renewal duration vector
    const EDOMAIN_AND_RENEWAL_DURATION_MUST_HAVE_SAME_LENGTH: u64 = 2;

    // ==== Migrate ====

    /// Domains only
    public entry fun bulk_migrate_domain(
        user: &signer,
        domain_names: vector<String>
    ) {
        for (idx in 0..domain_names.length()) {
            let domain_name = domain_names[idx];
            router::migrate_name(user, domain_name, option::none());
        }
    }

    /// Subdomains only
    public entry fun bulk_migrate_subdomain(
        user: &signer,
        domain_names: vector<String>,
        subdomain_names: vector<Option<String>>,
    ) {
        assert!(
            domain_names.length() == subdomain_names.length(),
            error::invalid_argument(EDOMAIN_AND_SUBDOMAIN_MUST_HAVE_SAME_LENGTH)
        );
        for (idx in 0..domain_names.length()) {
            let domain_name = domain_names[idx];
            let subdomain_name = subdomain_names[idx];
            router::migrate_name(user, domain_name, subdomain_name);
        }
    }

    // ==== Renewal ====

    /// Domains only
    public entry fun bulk_renew_domain(
        user: &signer,
        domain_names: vector<String>,
        renewal_duration_secs: vector<u64>,
    ) {
        assert!(
            domain_names.length() == renewal_duration_secs.length(),
            error::invalid_argument(EDOMAIN_AND_RENEWAL_DURATION_MUST_HAVE_SAME_LENGTH)
        );
        for (idx in 0..domain_names.length()) {
            let domain_name = domain_names[idx];
            let renewal_duration_sec = renewal_duration_secs[idx];
            router::renew_domain(user, domain_name, renewal_duration_sec);
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
        for (idx in 0..domain_names.length()) {
            router::register_subdomain(
                domain_admin,
                domain_names[idx],
                subdomain_names[idx],
                expiration_time_secs[idx],
                expiration_policies[idx],
                transferrable[idx],
                option::some(target_addrs[idx]),
                option::some(to_addrs[idx]),
            );
        }
    }
}
