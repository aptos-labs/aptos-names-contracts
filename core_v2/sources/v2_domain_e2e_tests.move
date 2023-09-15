#[test_only]
module aptos_names_v2::v2_domain_e2e_tests {
    use aptos_framework::timestamp;
    use aptos_framework::object;
    use aptos_names_v2::v2_config;
    use aptos_names_v2::v2_domains;
    use aptos_names_v2::v2_test_helper;
    use aptos_names_v2::v2_test_utils;
    use std::option;
    use std::signer;
    use std::string;
    use std::vector;

    const MAX_REMAINING_TIME_FOR_RENEWAL_SEC: u64 = 15552000;
    const SECONDS_PER_DAY: u64 = 60 * 60 * 24;
    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_happy_path_e2e(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let user_addr = signer::address_of(user);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);

        // Set an address and verify it
        v2_test_helper::set_target_address(user, v2_test_helper::domain_name(),option::none(),  user_addr);

        // Ensure the owner can clear the address
        v2_test_helper::clear_target_address(user, option::none(), v2_test_helper::domain_name());

        // And also can clear if the user is the registered address, but not owner
        v2_test_helper::set_target_address(user, v2_test_helper::domain_name(), option::none(), signer::address_of(rando));
        v2_test_helper::clear_target_address(rando, option::none(), v2_test_helper::domain_name());

        // Set it back for following tests
        v2_test_helper::set_target_address(user, v2_test_helper::domain_name(), option::none(), user_addr);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_renew_domain_e2e(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());

        // Set the time is early than max remaining time for renewal from expiration time
        timestamp::update_global_time_for_test_secs(expiration_time_sec - MAX_REMAINING_TIME_FOR_RENEWAL_SEC - 5);
        assert!(!v2_domains::is_domain_in_renewal_window(v2_test_helper::domain_name()), 1);

        timestamp::update_global_time_for_test_secs(expiration_time_sec - MAX_REMAINING_TIME_FOR_RENEWAL_SEC + 5);
        assert!(v2_domains::is_domain_in_renewal_window(v2_test_helper::domain_name()), 2);

        // Renew the domain
        v2_domains::renew_domain(user, v2_test_helper::domain_name(), SECONDS_PER_YEAR);

