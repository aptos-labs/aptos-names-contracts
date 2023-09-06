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
        // Need to reverse because we can only traverse backward
        vector::reverse(&mut domain_names);
        vector::reverse(&mut subdomain_names);
        while (!vector::is_empty(&domain_names)) {
            let domain_name = vector::pop_back(&mut domain_names);
            let subdomain_name = vector::pop_back(&mut subdomain_names);
            router::migrate_name(user, domain_name, subdomain_name);
        }
    }
}
