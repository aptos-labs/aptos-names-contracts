#[test_only]
module router::primary_name_tests {
    use router::router;
    use router::test_helper;
    use std::option;
    use std::option::Option;
    use std::signer::address_of;
    use std::string::{utf8, String};
    use std::vector;
    use aptos_framework::object;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    inline fun get_v1_primary_name(
        user_addr: address
    ): (Option<String>, Option<String>) {
        let record = aptos_names::domains::get_reverse_lookup(user_addr);
        if (option::is_none(&record)) {
            (option::none(), option::none())
        } else {
            let (subdomain_name, domain_name) = aptos_names::domains::get_name_record_key_v1_props(
                option::borrow(&record)
            );
            (subdomain_name, option::some(domain_name))
        }
    }

    /// Returns true if the name is tracked in v2
    inline fun exists_in_v2(domain_name: String, subdomain_name: Option<String>): bool {
        object::is_object(aptos_names_v2::domains::get_token_addr(domain_name, subdomain_name))
    }

    inline fun get_v2_primary_name(
        user_addr: address
    ): (Option<String>, Option<String>) {
        let token_addr = aptos_names_v2::domains::get_reverse_lookup(user_addr);
        if (option::is_none(&token_addr)) {
            (option::none(), option::none())
        } else {
            let (subdomain_name, domain_name) = aptos_names_v2::domains::get_record_props_from_token_addr(
                *option::borrow(&token_addr)
            );
            (subdomain_name, option::some(domain_name))
        }
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
    fun test_set_primary_name_when_register(
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

        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());

        let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
        assert!(*option::borrow(&primary_domain_name) == domain_name, 1);
        assert!(option::is_none(&primary_subdomain_name), 2);

        // Bump mode
        router::set_mode(router, 1);

        let user = vector::borrow(&users, 1);
        let user_addr = address_of(user);
        let domain_name = utf8(b"test1");

        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());

        let (primary_subdomain_name, primary_domain_name) = router::get_primary_name(user_addr);
        assert!(*option::borrow(&primary_domain_name) == domain_name, 1);
        assert!(option::is_none(&primary_subdomain_name), 2);
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
            option::none(),
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

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 65545, location = router::router)]
    fun test_set_primary_name_should_trigger_auto_migration(
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
        let domain_name2 = utf8(b"test2");
        let subdomain_name = utf8(b"test");
        let subdomain_name2 = utf8(b"test2");
        let subdomain_name_opt2 = option::some(subdomain_name2);

        // Register with v1
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_domain(user, domain_name2, SECONDS_PER_YEAR, option::none(), option::none());

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

        router::set_primary_name(user, domain_name, option::none());

        // Bump mode
        router::set_mode(router, 1);

        // Set primary name to domain2, this should trigger auto migration
        router::set_primary_name(user, domain_name2, option::none());
        {
            // domain2 should be successfully migrated to v2
            assert!(aptos_names_v2::domains::is_owner_of_name(user_addr, option::none(), domain_name2), 1);
            // v1 primary name should be cleared
            let (_, v1_primary_domain_name) = get_v1_primary_name(user_addr);
            assert!(option::is_none(&v1_primary_domain_name), 2);
            // v2 primary name should be properly set to domain2
            let (v2_primary_subdomain_name, v2_primary_domain_name) = get_v2_primary_name(user_addr);
            assert!(v2_primary_domain_name == option::some(domain_name2), 3);
            assert!(option::is_none(&v2_primary_subdomain_name), 4);
        };
        // Set primary name to subdomain2
        // This should throw ESUBDOMAIN_NOT_MIGRATED error because we do not auto migrate subdomain and set primary name for v1 name in MODE_V1_AND_V2 is not allowed
        // User needs to migrate manually
        router::set_primary_name(user, domain_name2, subdomain_name_opt2);
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
    fun test_clear_domain_primary_name_should_trigger_auto_migration(
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

        router::set_primary_name(user, domain_name, option::none());

        // Bump mode
        router::set_mode(router, 1);

        // Clear domain primary name, this should trigger auto migration of previous primary name
        router::clear_primary_name(user);
        {
            // domain should be successfully migrated to v2
            let (is_owner_of_v1_name, _) = aptos_names::domains::is_owner_of_name(user_addr, option::none(), domain_name);
            assert!(!is_owner_of_v1_name, 1);
            assert!(aptos_names_v2::domains::is_owner_of_name(user_addr, option::none(), domain_name), 2);
            // v1 primary name should be cleared
            let (v1_primary_subdomain_name, v1_primary_domain_name) = get_v1_primary_name(user_addr);
            assert!(option::is_none(&v1_primary_domain_name), 3);
            assert!(option::is_none(&v1_primary_subdomain_name), 4);
            // v2 primary name should be empty
            let (v2_primary_subdomain_name, v2_primary_domain_name) = get_v2_primary_name(user_addr);
            assert!(option::is_none(&v2_primary_domain_name), 5);
            assert!(option::is_none(&v2_primary_subdomain_name), 6);
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
    fun test_clear_subdomain_primary_name_should_not_trigger_auto_migration(
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
            option::none(),
        );

        router::set_primary_name(user, domain_name, subdomain_name_opt);

        // Bump mode
        router::set_mode(router, 1);

        // Clear subdomain primary name
        // This should not auto migrate the previous primary name because we do not auto migrate subdomain
        router::clear_primary_name(user);
        {
            // subdomain should still remain in v1
            let (is_owner_of_v1_name, _) = aptos_names::domains::is_owner_of_name(user_addr, subdomain_name_opt, domain_name);
            assert!(is_owner_of_v1_name, 1);
            assert!(!aptos_names_v2::domains::is_owner_of_name(user_addr, subdomain_name_opt, domain_name), 2);
            // v1 primary name should be cleared
            let (v1_primary_subdomain_name, v1_primary_domain_name) = get_v1_primary_name(user_addr);
            assert!(option::is_none(&v1_primary_domain_name), 2);
            assert!(option::is_none(&v1_primary_subdomain_name), 3);
            // v2 primary name should be empty
            let (v2_primary_subdomain_name, v2_primary_domain_name) = get_v2_primary_name(user_addr);
            assert!(option::is_none(&v2_primary_domain_name), 4);
            assert!(option::is_none(&v2_primary_subdomain_name), 5);
        };
    }
}