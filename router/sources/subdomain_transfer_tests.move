#[test_only]
module router::subdomain_transfer_tests {
    use router::router;
    use router::test_helper;
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
    #[expected_failure(abort_code = 327683, location = aptos_framework::object)]
    fun test_register_subdomain_with_subdomain_owner_transfer_disabled(
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
        let user1 = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);
        let user1_addr = address_of(user1);
        let user2_addr = address_of(user2);
        let domain_name = utf8(b"test1");
        let subdomain_name = utf8(b"sub");
        let subdomain_name_opt = option::some(subdomain_name);

        router::set_mode(router, 1);

        // Register domain
        router::register_domain(user1, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        // Register subdomain and disable owner transfer
        router::register_subdomain(
            user1,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::some(user2_addr),
            option::some(user2_addr),
        );
        assert!(router::is_name_owner(user2_addr, domain_name, subdomain_name_opt), 0);
        // Subdomain owner should not be able to transfer it now
        router::transfer_name(user2, domain_name, subdomain_name_opt, user1_addr);
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
    #[expected_failure(abort_code = 327683, location = aptos_framework::object)]
    fun test_register_subdomain_with_subdomain_owner_transfer_enabled_and_disable_subdomain_owner_transfer(
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
        let user1 = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);
        let user1_addr = address_of(user1);
        let user2_addr = address_of(user2);
        let domain_name = utf8(b"test1");
        let subdomain_name = utf8(b"sub");
        let subdomain_name_opt = option::some(subdomain_name);

        router::set_mode(router, 1);

        // Register domain
        router::register_domain(user1, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        // Register subdomain and disable owner transfer
        router::register_subdomain(
            user1,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            true,
            option::some(user2_addr),
            option::some(user2_addr),
        );
        assert!(router::is_name_owner(user2_addr, domain_name, subdomain_name_opt), 0);
        // Disable owner transfer as domain admin
        router::domain_admin_set_subdomain_transferability(user1, domain_name, subdomain_name, false);
        // Subdomain owner should not be able to transfer it now
        router::transfer_name(user2, domain_name, subdomain_name_opt, user1_addr);
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
    fun test_register_subdomain_with_subdomain_owner_transfer_disabled_and_enable_subdomain_owner_transfer(
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
        let user1 = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);
        let user1_addr = address_of(user1);
        let user2_addr = address_of(user2);
        let domain_name = utf8(b"test1");
        let subdomain_name = utf8(b"sub");
        let subdomain_name_opt = option::some(subdomain_name);

        router::set_mode(router, 1);

        // Register domain
        router::register_domain(user1, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        // Register subdomain and disable owner transfer
        router::register_subdomain(
            user1,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::some(user2_addr),
            option::some(user2_addr),
        );
        assert!(router::is_name_owner(user2_addr, domain_name, subdomain_name_opt), 0);
        // Enable owner transfer as domain admin
        router::domain_admin_set_subdomain_transferability(user1, domain_name, subdomain_name, true);
        // Subdomain owner should be able to transfer it now
        router::transfer_name(user2, domain_name, subdomain_name_opt, user1_addr);
        assert!(router::is_name_owner(user1_addr, domain_name, subdomain_name_opt), 1);
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
    fun test_register_subdomain_with_subdomain_owner_transfer_disabled_and_domain_admin_can_still_transfer(
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
        let user1 = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);
        let user1_addr = address_of(user1);
        let user2_addr = address_of(user2);
        let domain_name = utf8(b"test1");
        let subdomain_name = utf8(b"sub");
        let subdomain_name_opt = option::some(subdomain_name);

        router::set_mode(router, 1);

        // Register domain
        router::register_domain(user1, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        // Register subdomain and disable owner transfer
        router::register_subdomain(
            user1,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::some(user2_addr),
            option::some(user2_addr),
        );
        assert!(router::is_name_owner(user2_addr, domain_name, subdomain_name_opt), 0);
        // Domain admin should still be able to transfer subdomain
        router::domain_admin_transfer_subdomain(user1, domain_name, subdomain_name, user1_addr);
        assert!(router::is_name_owner(user1_addr, domain_name, subdomain_name_opt), 0);
    }
}
