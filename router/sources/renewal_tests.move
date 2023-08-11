#[test_only]
module router::renewal_tests {
    use router::router;
    use router::test_helper;
    use std::option;
    use std::string::utf8;
    use std::vector;
    use aptos_framework::timestamp;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;
    const ENOT_IMPLEMENTED_IN_MODE: u64 = 786436;

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
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user1, &aptos, user2, &foundation);
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
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user1, &aptos, user2, &foundation);
        let user = vector::borrow(&users, 0);
        let domain_name = utf8(b"test");

        // Bump mode to v2
        router::set_mode(router, 1);

        router::register_domain(user, domain_name, SECONDS_PER_YEAR);
        assert!(router::get_expiration(domain_name, option::none()) == SECONDS_PER_YEAR, 1);

        // Renewals only allowed within 6 months of expiration. Move time to 100 seconds before expiry.
        timestamp::update_global_time_for_test_secs(SECONDS_PER_YEAR - 100);
        router::renew_domain(user, domain_name, SECONDS_PER_YEAR);
        assert!(router::get_expiration(domain_name, option::none()) == SECONDS_PER_YEAR * 2, 2);
    }
}
