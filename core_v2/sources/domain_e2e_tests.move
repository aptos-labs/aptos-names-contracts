#[test_only]
module aptos_names_v2::domain_e2e_tests {
    use std::fixed_point32::round;
    use aptos_framework::chain_id;
    use aptos_framework::timestamp;
    use aptos_framework::object;
    use aptos_names_v2::config;
    use aptos_names_v2::domains;
    use aptos_names_v2::time_helper;
    use aptos_names_v2::test_helper;
    use aptos_names_v2::test_utils;
    use std::option;
    use std::signer;
    use std::string;
    use std::vector;

    const MAX_REMAINING_TIME_FOR_RENEWAL_SEC: u64 = 15552000;

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun happy_path_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );

        // Set an address and verify it
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), user_addr);

        // Ensure the owner can clear the address
        test_helper::clear_target_address(user, option::none(), test_helper::domain_name());

        // And also can clear if the user is the registered address, but not owner
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));
        test_helper::clear_target_address(rando, option::none(), test_helper::domain_name());

        // Set it back for following tests
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), user_addr);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun e2e_test_with_valid_signature(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        /*
          Signature generated with scripts/generateKeys.ts
            yarn ts-node --compilerOptions '{"target": "es6", "module": "commonjs", "esModuleInterop": true}'  ./scripts/generateKeys.ts

          let proof_struct = RegisterDomainProofChallenge {
              account_address: AccountAddress::from_hex_literal(aptos_names_v2).unwrap(),
              module_name: String::from("verify"),
              struct_name: String::from("RegisterDomainProofChallenge"),
              sequence_number: 0,
              register_address: *register_account.address(),
              domain_name: String::from("test"),
              chain_id: 4,
          };
      */

        let signature: vector<u8> = x"c381226467371d5a5ca2408333b8f8c68d4c6f81d1f020c11402620ec47c1b74114c60a02bcb4798ee84df6e85be2c79e6f691962beecef1ab73b93a9dcaea03";
        e2e_test_with_signature(router_signer, aptos_names_v2, user, aptos, rando, foundation, signature);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 65537, location = aptos_names_v2::verify)]
    fun e2e_test_with_invalid_signature(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let signature: vector<u8> = x"2b0340b4529e3f90f0b1af7364241c51172c1133f0c077b7836962c3f104115832ccec0b74382533c33d9bd14a6e68021e5c23439242ddd43047e7929084ac01";
        e2e_test_with_signature(router_signer, aptos_names_v2, user, aptos, rando, foundation, signature);
    }

    #[test_only]
    fun e2e_test_with_signature(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer,
        signature: vector<u8>
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let user_addr = signer::address_of(user);

        chain_id::initialize_for_test(&aptos, 4);
        config::set_unrestricted_mint_enabled(aptos_names_v2, false);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            signature
        );

        // Set an address and verify it
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), user_addr);

        // Ensure the owner can clear the address
        test_helper::clear_target_address(user, option::none(), test_helper::domain_name());

        // And also can clear if the user is the registered address, but not owner
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));
        test_helper::clear_target_address(rando, option::none(), test_helper::domain_name());

        // Set it back for following tests
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), user_addr);
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
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );

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

        let (new_expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );
        // Ensure the domain is still expired after the new expiration time
        timestamp::update_global_time_for_test_secs(new_expiration_time_sec + 5);
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 5);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327696, location = aptos_names_v2::domains)]
    fun test_register_domain_abort_with_disabled_unrestricted_mint(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        chain_id::initialize_for_test(&aptos, 4);
        config::set_unrestricted_mint_enabled(aptos_names_v2, false);

        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
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
    fun names_are_registerable_after_expiry_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );

        // Set the time past the domain's expiration time
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        // It should now be: expired, registered, AND registerable
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 81);
        assert!(domains::name_is_registerable(option::none(), test_helper::domain_name()), 82);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(
            router_signer,
            rando,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            2,
            vector::empty<u8>()
        );

        // Reverse lookup for |user| should be none.
        assert!(option::is_none(&domains::get_reverse_lookup(signer::address_of(user))), 85);

        // And again!
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        // It should now be: expired, registered, AND registerable
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 81);
        assert!(domains::name_is_registerable(option::none(), test_helper::domain_name()), 82);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(
            router_signer,
            rando,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            3,
            vector::empty<u8>()
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
    #[expected_failure(abort_code = 196611, location = aptos_names_v2::domains)]
    fun dont_allow_double_domain_registrations_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        // Ensure we can't register it again
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
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
    #[expected_failure(abort_code = 327689, location = aptos_names_v2::domains)]
    fun dont_allow_rando_to_set_domain_address_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        // Ensure we can't set it as a rando. The expected target address doesn't matter as it won't get hit
        test_helper::set_target_address(rando, option::none(), test_helper::domain_name(), @aptos_names_v2);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327682, location = aptos_names_v2::domains)]
    fun dont_allow_rando_to_clear_domain_address_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain, and set its address
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), signer::address_of(user));

        // Ensure we can't clear it as a rando
        test_helper::clear_target_address(rando, option::none(), test_helper::domain_name());
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun owner_can_clear_domain_address_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain, and set its address
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        test_helper::set_target_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));

        // Ensure we can clear as owner
        test_helper::clear_target_address(user, option::none(), test_helper::domain_name());
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
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );

        domains::force_set_domain_address(aptos_names_v2, test_helper::domain_name(), rando_addr);
        let (_expiration_time_sec, target_address) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );
        test_utils::print_actual_expected(b"set_domain_address: ", target_address, option::some(rando_addr), false);
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
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::config)]
    fun rando_cant_force_set_target_address_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );

        // Rando is not allowed to do this
        domains::force_set_domain_address(rando, test_helper::domain_name(), rando_addr);
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
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        let is_owner = domains::is_owner_of_name(signer::address_of(user), option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );
        assert!(
            time_helper::seconds_to_years(expiration_time_sec) == 1,
            time_helper::seconds_to_years(expiration_time_sec)
        );

        // renew the domain by admin outside of renewal window
        domains::force_set_name_expiration(
            aptos_names_v2,
            test_helper::domain_name(),
            option::none(),
            timestamp::now_seconds() + 2 * test_helper::one_year_secs()
        );

        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );
        assert!(
            time_helper::seconds_to_years(expiration_time_sec) == 2,
            time_helper::seconds_to_years(expiration_time_sec)
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
    fun admin_can_force_seize_domain_name_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        let is_owner = domains::is_owner_of_name(signer::address_of(user), option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(
            aptos_names_v2,
            option::none(),
            test_helper::domain_name(),
            test_helper::two_hundred_year_secs()
        );
        let is_owner = domains::is_owner_of_name(
            signer::address_of(aptos_names_v2),
            option::none(),
            test_helper::domain_name()
        );
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );
        assert!(
            time_helper::seconds_to_years(expiration_time_sec) == 200,
            time_helper::seconds_to_years(expiration_time_sec)
        );

        // Ensure that the user's primary name is no longer set.
        assert!(option::is_none(&domains::get_reverse_lookup(user_addr)), 1);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun admin_force_seize_domain_name_doesnt_clear_unrelated_primary_name_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain. This will be the user's reverse lookup
        {
            test_helper::register_name(
                router_signer,
                user,
                option::none(),
                test_helper::domain_name(),
                test_helper::one_year_secs(),
                test_helper::fq_domain_name(),
                1,
                vector::empty<u8>()
            );
            let is_owner = domains::is_owner_of_name(
                signer::address_of(user),
                option::none(),
                test_helper::domain_name()
            );
            assert!(is_owner, 1);
        };

        // Register another domain. This will **not** be the user's reverse lookup
        let domain_name = string::utf8(b"sets");
        let fq_domain_name = string::utf8(b"sets.apt");
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            domain_name,
            test_helper::one_year_secs(),
            fq_domain_name,
            1,
            vector::empty<u8>()
        );
        let is_owner = domains::is_owner_of_name(signer::address_of(user), option::none(), domain_name);
        assert!(is_owner, 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(
            aptos_names_v2,
            option::none(),
            domain_name,
            test_helper::two_hundred_year_secs()
        );
        let is_owner = domains::is_owner_of_name(signer::address_of(aptos_names_v2), option::none(), domain_name);
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), domain_name);
        assert!(
            time_helper::seconds_to_years(expiration_time_sec) == 200,
            time_helper::seconds_to_years(expiration_time_sec)
        );

        // Ensure that the user's primary name is still set.
        assert!(option::is_some(&domains::get_reverse_lookup(user_addr)), 1);
    }

    #[test(
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun admin_can_force_create_domain_name_e2e_test(
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let _ = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);

        // No domain is registered yet
        assert!(!domains::name_is_registered(option::none(), test_helper::domain_name()), 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(
            aptos_names_v2,
            option::none(),
            test_helper::domain_name(),
            test_helper::two_hundred_year_secs()
        );
        let is_owner = domains::is_owner_of_name(
            signer::address_of(aptos_names_v2),
            option::none(),
            test_helper::domain_name()
        );
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );
        assert!(
            time_helper::seconds_to_years(expiration_time_sec) == 200,
            time_helper::seconds_to_years(expiration_time_sec)
        );

        // Try to nuke the domain
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 3);
        domains::force_clear_registration(aptos_names_v2, option::none(), test_helper::domain_name());
        assert!(!domains::name_is_registered(option::none(), test_helper::domain_name()), 4);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::config)]
    fun rando_cant_force_seize_domain_name_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        let is_owner = domains::is_owner_of_name(signer::address_of(user), option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(
            rando,
            option::none(),
            test_helper::domain_name(),
            test_helper::two_hundred_year_secs()
        );
    }

    #[test(
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::config)]
    fun rando_cant_force_create_domain_name_e2e_test(
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let rando = vector::borrow(&users, 1);

        // No domain is registered yet
        assert!(!domains::name_is_registered(option::none(), test_helper::domain_name()), 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(
            rando,
            option::none(),
            test_helper::domain_name(),
            test_helper::two_hundred_year_secs()
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
    fun clear_name_happy_path_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );

        // Clear my reverse lookup.
        domains::clear_reverse_lookup(user);

        assert!(option::is_none(&domains::get_reverse_lookup(user_addr)), 1);
    }

    #[test(
        router_signer = @router_signer,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun set_primary_name_after_transfer_clears_old_primary_name_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Transfer the domain to rando
        let record_obj = domains::get_record_obj(test_helper::domain_name(), option::none());
        object::transfer(user, record_obj, signer::address_of(rando));

        // Verify primary name for |user| hasn't changed
        assert!(option::is_some(&domains::get_reverse_lookup(user_addr)), 1);
        assert!(
            *option::borrow(&domains::name_resolved_address(option::none(), test_helper::domain_name())) == user_addr,
            1
        );

        // |rando| sets his primary name
        let domain_name_str = string::utf8(b"test");
        domains::set_reverse_lookup(rando, option::none(), domain_name_str);

        // |user|'s primary name should be none.
        assert!(option::is_none(&domains::get_reverse_lookup(user_addr)), 1);
        assert!(
            *option::borrow(&domains::name_resolved_address(option::none(), test_helper::domain_name())) == rando_addr,
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
    fun set_target_address_after_transfer_clears_old_primary_name_e2e_test(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Transfer the domain to rando
        let record_obj = domains::get_record_obj(test_helper::domain_name(), option::none());
        object::transfer(user, record_obj, signer::address_of(rando));

        // Verify primary name for |user| hasn't changed
        assert!(option::is_some(&domains::get_reverse_lookup(user_addr)), 1);
        assert!(
            *option::borrow(&domains::name_resolved_address(option::none(), test_helper::domain_name())) == user_addr,
            1
        );

        // |rando| sets target address
        let domain_name_str = string::utf8(b"test");
        domains::set_domain_address(rando, domain_name_str, rando_addr);

        // |user|'s primary name should be none.
        assert!(option::is_none(&domains::get_reverse_lookup(user_addr)), 1);
        assert!(
            *option::borrow(&domains::name_resolved_address(option::none(), test_helper::domain_name())) == rando_addr,
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
    fun owner_of_expired_name_is_not_owner(
        router_signer: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Set the time past the domain's expiration time
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(
            option::none(),
            test_helper::domain_name()
        );
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(!is_owner, 1);
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
        foundation: signer
    ) {
        let users = test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(
            router_signer,
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );

        // user is owner
        {
            let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
            assert!(is_owner, 1);
        };

        let token_addr = domains::token_addr(test_helper::domain_name(), option::none());
        object::transfer_raw(user, token_addr, rando_addr);

        // rando is owner
        {
            let is_owner = domains::is_owner_of_name(rando_addr, option::none(), test_helper::domain_name());
            assert!(is_owner, 1);
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
        foundation: signer
    ) {
        test_helper::e2e_test_setup(aptos_names_v2, user, &aptos, rando, &foundation);

        // Non-registered domain should be expired
        {
            let is_expired = domains::name_is_expired(option::none(), test_helper::domain_name());
            assert!(is_expired, 1);
        };

        // Non-registered subdomain should be expired
        {
            let is_expired = domains::name_is_expired(
                option::some(test_helper::subdomain_name()),
                test_helper::domain_name()
            );
            assert!(is_expired, 1);
        };
    }
}
