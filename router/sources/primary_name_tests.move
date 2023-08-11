#[test_only]
module router::primary_name_tests {
    use router::router;
    use router::test_helper;
    use std::option;
    use std::signer::address_of;
    use std::string::utf8;
    use std::vector;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    fun test_set_primary_name(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = address_of(user);
        let domain_name = utf8(b"test");
        let subdomain_name = utf8(b"test");
        let subdomain_name_opt = option::some(subdomain_name);

        // Register with v1
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_subdomain(
            user,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none()
        );

        // Set domain as primary
        router::set_primary_name(user, domain_name, option::none());
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 1);
            assert!(option::is_none(&primary_subdomain_name), 2);
        };

        // Set subdomain as primary
        router::set_primary_name(user, domain_name, subdomain_name_opt);
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 3);
            assert!(*option::borrow(&primary_subdomain_name) == subdomain_name, 4);
        };

        // Clear primary name
        router::clear_primary_name(user);
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(option::is_none(&primary_domain_name), 5);
            assert!(option::is_none(&primary_subdomain_name), 6);
        };

        // Bump mode
        router::set_mode(router, 1);

        // Primary name should still be cleared after version bump
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(option::is_none(&primary_domain_name), 5);
            assert!(option::is_none(&primary_subdomain_name), 6);
        };

        // Migrate domain and subdomain
        router::migrate_name(user, domain_name, option::none());
        router::migrate_name(user, domain_name, subdomain_name_opt);

        // Set domain as primary
        router::set_primary_name(user, domain_name, option::none());
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 7);
            assert!(option::is_none(&primary_subdomain_name), 8);
        };

        // Set subdomain as primary
        router::set_primary_name(user, domain_name, subdomain_name_opt);
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 9);
            assert!(*option::borrow(&primary_subdomain_name) == subdomain_name, 10);
        };

        // Clear primary name
        router::clear_primary_name(user);
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(option::is_none(&primary_domain_name), 11);
            assert!(option::is_none(&primary_subdomain_name), 12);
        };
    }
}
