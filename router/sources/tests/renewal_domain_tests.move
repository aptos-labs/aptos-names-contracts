#[test_only]
module router::renewal_domain_tests {
    use router::router;
    use router::router_test_helper;
    use std::option;
    use std::option::Option;
    use std::signer;
    use std::string::{utf8, String};
    use std::vector;
    use aptos_framework::timestamp;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;
    const ENOT_IMPLEMENTED_IN_MODE: u64 = 786436;
    const AUTO_RENEWAL_EXPIRATION_CUTOFF_SEC: u64 = 1709855999;

    inline fun get_v1_expiration(
        domain_name: String,
        subdomain_name: Option<String>
    ): u64 {
        let (_property_version, expiration_time_sec, _target_addr) = aptos_names::domains::get_name_record_v1_props_for_name(
            subdomain_name,
            domain_name,
        );
        expiration_time_sec
    }

    inline fun get_v2_expiration(
        domain_name: String,
        subdomain_name: Option<String>
    ): u64 {
        let expiration_time_sec = aptos_names_v2::v2_domains::get_expiration(domain_name, subdomain_name);
        expiration_time_sec
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
    #[expected_failure(abort_code = ENOT_IMPLEMENTED_IN_MODE, location = router)]
    fun test_renew_domain_in_v1(
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

        router::renew_domain(user, domain_name, SECONDS_PER_YEAR);
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
    fun test_renew_domain_in_v2(
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

        // Bump mode to v2
        router::set_mode(router, 1);

        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        assert!(router::get_expiration(domain_name, option::none()) == SECONDS_PER_YEAR, 1);

        // Renewals only allowed within 6 months of expiration. Move time to 100 seconds before expiry.
        timestamp::update_global_time_for_test_secs(SECONDS_PER_YEAR - 100);
        router::renew_domain(user, domain_name, SECONDS_PER_YEAR);
        assert!(router::get_expiration(domain_name, option::none()) == SECONDS_PER_YEAR * 2, 2);
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
    fun test_renew_v1_name_not_eligible_for_free_extension_should_trigger_auto_migration(
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
        let user_addr = signer::address_of(user);
        let domain_name = utf8(b"test");

        // update global time to next year so domain is not eligibal for free 1 year extension
        timestamp::update_global_time_for_test_secs(AUTO_RENEWAL_EXPIRATION_CUTOFF_SEC);
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());

        // Bump mode to v2
        router::set_mode(router, 1);

        // Make v1 read only except for admin
        aptos_names::config::set_is_enabled(aptos_names, false);

        // Renewals only allowed within 6 months of expiration. Move time to 100 seconds before expiry.
        timestamp::update_global_time_for_test_secs(AUTO_RENEWAL_EXPIRATION_CUTOFF_SEC + SECONDS_PER_YEAR - 100);
        router::renew_domain(user, domain_name, SECONDS_PER_YEAR);
        // Domain should be auto migrated to v2 and renewed with 1 year
        {
            // v1 name should be burnt now, i.e. not owned by the user now
            let (is_v1_owner, _) = aptos_names::domains::is_token_owner(user_addr, option::none(), domain_name);
            assert!(!is_v1_owner, 1);
            // v2 name should be owned by user
            assert!(aptos_names_v2::v2_domains::is_token_owner(user_addr, domain_name, option::none()), 2);
            assert!(!aptos_names_v2::v2_domains::is_name_expired(domain_name, option::none()), 3);
            // v2 name expiration should be 1 year after original expiration
            assert!(
                get_v2_expiration(
                    domain_name,
                    option::none()
                ) == AUTO_RENEWAL_EXPIRATION_CUTOFF_SEC + SECONDS_PER_YEAR * 2,
                get_v2_expiration(domain_name, option::none())
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
    #[expected_failure(abort_code = 196626, location = aptos_names_v2::v2_domains)]
    fun test_renew_v1_name_eligible_for_free_extension_should_trigger_auto_migration_and_fail(
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

        // Do not update system time so domain is eligibal for free 1 year extension
        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());

        // Bump mode to v2
        router::set_mode(router, 1);

        // Renewals only allowed within 6 months of expiration. Move time to 100 seconds before expiry.
        timestamp::update_global_time_for_test_secs( SECONDS_PER_YEAR - 100);
        // Expect to fail due to EDOMAIN_NOT_AVAILABLE_TO_RENEW during renew because migration already renew for free 1 year extension
        router::renew_domain(user, domain_name, SECONDS_PER_YEAR);
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
    fun test_renew_expired_but_still_in_grace_period_domain_in_v2(
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

        // Bump mode to v2
        router::set_mode(router, 1);

        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        assert!(router::get_expiration(domain_name, option::none()) == SECONDS_PER_YEAR, 1);

        // Renewals only allowed [expiration - 6 month, expiration + grace period]. Move time to 100 seconds after expiry.
        // We should be able to renew since it's within the 1 month grace period
        timestamp::update_global_time_for_test_secs(SECONDS_PER_YEAR + 100);
        router::renew_domain(user, domain_name, SECONDS_PER_YEAR);
        // New expiration date is 1 year after original expiration date
        assert!(router::get_expiration(domain_name, option::none()) == SECONDS_PER_YEAR * 2, 2);
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
    #[expected_failure(abort_code = 196639, location = aptos_names_v2::v2_domains)]
    fun test_cannot_renew_expired_past_grace_period_domain_in_v2(
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

        // Bump mode to v2
        router::set_mode(router, 1);

        router::register_domain(user, domain_name, SECONDS_PER_YEAR, option::none(), option::none());
        assert!(router::get_expiration(domain_name, option::none()) == SECONDS_PER_YEAR, 1);

        // Renewals only allowed [expiration - 6 month, expiration + grace period]. Move time to 1 year after expiry.
        // We should not be able to renew since it's past the 1 month grace period
        timestamp::update_global_time_for_test_secs(SECONDS_PER_YEAR * 2);
        router::renew_domain(user, domain_name, SECONDS_PER_YEAR);
    }
}
