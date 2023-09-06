module bulk_migrate::migrate {
    use std::error;
    use std::option::Option;
    use std::string::String;
    use std::vector;
    use router::router;

    /// For bulk migrate endpoint, domain names vector must have same length as subdomain names vector
    const EDOMAIN_AND_SUBDOMAIN_MUST_HAVE_SAME_LENGTH: u64 = 1;

    public entry fun bulk_migrate_name(
        user: &signer,
        domain_names: vector<String>,
        subdomain_names: vector<Option<String>>,
    ) {
        assert!(
            vector::length(&domain_names) == vector::length(&subdomain_names),
            error::invalid_argument(EDOMAIN_AND_SUBDOMAIN_MUST_HAVE_SAME_LENGTH)
        );
        let idx = 0;
        while (idx < vector::length(&domain_names)) {
            let domain_name = domain_names[idx];
            let subdomain_name = subdomain_names[idx];
            router::migrate_name(user, domain_name, subdomain_name);
            idx = idx + 1
        }
    }
}
