#[test_only]
module router::target_address_tests {
    use router::router;
    use router::test_helper;
    use std::option;
    use std::option::Option;
    use std::signer::address_of;
    use std::string::{utf8, String};
    use std::vector;
    use aptos_framework::object;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    inline fun get_v1_target_addr(
        domain_name: String,
        subdomain_name: Option<String>
    ): Option<address> {
        let (_property_version, _expiration_time_sec, target_addr) = aptos_names::domains::get_name_record_v1_props_for_name(
            subdomain_name,
            domain_name,
        );
        target_addr
    }

    /// Returns true if the name is tracked in v2
    inline fun exists_in_v2(domain_name: String, subdomain_name: Option<String>): bool {
        object::is_object(aptos_names_v2::domains::get_token_addr(domain_name, subdomain_name))
    }

    inline fun get_v2_target_addr(
        domain_name: String,
        subdomain_name: Option<String>
    ): Option<address> {
        if (!exists_in_v2(domain_name, subdomain_name)) {
            option::none()
        }else {
            let (_expiration_time_sec, target_addr) = aptos_names_v2::domains::get_name_record_props_for_name(
                subdomain_name,
                domain_name
            );
            target_addr
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
    fun test_set_target_address(
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
        let user2 = vector::borrow(&users, 1);
        let user_addr = address_of(user);
        let user2_addr = address_of(user2);
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

        // Domain target address should be default to user_addr
        {
            let target_address = get_v1_target_addr(domain_name, option::none());
            assert!(*option::borrow(&target_address) == user_addr, 1);
        };
        // Subdomain target address should be none, because we don't auto set target address in v1
        {
            let target_address = get_v1_target_addr(domain_name, subdomain_name_opt);
            assert!(option::is_none(&target_address), 2);
        };

        // Set domain target address to user2_addr
        router::set_target_addr(user, domain_name, option::none(), user2_addr);
        {
            let target_address = get_v1_target_addr(domain_name, option::none());
            assert!(*option::borrow(&target_address) == user2_addr, 3);
        };
        // Set subdomain target address to user2_addr
        router::set_target_addr(user, domain_name, subdomain_name_opt, user2_addr);
        {
            let target_address = get_v1_target_addr(domain_name, subdomain_name_opt);
            assert!(*option::borrow(&target_address) == user2_addr, 4);
        };

        // Clear domain target address
        router::clear_target_addr(user, domain_name, option::none());
        {
            let target_address = get_v1_target_addr(domain_name, option::none());
            assert!(option::is_none(&target_address), 5);
        };

        // Clear subdomain target address
        router::clear_target_addr(user, domain_name, subdomain_name_opt);
        {
            let target_address = get_v1_target_addr(domain_name, subdomain_name_opt);
            assert!(option::is_none(&target_address), 6);
        };

        // Bump mode
        router::set_mode(router, 1);

        // Target should still be cleared after version bump
        {
            let target_address = get_v2_target_addr(domain_name, option::none());
            assert!(option::is_none(&target_address), 7);
            let target_address = get_v2_target_addr(domain_name, subdomain_name_opt);
            assert!(option::is_none(&target_address), 8);
        };

        // Migrate domain and subdomain
        router::migrate_name(user, domain_name, option::none());
        router::migrate_name(user, domain_name, subdomain_name_opt);

        // Set domain target address to user2_addr
        router::set_target_addr(user, domain_name, option::none(), user2_addr);
        {
            let target_address = get_v2_target_addr(domain_name, option::none());
            assert!(*option::borrow(&target_address) == user2_addr, 3);
        };
        // Set subdomain target address to user2_addr
        router::set_target_addr(user, domain_name, subdomain_name_opt, user2_addr);
        {
            let target_address = get_v2_target_addr(domain_name, subdomain_name_opt);
            assert!(*option::borrow(&target_address) == user2_addr, 4);
        };

        // Clear domain target address
        router::clear_target_addr(user, domain_name, option::none());
        {
            let target_address = get_v2_target_addr(domain_name, option::none());
            assert!(option::is_none(&target_address), 5);
        };

        // Clear subdomain target address
        router::clear_target_addr(user, domain_name, subdomain_name_opt);
        {
            let target_address = get_v2_target_addr(domain_name, subdomain_name_opt);
            assert!(option::is_none(&target_address), 6);
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
    fun test_set_target_address_should_trigger_auto_migration(
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
        let user2 = vector::borrow(&users, 1);
        let user2_addr = address_of(user2);
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

        // Bump mode
        router::set_mode(router, 1);

        // Set domain target address to user2_addr, this should trigger auto migration
        router::set_target_addr(user, domain_name, option::none(), user2_addr);
        {
            assert!(aptos_names_v2::domains::is_owner_of_name(user_addr, option::none(), domain_name), 1);
            let v1_target_address = get_v1_target_addr(domain_name, option::none());
            assert!(option::is_none(&v1_target_address), 2);
            let v2_target_address = get_v2_target_addr(domain_name, option::none());
            assert!(*option::borrow(&v2_target_address) == user2_addr, 3);
        };
        // Set subdomain target address to user2_addr
        // This should throw ESUBDOMAIN_NOT_MIGRATED error because we do not auto migrate subdomain and set target address for v1 name in MODE_V1_AND_V2 is not allowed
        // User needs to migrate manually
        router::set_target_addr(user, domain_name, subdomain_name_opt, user2_addr);
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
    fun test_clear_target_address_should_trigger_auto_migration(
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

        // Bump mode
        router::set_mode(router, 1);

        // Clear domain target address, this should trigger auto migration
        router::clear_target_addr(user, domain_name, option::none());
        {
            assert!(aptos_names_v2::domains::is_owner_of_name(user_addr, option::none(), domain_name), 1);
            let v1_target_address = get_v1_target_addr(domain_name, option::none());
            assert!(option::is_none(&v1_target_address), 1);
            let v2_target_address = get_v2_target_addr(domain_name, option::none());
            assert!(option::is_none(&v2_target_address), 2);
        };
        // Clear subdomain target address
        // This should throw error ESUBDOMAIN_NOT_MIGRATED because we do not auto migrate subdomain and set target address for v1 name in MODE_V1_AND_V2 is not allowed
        // User needs to migrate manually
        router::clear_target_addr(user, domain_name, subdomain_name_opt);
    }
}