        // Ensure the domain is still registered after the original expiration time
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);
        assert!(v2_domains::is_name_registered(v2_test_helper::domain_name(), option::none()), 4);

        let new_expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        // Ensure the domain is still expired after the new expiration time
        timestamp::update_global_time_for_test_secs(new_expiration_time_sec + 5);
        assert!(v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none()), 5);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_names_are_registerable_after_expiry(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);

        // Set the time past the domain's expiration time
        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        // It should now be: expired, registered, AND registerable
        assert!(v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none()), 80);
        assert!(v2_domains::is_name_registered(v2_test_helper::domain_name(), option::none()), 81);
        assert!(v2_domains::is_name_registerable(v2_test_helper::domain_name(), option::none()), 82);

        // Lets try to register it again, now that it is expired
        v2_test_helper::register_name(router_signer, rando, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 2);

        // Reverse lookup for |user| should be none.
        assert!(option::is_none(&v2_domains::get_reverse_lookup(signer::address_of(user))), 85);

        // And again!
        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        // It should now be: expired, registered, AND registerable
        assert!(v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none()), 80);
        assert!(v2_domains::is_name_registered(v2_test_helper::domain_name(), option::none()), 81);
        assert!(v2_domains::is_name_registerable(v2_test_helper::domain_name(), option::none()), 82);

        // Lets try to register it again, now that it is expired
        v2_test_helper::register_name(router_signer, rando, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 3);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 196611, location = aptos_names_v2::v2_domains)]
    fun test_no_double_domain_registrations(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        // Ensure we can't register it again
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327689, location = aptos_names_v2::v2_domains)]
    fun test_non_owner_can_not_set_target_address(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        // Ensure we can't set it as a rando. The expected target address doesn't matter as it won't get hit
        v2_test_helper::set_target_address(rando, v2_test_helper::domain_name(), option::none(), @aptos_names_v2);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327682, location = aptos_names_v2::v2_domains)]
    fun test_non_owner_can_not_clear_target_address(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain, and set its address
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        v2_test_helper::set_target_address(user,  v2_test_helper::domain_name(), option::none(),signer::address_of(user));

        // Ensure we can't clear it as a rando
        v2_test_helper::clear_target_address(rando, option::none(), v2_test_helper::domain_name());
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_owner_can_clear_domain_address(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain, and set its address
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        v2_test_helper::set_target_address(user, v2_test_helper::domain_name(), option::none(), signer::address_of(rando));

        // Ensure we can clear as owner
        v2_test_helper::clear_target_address(user, option::none(), v2_test_helper::domain_name());
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_target_addr_owner_can_clear_target_address(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain, and set its address
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        v2_test_helper::set_target_address(user, v2_test_helper::domain_name(), option::none(), signer::address_of(rando));

        // Ensure we can clear as owner
        v2_test_helper::clear_target_address(rando, option::none(), v2_test_helper::domain_name());
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_get_target_address_for_domain(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        v2_test_helper::set_target_address(user, v2_test_helper::domain_name(),option::none(),  user_addr);
        let target_address = v2_domains::get_target_address(v2_test_helper::domain_name(), option::none());
        assert!(target_address == option::some(user_addr), 2);

        timestamp::update_global_time_for_test_secs(v2_test_helper::one_year_secs() + 5);
        let target_address = v2_domains::get_target_address(v2_test_helper::domain_name(), option::none());
        assert!(option::is_none(&target_address), 3);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_get_expiration_for_domain(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        v2_test_helper::set_target_address(user, v2_test_helper::domain_name(),option::none(),  user_addr);
        let expiration_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        assert!(expiration_sec == v2_test_helper::one_year_secs(), 1);
    }


    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_get_reverse_lookup_for_domain(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        aptos_names_v2::v2_domains::set_reverse_lookup(user, option::none(), v2_test_helper::domain_name());
        let token_addr = v2_domains::get_token_addr(v2_test_helper::domain_name(), option::none());
        assert!(v2_domains::get_reverse_lookup(user_addr) == option::some(token_addr), 1);

        timestamp::update_global_time_for_test_secs(v2_test_helper::one_year_secs() + 5);
        assert!(option::is_none(&v2_domains::get_reverse_lookup(user_addr)), 1);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_admin_can_force_set_target_address_e2e(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        v2_test_helper::register_name(router_signer,
            user,
            option::none(),
            v2_test_helper::domain_name(),
            v2_test_helper::one_year_secs(),
            v2_test_helper::fq_domain_name(),
            1,
        );

        v2_domains::force_set_target_address(aptos_names_v2, v2_test_helper::domain_name(), option::none(), rando_addr);
        let target_address = v2_domains::get_target_address(v2_test_helper::domain_name(), option::none());
        v2_test_utils::print_actual_expected(b"set_domain_address: ", target_address, option::some(rando_addr), false);
        assert!(target_address == option::some(rando_addr), 33);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::v2_config)]
    fun test_rando_cant_force_set_target_address_e2e(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);

        // Rando is not allowed to do this
        v2_domains::force_set_target_address(rando, v2_test_helper::domain_name(), option::none(), rando_addr);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_admin_can_force_renew_domain_name(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        let is_owner = v2_domains::is_token_owner(signer::address_of(user), v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 1);

        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        assert!(
            expiration_time_sec / SECONDS_PER_YEAR == 1, expiration_time_sec / SECONDS_PER_YEAR);

        // renew the domain by admin outside of renewal window
        v2_domains::force_set_name_expiration(aptos_names_v2, v2_test_helper::domain_name(), option::none(), timestamp::now_seconds() + 2 * v2_test_helper::one_year_secs());

        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        assert!(
            expiration_time_sec / SECONDS_PER_YEAR == 2, expiration_time_sec / SECONDS_PER_YEAR);
    }


    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_admin_can_force_seize_domain_name(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        let is_owner = v2_domains::is_token_owner(signer::address_of(user), v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 1);

        // Take the domain name for much longer than users are allowed to register it for
        v2_domains::force_create_or_seize_name(aptos_names_v2, v2_test_helper::domain_name(), option::none(), v2_test_helper::two_hundred_year_secs());
        let is_owner = v2_domains::is_token_owner(signer::address_of(aptos_names_v2), v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        assert!(
            expiration_time_sec / SECONDS_PER_YEAR == 200, expiration_time_sec / SECONDS_PER_YEAR);

        // Ensure that the user's primary name is no longer set.
        assert!(option::is_none(&v2_domains::get_reverse_lookup(user_addr)), 1);
    }

    #[test(
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_admin_can_force_create_domain_name(
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let _ = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);

        // No domain is registered yet
        assert!(!v2_domains::is_name_registered(v2_test_helper::domain_name(), option::none()), 1);

        // Take the domain name for much longer than users are allowed to register it for
        v2_domains::force_create_or_seize_name(aptos_names_v2, v2_test_helper::domain_name(), option::none(), v2_test_helper::two_hundred_year_secs());
        let is_owner = v2_domains::is_token_owner(signer::address_of(aptos_names_v2), v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        assert!(
            expiration_time_sec / SECONDS_PER_YEAR == 200, expiration_time_sec / SECONDS_PER_YEAR);

        // Try to nuke the domain
        assert!(v2_domains::is_name_registered(v2_test_helper::domain_name(), option::none()), 3);
        v2_domains::force_clear_registration(aptos_names_v2, v2_test_helper::domain_name(), option::none());
        assert!(!v2_domains::is_name_registered(v2_test_helper::domain_name(), option::none()), 4);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::v2_config)]
    fun test_rando_cant_force_seize_domain_name(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        let is_owner = v2_domains::is_token_owner(signer::address_of(user), v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 1);

        // Take the domain name for much longer than users are allowed to register it for
        v2_domains::force_create_or_seize_name(rando, v2_test_helper::domain_name(), option::none(), v2_test_helper::two_hundred_year_secs());
    }

    #[test(
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::v2_config)]
    fun test_rando_cant_force_create_domain_name(
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let rando = vector::borrow(&users, 1);

        // No domain is registered yet
        assert!(!v2_domains::is_name_registered(v2_test_helper::domain_name(), option::none()), 1);

        // Take the domain name for much longer than users are allowed to register it for
        v2_domains::force_create_or_seize_name(rando, v2_test_helper::domain_name(), option::none(), v2_test_helper::two_hundred_year_secs());
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_clear_name_happy_path_e2e(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);

        // Clear my reverse lookup.
        v2_domains::clear_reverse_lookup(user);

        assert!(option::is_none(&v2_domains::get_reverse_lookup(user_addr)), 1);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_owner_of_expired_name_is_not_owner(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        v2_test_helper::register_name(router_signer, user, option::none(), v2_test_helper::domain_name(), v2_test_helper::one_year_secs(), v2_test_helper::fq_domain_name(), 1);
        let is_owner = v2_domains::is_token_owner(user_addr, v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 1);

        // Set the time past the domain's expiration time
        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        let is_owner = v2_domains::is_token_owner(signer::address_of(user), v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && is_expired, 1);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_transfer(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);

        // Register the domain
        v2_test_helper::register_name(router_signer,
            user,
            option::none(),
            v2_test_helper::domain_name(),
            v2_test_helper::one_year_secs(),
            v2_test_helper::fq_domain_name(),
            1,
        );

        // user is owner
        {
            let is_owner = v2_domains::is_token_owner(user_addr, v2_test_helper::domain_name(), option::none());
            let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
            assert!(is_owner && !is_expired, 1);
        };

        let token_addr = v2_domains::get_token_addr(v2_test_helper::domain_name(), option::none());
        object::transfer_raw(user, token_addr, rando_addr);

        // rando is owner
        {
            let is_owner = v2_domains::is_token_owner(rando_addr, v2_test_helper::domain_name(), option::none());
            let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
            assert!(is_owner && !is_expired, 1);
        };
    }

    #[test(
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_nonregistered_record_expiry(
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);

        // Non-registered domain should be expired
        {
            let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
            assert!(is_expired, 1);
        };

        // Non-registered subdomain should be expired
        {
            let is_expired = v2_domains::is_name_expired(
                v2_test_helper::domain_name(),
                option::some(v2_test_helper::subdomain_name()),
            );
            assert!(is_expired, 1);
        };
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 393221, location = aptos_names_v2::v2_domains)]
    fun test_cannot_set_unregistered_name_as_primary_name(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        v2_test_helper::register_name(
            router_signer,
            user,
            option::none(),
            v2_test_helper::domain_name(),
            v2_test_helper::one_year_secs(),
            v2_test_helper::fq_domain_name(),
            1
        );

        // Set a not exist domain as primary name, should trigger ENAME_NOT_EXIST error
        aptos_names_v2::v2_domains::set_reverse_lookup(user, option::none(), string::utf8(b"notexist"));
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 196611, location = aptos_names_v2::v2_domains)]
    fun test_register_during_reregistration_grace(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Set the reregistration grace period to 30 days
        v2_config::set_reregistration_grace_sec(aptos_names_v2, 30 * SECONDS_PER_DAY);

        // Register the domain
        v2_test_helper::register_name(
            router_signer,
            user,
            option::none(),
            v2_test_helper::domain_name(),
            v2_test_helper::one_year_secs(),
            v2_test_helper::fq_domain_name(),
            1
        );

        let is_owner = v2_domains::is_token_owner(user_addr, v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 1);

        // Set the time right before the domain's expiration time + grace period
        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + v2_config::reregistration_grace_sec());

        // Is still owner but name has expired
        let is_owner = v2_domains::is_token_owner(user_addr, v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && is_expired, 1);

        // Register the domain again. Should fail because it's still in the grace period
        v2_test_helper::register_name(
            router_signer,
            user,
            option::none(),
            v2_test_helper::domain_name(),
            v2_test_helper::one_year_secs(),
            v2_test_helper::fq_domain_name(),
            1
        );
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_register_after_reregistration_grace(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
    ) {
        let users = v2_test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Set the reregistration grace period to 30 days
        v2_config::set_reregistration_grace_sec(aptos_names_v2, 30 * SECONDS_PER_DAY);

        // Register the domain
        v2_test_helper::register_name(
            router_signer,
            user,
            option::none(),
            v2_test_helper::domain_name(),
            v2_test_helper::one_year_secs(),
            v2_test_helper::fq_domain_name(),
            1
        );

        let is_owner = v2_domains::is_token_owner(user_addr, v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && !is_expired, 1);

        // Set the time right before the domain's expiration time + grace period
        let expiration_time_sec = v2_domains::get_expiration(v2_test_helper::domain_name(), option::none());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + v2_config::reregistration_grace_sec() + 1);

        // Is still owner but name has expired
        let is_owner = v2_domains::is_token_owner(user_addr, v2_test_helper::domain_name(), option::none());
        let is_expired = v2_domains::is_name_expired(v2_test_helper::domain_name(), option::none());
        assert!(is_owner && is_expired, 1);

        // Register the domain again. Should succeeds because it's out of the grace period
        v2_test_helper::register_name(
            router_signer,
            user,
            option::none(),
            v2_test_helper::domain_name(),
            v2_test_helper::one_year_secs(),
            v2_test_helper::fq_domain_name(),
            1
        );
    }
}
