#[test_only]
module bulk::bulk_tests {
    use aptos_framework::timestamp;
    use bulk::bulk::{bulk_renew_domain, bulk_migrate_domain, bulk_migrate_subdomain};
    use router::router;
    use router::router_test_helper;
    use std::option;
    use std::signer;
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
    fun test_bulk_migrate_happy_path(
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
        let user1_addr = signer::address_of(user1);
        let domain_name1 = utf8(b"test1");
        let domain_name2 = utf8(b"test2");
        let subdomain_name = utf8(b"sub");
        let subdomain_name_opt = option::some(subdomain_name);

        // Register with v1
        router::register_domain(user1, domain_name1, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_domain(user1, domain_name2, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_subdomain(
            user1,
            domain_name1,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none(),
        );
        router::register_subdomain(
            user1,
            domain_name2,
            subdomain_name,
            SECONDS_PER_YEAR,
            0,
            false,
            option::none(),
            option::none(),
        );

        // Bump mode
        router::set_mode(router, 1);

        bulk_migrate_domain(
            user1,
            vector [
                domain_name1,
                domain_name2,
            ]
        );
        bulk_migrate_subdomain(
            user1,
            vector [
                domain_name1,
                domain_name2,
            ], vector [
                subdomain_name_opt,
                subdomain_name_opt,
            ]
        );

        // Verify names no longer exist in v1
        {
            let (is_owner, _) = aptos_names::domains::is_owner_of_name(user1_addr, option::none(), domain_name1);
            assert!(!is_owner, 1);
            let (is_owner, _) = aptos_names::domains::is_owner_of_name(user1_addr, subdomain_name_opt, domain_name1);
            assert!(!is_owner, 2);
            let (is_owner, _) = aptos_names::domains::is_owner_of_name(user1_addr, option::none(), domain_name2);
            assert!(!is_owner, 2);
            let (is_owner, _) = aptos_names::domains::is_owner_of_name(user1_addr, subdomain_name_opt, domain_name2);
            assert!(!is_owner, 2);
        };

        // Verify names exist in v2 now
        {
            assert!(
                aptos_names_v2::v2_domains::is_token_owner(
                    user1_addr,
                    domain_name1,
                    option::none()
                ) && !aptos_names_v2::v2_domains::is_name_expired(domain_name1, option::none()),
                3
            );
            assert!(
                aptos_names_v2::v2_domains::is_token_owner(
                    user1_addr,
                    domain_name1,
                    subdomain_name_opt,
                ) && !aptos_names_v2::v2_domains::is_name_expired(domain_name1, subdomain_name_opt),
                4
            );
            assert!(
                aptos_names_v2::v2_domains::is_token_owner(
                    user1_addr,
                    domain_name2,
                    option::none()
                ) && !aptos_names_v2::v2_domains::is_name_expired(domain_name2, option::none()),
                3
            );
            assert!(
                aptos_names_v2::v2_domains::is_token_owner(
                    user1_addr,
                    domain_name2,
                    subdomain_name_opt,
                ) && !aptos_names_v2::v2_domains::is_name_expired(domain_name2, subdomain_name_opt),
                4
            );
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
    fun test_bulk_renew_happy_path(
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
        let domain_name = utf8(b"test");

        // Bump mode
        router::set_mode(router, 1);

        // Register with v2
        router::register_domain(user1, domain_name, SECONDS_PER_YEAR, option::none(), option::none());

        // Update time to 7 months later
        timestamp::update_global_time_for_test_secs(60 * 60 * 24 * 30 * 7);

        bulk_renew_domain(user1, vector [ domain_name ], vector [ SECONDS_PER_YEAR ]);

        // Verify names new expiration
        let expiration = router::get_expiration(domain_name, option::none());
        assert!(expiration == SECONDS_PER_YEAR * 2, 1);
    }
}
