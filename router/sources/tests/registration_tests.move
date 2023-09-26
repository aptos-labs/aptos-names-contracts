#[test_only]
module router::registration_tests {
    use router::router;
    use router::router_test_helper;
    use std::option;
    use std::signer::address_of;
    use std::string::utf8;
    use std::vector;

    const MAX_MODE: u8 = 1;
    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    // == DOMAIN REGISTRATION ==

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    fun test_register_domain(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = address_of(user);
        let domain_name1 = utf8(b"test1");
        let domain_name2 = utf8(b"test2");

        // Register with v1
        router::register_domain(user, domain_name1, SECONDS_PER_YEAR, option::none(), option::none());
        assert!(router::is_name_owner(user_addr, domain_name1, option::none()), 1);

        // Bump mode
        router::set_mode(router, 1);

        // Register with v2
        router::register_domain(user, domain_name2, SECONDS_PER_YEAR, option::none(), option::none());
        assert!(router::is_name_owner(user_addr, domain_name1, option::none()), 2);
        assert!(router::is_name_owner(user_addr, domain_name2, option::none()), 3);

        // v1 primary name is not cleared. v1 primary name only gets unset for explicit change of primary name.
        assert!(option::is_some(&aptos_names::domains::get_reverse_lookup(address_of(user))), 4);
        // v2 primary name is properly set
        let (primary_subdomain_name, primary_domain_name) = router::router::get_primary_name(address_of(user));
        assert!(option::is_none(&primary_subdomain_name), 5);
        assert!(option::some(domain_name1) == primary_domain_name, 6);
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 851974, location = router)]
    fun test_register_same_domain_in_v1_and_v2(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let domain_name = utf8(b"test1");

        // Register with v1
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());

        // Bump mode
        router::set_mode(router, 1);

        // Fail to register with v2 because name is still active in v1
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    fun test_register_diff_domain_in_v1_and_v2(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = address_of(user);
        let domain_name1 = utf8(b"test1");

        // Register with v1
        router::register_domain(user, domain_name1, SECONDS_PER_YEAR, option::none(), option::none());
        {
            // Primary name should be `domain_name1`
            let (primary_subdomain, primary_domain) = router::get_primary_name(user_addr);
            assert!(primary_subdomain == option::none(), 3);
            assert!(*option::borrow(&primary_domain) == domain_name1, 4);
        };

        // Bump mode and disable v1
        aptos_names::config::set_is_enabled(aptos_names, false);
        router::set_mode(router, 1);

        let domain_name = utf8(b"test2");
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        {
            // Primary name should still be `domain_name1`
            let (primary_subdomain, primary_domain) = router::get_primary_name(user_addr);
            assert!(primary_subdomain == option::none(), 3);
            assert!(*option::borrow(&primary_domain) == domain_name1, 4);
        };
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    fun test_register_domain_with_target_addr_and_to_addr(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user1, &aptos, user2, &foundation);
        let user1 = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);
        let user1_addr = address_of(user1);
        let user2_addr = address_of(user2);
        let domain_name1 = utf8(b"test1");
        let domain_name2 = utf8(b"test2");

        // Register with v1
        aptos_token::token::opt_in_direct_transfer(user2, true);
        router::register_domain(
            user1,
            domain_name1,
            SECONDS_PER_YEAR,
            option::some(user2_addr),
            option::some(user2_addr)
        );
        assert!(router::is_name_owner(user2_addr, domain_name1, option::none()), 1);
        assert!(*option::borrow(&router::get_target_addr(domain_name1, option::none())) == user2_addr, 2);
        {
            // Primary name should be unset for user1 now that `target_addr` has been changed.
            let (primary_subdomain, primary_domain) = router::get_primary_name(user1_addr);
            assert!(primary_subdomain == option::none(), 3);
            assert!(primary_domain == option::none(), 4);
        };

        // Bump mode
        router::set_mode(router, 1);

        // Register with v2
        router::register_domain(
            user1,
            domain_name2,
            SECONDS_PER_YEAR,
            option::some(user2_addr),
            option::some(user2_addr)
        );
        assert!(router::is_name_owner(user2_addr, domain_name2, option::none()), 1);
        assert!(*option::borrow(&router::get_target_addr(domain_name2, option::none())) == user2_addr, 2);
        {
            // Primary name should be unset for user1 now that `target_addr` has been changed.
            let (primary_subdomain, primary_domain) = router::get_primary_name(user1_addr);
            assert!(primary_subdomain == option::none(), 3);
            assert!(primary_domain == option::none(), 4);
        };
    }

    // == SUBDOMAIN REGISTRATION ==

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    fun test_register_subdomain(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = address_of(user);

        // Register with v1
        let domain_name1 = utf8(b"test1");
        let subdomain_name1 = utf8(b"sub1");
        router::register_domain(user, domain_name1, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_subdomain(
            user,
            domain_name1,
            subdomain_name1,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none(),
        );
        assert!(router::is_name_owner(user_addr, domain_name1, option::some(subdomain_name1)), 1);

        // Bump mode
        router::set_mode(router, 1);

        // Register with v2
        let domain_name2 = utf8(b"test2");
        let subdomain_name2 = utf8(b"sub2");
        router::register_domain(user, domain_name2, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_subdomain(
            user,
            domain_name2,
            subdomain_name2,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none(),
        );
        assert!(router::is_name_owner(user_addr, domain_name2, option::some(subdomain_name2)), 2);
        assert!(router::get_subdomain_expiration_policy(domain_name2, subdomain_name2) == 0, 3);

        // Register another subdomain with a different subdomain expiration policy
        let subdomain_name3 = utf8(b"sub3");
        router::register_subdomain(
            user,
            domain_name2,
            subdomain_name3,
            SECONDS_PER_YEAR,
            1,
            false,
            option::none(),
            option::none(),
        );
        assert!(router::is_name_owner(user_addr, domain_name2, option::some(subdomain_name3)), 2);
        assert!(router::get_subdomain_expiration_policy(domain_name2, subdomain_name3) == 1, 3);
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 851974, location = router)]
    fun test_register_same_subdomain_in_v1_and_v2(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let domain_name = utf8(b"test");
        let subdomain_name = utf8(b"sub");

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
            option::none(),
        );

        // Bump mode
        router::set_mode(router, 1);

        // Migrate domain
        router::migrate_name(user, domain_name, option::none());

        // Fail to register with v2 because name is still active in v1
        router::register_subdomain(
            user,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none(),
        );
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 851974, location = router)]
    fun test_register_subdomain_whose_domain_is_not_in_v2(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let domain_name = utf8(b"test");
        let subdomain_name = utf8(b"sub");

        // Register domain with v1
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_subdomain(
            user,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none(),
        );

        // Bump mode
        router::set_mode(router, 1);

        // Fail to register with v2 because domain does not yet exist in v2
        router::register_subdomain(
            user,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none(),
        );
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    fun test_register_subdomain_with_target_addr_and_to_addr(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user1, &aptos, user2, &foundation);
        let user1 = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);
        let user1_addr = address_of(user1);
        let user2_addr = address_of(user2);
        let domain_name1 = utf8(b"test1");
        let domain_name2 = utf8(b"test2");
        let subdomain_name = utf8(b"sub");
        let subdomain_name_opt = option::some(subdomain_name);

        // Register with v1
        aptos_token::token::opt_in_direct_transfer(user2, true);
        router::register_domain(user1, domain_name1, SECONDS_PER_YEAR, option::some(user2_addr), option::none());
        router::register_subdomain(
            user1,
            domain_name1,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::some(user2_addr),
            option::some(user2_addr),
        );
        assert!(router::is_name_owner(user2_addr, domain_name1, subdomain_name_opt), 1);
        assert!(*option::borrow(&router::get_target_addr(domain_name1, subdomain_name_opt)) == user2_addr, 2);
        {
            // Primary name should be unset for user1 now that `target_addr` has been changed.
            let (primary_subdomain, primary_domain) = router::get_primary_name(user1_addr);
            assert!(primary_subdomain == option::none(), 3);
            assert!(primary_domain == option::none(), 4);
        };

        // Bump mode
        router::set_mode(router, 1);

        // Register with v2
        router::register_domain(user1, domain_name2, SECONDS_PER_YEAR, option::some(user2_addr), option::none());
        router::register_subdomain(
            user1,
            domain_name2,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::some(user2_addr),
            option::some(user2_addr),
        );
        assert!(router::is_name_owner(user2_addr, domain_name2, subdomain_name_opt), 1);
        assert!(*option::borrow(&router::get_target_addr(domain_name2, subdomain_name_opt)) == user2_addr, 2);
        {
            // Primary name should be unset for user1 now that `target_addr` has been changed.
            let (primary_subdomain, primary_domain) = router::get_primary_name(user1_addr);
            assert!(primary_subdomain == option::none(), 3);
            assert!(primary_domain == option::none(), 4);
        };
    }
}
