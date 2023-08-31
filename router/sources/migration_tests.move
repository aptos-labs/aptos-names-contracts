#[test_only]
module router::migration_tests {
    use aptos_framework::timestamp;
    use router::router;
    use router::router_test_helper;
    use std::option;
    use std::signer::address_of;
    use std::string::utf8;
    use std::vector;

    const MAX_MODE: u8 = 1;
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
    fun test_migrate_domain(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = address_of(user);
        let domain_name = utf8(b"test");

        // Register with v1
        let now = timestamp::now_seconds();
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        assert!(router::is_name_owner(user_addr, domain_name, option::none()), 1);
        assert!(*option::borrow(&router::get_target_addr(domain_name, option::none())) == user_addr, 2);
        assert!(router::get_expiration(domain_name, option::none()) == now + SECONDS_PER_YEAR, 3);
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 4);
            assert!(option::is_none(&primary_subdomain_name), 5);
        };

        // Bump mode
        router::set_mode(router, 1);

        // Attributes should still be the same
        assert!(router::is_name_owner(user_addr, domain_name, option::none()), 7);
        assert!(*option::borrow(&router::get_target_addr(domain_name, option::none())) == user_addr, 8);
        assert!(router::get_expiration(domain_name, option::none()) == now + SECONDS_PER_YEAR, 9);
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 10);
            assert!(option::is_none(&primary_subdomain_name), 11);
        };

        // Migrate to v2
        router::migrate_name(user, domain_name, option::none());
        assert!(router::is_name_owner(user_addr, domain_name, option::none()), 12);
        assert!(*option::borrow(&router::get_target_addr(domain_name, option::none())) == user_addr, 13);
        // Auto-renewal is on because the expiration is 2 years from epoch
        assert!(router::get_expiration(domain_name, option::none()) == now + SECONDS_PER_YEAR * 2, 14);
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 15);
            assert!(option::is_none(&primary_subdomain_name), 16);
        };

        // v1 target is cleared
        assert!(option::is_none(&aptos_names::domains::name_resolved_address(option::none(), domain_name)), 17);
        // v1 primary name is cleared
        assert!(option::is_none(&aptos_names::domains::get_reverse_lookup(user_addr)), 17);
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327688, location = router)]
    fun test_migrate_domain_as_non_owner(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user1, &aptos, user2, &foundation);
        let user1 = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);
        let domain_name = utf8(b"test");

        // Register with v1
        router::register_domain(user1, domain_name, SECONDS_PER_YEAR, option::none(), option::none());

        // Bump mode
        router::set_mode(router, 1);

        // Migration fails because user2 does not own `domain_name`
        router::migrate_name(user2, domain_name, option::none());
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    fun test_migrate_domain_no_autorenewal(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let domain_name = utf8(b"test");

        // Set time 1690000000 (2023/07/2023), where our expiration falls past 2024/03/07
        timestamp::update_global_time_for_test_secs(1690000000);
        let now = timestamp::now_seconds();

        // Register with v1
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());

        // Bump mode
        router::set_mode(router, 1);

        // Migration fails because user2 does not own `domain_name`
        router::migrate_name(user, domain_name, option::none());

        // Auto-renewal is off because the expiration is after 2024/03/07
        assert!(router::get_expiration(domain_name, option::none()) == now + SECONDS_PER_YEAR, 14);
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    fun test_migrate_subdomain(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = address_of(user);
        let domain_name = utf8(b"test");
        let subdomain_name = utf8(b"sub");
        let subdomain_name_opt = option::some(subdomain_name);

        // Register with v1
        let now = timestamp::now_seconds();
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
        router::set_primary_name(user, domain_name, subdomain_name_opt);
        assert!(router::is_name_owner(user_addr, domain_name, subdomain_name_opt), 7);
        assert!(*option::borrow(&router::get_target_addr(domain_name, subdomain_name_opt)) == user_addr, 8);
        assert!(router::get_expiration(domain_name, option::none()) == now + SECONDS_PER_YEAR, 9);
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 10);
            assert!(*option::borrow(&primary_subdomain_name) == subdomain_name, 11);
        };

        // Bump mode
        router::set_mode(router, 1);

        // Attribtes should be the same
        assert!(router::is_name_owner(user_addr, domain_name, subdomain_name_opt), 7);
        assert!(*option::borrow(&router::get_target_addr(domain_name, subdomain_name_opt)) == user_addr, 8);
        assert!(router::get_expiration(domain_name, option::none()) == now + SECONDS_PER_YEAR, 9);
        assert!(router::get_expiration(domain_name, subdomain_name_opt) == now + SECONDS_PER_YEAR, 9);
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 10);
            assert!(*option::borrow(&primary_subdomain_name) == subdomain_name, 11);
        };

        // Migrate to v2
        router::migrate_name(user, domain_name, option::none());
        router::migrate_name(user, domain_name, subdomain_name_opt);
        assert!(router::is_name_owner(user_addr, domain_name, subdomain_name_opt), 7);
        assert!(*option::borrow(&router::get_target_addr(domain_name, subdomain_name_opt)) == user_addr, 8);
        // Auto-renewal will not happen for subdomain. Its expiration remains the same
        assert!(
            router::get_expiration(domain_name, subdomain_name_opt) == now + SECONDS_PER_YEAR,
            9
        );
        {
            let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
            assert!(*option::borrow(&primary_domain_name) == domain_name, 10);
            assert!(*option::borrow(&primary_subdomain_name) == subdomain_name, 11);
        };
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327688, location = router)]
    fun test_migrate_subdomain_as_non_owner(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user1, &aptos, user2, &foundation);
        let user1 = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);
        let domain_name = utf8(b"test");
        let subdomain_name = utf8(b"sub");
        let subdomain_name_opt = option::some(subdomain_name);

        // Register with v1
        router::register_domain(user1, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_subdomain(
            user1,
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

        // Migrate the domain name
        router::migrate_name(user1, domain_name, option::none());

        // Migration fails because user2 does not own `subdomain_name`
        router::migrate_name(user2, domain_name, subdomain_name_opt);
    }
}
