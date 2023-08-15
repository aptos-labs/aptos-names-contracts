#[test_only]
module router::domain_admin_tests {
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
    fun test_domain_admin_transfer_subdomain(
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

        // Bump mode
        router::set_mode(router, 1);

        // Register with v1
        let domain_name = utf8(b"test1");
        let subdomain_name = utf8(b"sub1");
        router::register_domain(user1, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_subdomain(
            user1,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none()
        );
        assert!(router::is_name_owner(user1_addr, domain_name, option::some(subdomain_name)), 1);

        router::domain_admin_transfer_subdomain(user1, domain_name, subdomain_name, user2_addr, option::none());
        assert!(router::is_name_owner(user2_addr, domain_name, option::some(subdomain_name)), 1);
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
    fun test_domain_admin_set_subdomain_expiration_policy(
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

        // Bump mode
        router::set_mode(router, 1);

        // Register with v1
        let domain_name = utf8(b"test1");
        let subdomain_name = utf8(b"sub1");
        router::register_domain(user1, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_subdomain(
            user1,
            domain_name,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none()
        );
        assert!(router::get_subdomain_expiration_policy(domain_name, subdomain_name) == 0, 1);

        // Set it to 1
        router::domain_admin_set_subdomain_expiration_policy(
            user1,
            domain_name,
            subdomain_name,
            1,
        );
        assert!(router::get_subdomain_expiration_policy(domain_name, subdomain_name) == 1, 2);

        // Set it to 0
        router::domain_admin_set_subdomain_expiration_policy(
            user1,
            domain_name,
            subdomain_name,
            0,
        );
        assert!(router::get_subdomain_expiration_policy(domain_name, subdomain_name) == 0, 2);
    }
}
