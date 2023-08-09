#[test_only]
module aptos_names_v2::subdomain_e2e_tests {
    use aptos_framework::timestamp;
    use aptos_names_v2::domains;
    use aptos_names_v2::test_utils;
    use aptos_names_v2::test_helper;
    use std::option;
    use std::signer;
    use std::vector;
    use aptos_names_v2::time_helper;

    const MAX_REMAINING_TIME_FOR_RENEWAL_SEC: u64 = 15552000;

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun happy_path_e2e_test(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());

        // Set an address and verify it
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), user_addr);

        // Ensure the owner can clear the address
        test_helper::clear_target_address(user, option::none(), test_helper::domain_name());

        // And also can clear if the user is the registered address, but not owner
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));
        test_helper::clear_target_address(rando, option::none(), test_helper::domain_name());

        // Set it back for following tests
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), user_addr);

        // Register a subdomain!
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());

        // Set a subdomain address and verify it
        test_helper::set_target_address(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), user_addr);

        // Ensure these also work :-)
        test_helper::clear_target_address(user, option::some(test_helper::subdomain_name()), test_helper::domain_name());

        // And also can clear if is registered address, but not owner
        test_helper::set_target_address(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), signer::address_of(rando));
        test_helper::clear_target_address(rando, option::some(test_helper::subdomain_name()), test_helper::domain_name());
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_renew_domain_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());

        // Set the time is early than max remaining time for renewal from expiration time
        timestamp::update_global_time_for_test_secs(expiration_time_sec - MAX_REMAINING_TIME_FOR_RENEWAL_SEC - 5);
        assert!(!domains::is_domain_in_renewal_window(test_helper::domain_name()), 1);

        timestamp::update_global_time_for_test_secs(expiration_time_sec - MAX_REMAINING_TIME_FOR_RENEWAL_SEC + 5);
        assert!(domains::is_domain_in_renewal_window(test_helper::domain_name()), 2);

        // Renew the domain
        domains::renew_domain(user, test_helper::domain_name(), time_helper::years_to_seconds(1));

        // Ensure the domain is still registered after the original expiration time
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 4);

        let (new_expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        // Ensure the domain is still expired after the new expiration time
        timestamp::update_global_time_for_test_secs(new_expiration_time_sec + 5);
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 5);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_auto_renew_subdomain_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());

        // Register a subdomain!
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), timestamp::now_seconds() + test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>());
        assert!(domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 0, 2);
        // The subdomain auto-renewal policy is set to auto_renew
        domains::set_subdomain_renewal_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 1);
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), timestamp::now_seconds() + test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        // The subdomain auto-renewal policy is true by default
        assert!(domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 1, 2);

        // Renew the domain (and the subdomain should be auto renewed)
        let (original_expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::some(test_helper::subdomain_name()), test_helper::domain_name());
        timestamp::update_global_time_for_test_secs(original_expiration_time_sec - 5);
        domains::renew_domain(user, test_helper::domain_name(), time_helper::years_to_seconds(1));
        // Set the time past the domain's expiration time
        timestamp::update_global_time_for_test_secs(original_expiration_time_sec + 5);
        // Both domain and subdomain are not expired
        assert!(!domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(!domains::name_is_expired(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 80);
     }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 65562, location = aptos_names_v2::domains)]
    fun test_set_subdomain_renewal_policy(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());

        // Register a subdomain!
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>());
        assert!(domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 0, 2);
        // test set the policy to auto-renewal
        domains::set_subdomain_renewal_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 1);
        assert!(domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 1, 3);

        // test set the policy to something not exist
        domains::set_subdomain_renewal_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 100);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_manual_renew_subdomain_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        // Register a subdomain!
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>());
        domains::set_subdomain_renewal_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 0);
        assert!(domains::get_subdomain_renewal_policy(test_helper::domain_name(), test_helper::subdomain_name()) == 0, 2);

        // Set the time past the domain's expiration time
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::some(test_helper::subdomain_name()), test_helper::domain_name());
        // Renew the domain before it's expired
        timestamp::update_global_time_for_test_secs(expiration_time_sec - 5);
        domains::renew_domain(user, test_helper::domain_name(), time_helper::years_to_seconds(1));
        // Set the time past the domain's expiration time
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);
        // Ensure the subdomain is still expired after domain renewal
        assert!(!domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(domains::name_is_expired(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 80);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_transfer_subdomain(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);
        // create the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());

        // user is the owner of domain
        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // transfer the subdomain to rando
        domains::transfer_subdomain_owner(user, test_helper::subdomain_name(), test_helper::domain_name(), rando_addr, option::some(rando_addr));

        // rando owns the subdomain
        let is_owner = domains::is_owner_of_name(rando_addr, option::some(test_helper::subdomain_name()), test_helper::domain_name());
        assert!(is_owner, 2);

        {
            // when rando owns the subdomain and user owns the domain, user can still transfer the subdomain.
            domains::transfer_subdomain_owner(
                user,
                test_helper::subdomain_name(),
                test_helper::domain_name(),
                user_addr,
                option::some(user_addr)
            );
            let is_owner = domains::is_owner_of_name(
                user_addr,
                option::some(test_helper::subdomain_name()),
                test_helper::domain_name()
            );
            assert!(is_owner, 1);
        }
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327686, location = aptos_names_v2::domains)]
    fun test_non_domain_owner_transfer_domain(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);
        // create the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());

        // user is the owner of domain
        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // transfer the subdomain to rando
        domains::transfer_subdomain_owner(user, test_helper::subdomain_name(), test_helper::domain_name(), rando_addr, option::some(rando_addr));

        {
            // when rando owns the subdomain but not the domain, rando can't transfer subdomain ownership.
            domains::transfer_subdomain_owner(
                rando,
                test_helper::subdomain_name(),
                test_helper::domain_name(),
                user_addr,
                option::some(user_addr)
            );
        }
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 196632, location = aptos_names_v2::domains)]
    fun test_set_expiration_date_for_subdomain(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        // Register a subdomain!
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        // Set the auto-renewal flag as false
        domains::set_subdomain_renewal_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 0);

        domains::set_subdomain_expiration_as_domain_owner(user, test_helper::domain_name(), test_helper::subdomain_name(), timestamp::now_seconds() + 10);
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::some(test_helper::subdomain_name()), test_helper::domain_name());
        assert!(expiration_time_sec == timestamp::now_seconds() + 10, 1);
        let (domain_expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());

        // expect error when the expiration date pass the domain expiration date
        domains::set_subdomain_expiration_as_domain_owner(user, test_helper::domain_name(), test_helper::subdomain_name(), domain_expiration_time_sec + 5);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 65561, location = aptos_names_v2::domains)]
    fun test_register_domain_less_than_a_year(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), 100, test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 65561, location = aptos_names_v2::domains)]
    fun test_register_domain_duration_not_whole_years(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs()+5, test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_names_are_registerable_after_expiry_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());

        // Register a subdomain!
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), timestamp::now_seconds() + test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        // Set the subdomain auto-renewal policy to false
        domains::set_subdomain_renewal_policy(user, test_helper::domain_name(), test_helper::subdomain_name(), 0);

        // Set the time past the domain's expiration time
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::some(test_helper::subdomain_name()), test_helper::domain_name());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        // The domain should now be: expired, registered, AND registerable
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 81);
        assert!(domains::name_is_registerable(option::none(), test_helper::domain_name()), 82);

        // The subdomain now be: expired, registered, AND NOT registerable (because the domain is expired, too)
        assert!(domains::name_is_expired(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 90);
        assert!(domains::name_is_registered(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 91);
        assert!(!domains::name_is_registerable(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 92);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(rando, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 2, vector::empty<u8>(), option::none(), option::none());
        // The subdomain should now be registerable: it's both expired AND the domain is registered
        assert!(domains::name_is_expired(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 93);
        assert!(domains::name_is_registered(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 94);
        assert!(domains::name_is_registerable(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 95);

        // and likewise for the subdomain
        test_helper::register_name(rando, option::some(test_helper::subdomain_name()), test_helper::domain_name(), timestamp::now_seconds() + test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 2, vector::empty<u8>(), option::none(), option::none());

        // And again!
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::some(test_helper::subdomain_name()), test_helper::domain_name());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);


        // The domain should now be: expired, registered, AND registerable
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 81);
        assert!(domains::name_is_registerable(option::none(), test_helper::domain_name()), 82);

        // The subdomain now be: expired, registered, AND NOT registerable (because the domain is expired, too)
        assert!(domains::name_is_expired(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 90);
        assert!(domains::name_is_registered(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 91);
        assert!(!domains::name_is_registerable(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 92);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(rando, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 3, vector::empty<u8>(), option::none(), option::none());
        // The subdomain should now be registerable: it's both expired AND the domain is registered
        assert!(domains::name_is_expired(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 93);
        assert!(domains::name_is_registered(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 94);
        assert!(domains::name_is_registerable(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 95);

        // and likewise for the subdomain
        test_helper::register_name(rando, option::some(test_helper::subdomain_name()), test_helper::domain_name(), timestamp::now_seconds() + test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 3, vector::empty<u8>(), option::none(), option::none());
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 196611, location = aptos_names_v2::domains)]
    fun test_dont_allow_double_subdomain_registrations_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        // Try to register a subdomain twice (ensure we can't)
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327689, location = aptos_names_v2::domains)]
    fun test_dont_allow_rando_to_set_subdomain_address_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain and subdomain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        // Ensure we can't clear it as a rando. The expected target address doesn't matter as it won't get hit
        test_helper::set_target_address(rando, option::some(test_helper::subdomain_name()), test_helper::domain_name(), @aptos_names_v2);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327689, location = aptos_names_v2::domains)]
    fun test_dont_allow_rando_to_clear_subdomain_address_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain and subdomain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::set_target_address(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), signer::address_of(user));
        // Ensure we can't clear it as a rando. The expected target address doesn't matter as it won't get hit
        test_helper::set_target_address(rando, option::some(test_helper::subdomain_name()), test_helper::domain_name(), @aptos_names_v2);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_admin_can_force_set_subdomain_address_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());

        domains::force_set_subdomain_address(aptos_names_v2, test_helper::subdomain_name(), test_helper::domain_name(), rando_addr);
        let (_expiration_time_sec, target_address) = domains::get_name_record_v1_props_for_name(option::some(test_helper::subdomain_name()), test_helper::domain_name());
        test_utils::print_actual_expected(b"set_subdomain_address: ", target_address, option::some(rando_addr), false);
        assert!(target_address == option::some(rando_addr), 33);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::config)]
    fun test_rando_cant_force_set_subdomain_address_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain and subdomain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());

        // Rando is not allowed to do this
        domains::force_set_subdomain_address(rando, test_helper::subdomain_name(), test_helper::domain_name(), rando_addr);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun admin_can_force_seize_subdomain_name_e2e_test(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain and subdomain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        let is_owner = domains::is_owner_of_name(signer::address_of(user), option::some(test_helper::subdomain_name()), test_helper::domain_name());
        assert!(is_owner, 1);

        // Take the subdomain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(aptos_names_v2, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs());
        let is_owner = domains::is_owner_of_name(signer::address_of(aptos_names_v2), option::some(test_helper::subdomain_name()), test_helper::domain_name());
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::some(test_helper::subdomain_name()), test_helper::domain_name());
        assert!(time_helper::seconds_to_years(expiration_time_sec) == 1, time_helper::seconds_to_years(expiration_time_sec));
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun admin_can_force_create_subdomain_name_e2e_test(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // No subdomain is registered yet
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        assert!(!domains::name_is_registered(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 1);

        // Take the subdomain name
        domains::force_create_or_seize_name(aptos_names_v2, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs());
        let is_owner = domains::is_owner_of_name(signer::address_of(aptos_names_v2), option::some(test_helper::subdomain_name()), test_helper::domain_name());
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::some(test_helper::subdomain_name()), test_helper::domain_name());
        assert!(time_helper::seconds_to_years(expiration_time_sec) == 1, time_helper::seconds_to_years(expiration_time_sec));
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 131086, location = aptos_names_v2::domains)]
    fun test_admin_cant_force_create_subdomain_more_than_domain_time_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // No subdomain is registered yet- domain is registered for 1 year
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        assert!(!domains::name_is_registered(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 1);

        // Take the subdomain name for longer than domain: this should explode
        domains::force_create_or_seize_name(aptos_names_v2, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs() + 1);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::config)]
    fun test_rando_cant_force_seize_subdomain_name_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain and subdomain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        test_helper::register_name(user, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_subdomain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        let is_owner = domains::is_owner_of_name(signer::address_of(user), option::some(test_helper::subdomain_name()), test_helper::domain_name());
        assert!(is_owner, 1);

        // Attempt (and fail) to take the subdomain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(rando, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::two_hundred_year_secs());
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::config)]
    fun test_rando_cant_force_create_subdomain_name_e2e(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names, aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register a domain, and ensure no subdomain is registered yet
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>(), option::none(), option::none());
        assert!(!domains::name_is_registered(option::some(test_helper::subdomain_name()), test_helper::domain_name()), 1);

        // Attempt (and fail) to take the subdomain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(rando, option::some(test_helper::subdomain_name()), test_helper::domain_name(), test_helper::two_hundred_year_secs());
    }
}
