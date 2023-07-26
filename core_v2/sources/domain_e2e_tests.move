#[test_only]
module aptos_names_v2::domain_e2e_tests {
    use aptos_framework::account;
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

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun happy_path_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        // Set an address and verify it
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), user_addr);

        // Ensure the owner can clear the address
        test_helper::clear_name_address(user, option::none(), test_helper::domain_name());

        // And also can clear if the user is the registered address, but not owner
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));
        test_helper::clear_name_address(rando, option::none(), test_helper::domain_name());

        // Set it back for following tests
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), user_addr);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun e2e_test_with_valid_signature(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
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
        e2e_test_with_signature(myself, user, aptos, rando, foundation, signature);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 65537, location = aptos_names_v2::verify)]
    fun e2e_test_with_invalid_signature(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let signature: vector<u8> = x"2b0340b4529e3f90f0b1af7364241c51172c1133f0c077b7836962c3f104115832ccec0b74382533c33d9bd14a6e68021e5c23439242ddd43047e7929084ac01";
        e2e_test_with_signature(myself, user, aptos, rando, foundation, signature);
    }

    #[test_only]
    fun e2e_test_with_signature(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer, signature: vector<u8>) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let user_addr = signer::address_of(user);

        chain_id::initialize_for_test(&aptos, 4);
        config::set_unrestricted_mint_enabled(myself, false);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, signature);

        // Set an address and verify it
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), user_addr);

        // Ensure the owner can clear the address
        test_helper::clear_name_address(user, option::none(), test_helper::domain_name());

        // And also can clear if the user is the registered address, but not owner
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));
        test_helper::clear_name_address(rando, option::none(), test_helper::domain_name());

        // Set it back for following tests
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), user_addr);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327696, location = aptos_names_v2::domains)]
    fun test_register_domain_abort_with_disabled_unrestricted_mint(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        chain_id::initialize_for_test(&aptos, 4);
        config::set_unrestricted_mint_enabled(myself, false);

        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun names_are_registerable_after_expiry_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        // Set the time past the domain's expiration time
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        // It should now be: expired, registered, AND registerable
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 81);
        assert!(domains::name_is_registerable(option::none(), test_helper::domain_name()), 82);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(rando, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 2, vector::empty<u8>());

        // Reverse lookup for |user| should be none.
        assert!(option::is_none(&domains::get_reverse_lookup(signer::address_of(user))), 85);

        // And again!
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        // It should now be: expired, registered, AND registerable
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 81);
        assert!(domains::name_is_registerable(option::none(), test_helper::domain_name()), 82);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(rando, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 3, vector::empty<u8>());
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 196611, location = aptos_names_v2::domains)]
    fun dont_allow_double_domain_registrations_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        // Ensure we can't register it again
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327689, location = aptos_names_v2::domains)]
    fun dont_allow_rando_to_set_domain_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        // Ensure we can't set it as a rando. The expected target address doesn't matter as it won't get hit
        test_helper::set_name_address(rando, option::none(), test_helper::domain_name(), @aptos_names_v2);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327682, location = aptos_names_v2::domains)]
    fun dont_allow_rando_to_clear_domain_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain, and set its address
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), signer::address_of(user));

        // Ensure we can't clear it as a rando
        test_helper::clear_name_address(rando, option::none(), test_helper::domain_name());
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun owner_can_clear_domain_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain, and set its address
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));

        // Ensure we can clear as owner
        test_helper::clear_name_address(user, option::none(), test_helper::domain_name());
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun admin_can_force_set_name_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        domains::force_set_domain_address(myself, test_helper::domain_name(), rando_addr);
        let (_expiration_time_sec, target_address) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        test_utils::print_actual_expected(b"set_domain_address: ", target_address, option::some(rando_addr), false);
        assert!(target_address == option::some(rando_addr), 33);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::config)]
    fun rando_cant_force_set_name_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        // Rando is not allowed to do this
        domains::force_set_domain_address(rando, test_helper::domain_name(), rando_addr);
    }


    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun admin_can_force_seize_domain_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        let is_owner = domains::is_owner_of_name(signer::address_of(user), option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(myself, option::none(), test_helper::domain_name(), test_helper::two_hundred_year_secs());
        let is_owner = domains::is_owner_of_name(signer::address_of(myself), option::none(), test_helper::domain_name());
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        assert!(time_helper::seconds_to_years(expiration_time_sec) == 200, time_helper::seconds_to_years(expiration_time_sec));

        // Ensure that the user's primary name is no longer set.
        assert!(option::is_none(&domains::get_reverse_lookup(user_addr)), 1);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun admin_force_seize_domain_name_doesnt_clear_unrelated_primary_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain. This will be the user's reverse lookup
        {
            test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
            let is_owner = domains::is_owner_of_name(signer::address_of(user), option::none(), test_helper::domain_name());
            assert!(is_owner, 1);
        };

        // Register another domain. This will **not** be the user's reverse lookup
        let domain_name = string::utf8(b"sets");
        let fq_domain_name = string::utf8(b"sets.apt");
        test_helper::register_name(user, option::none(), domain_name, test_helper::one_year_secs(), fq_domain_name, 1, vector::empty<u8>());
        let is_owner = domains::is_owner_of_name(signer::address_of(user), option::none(), domain_name);
        assert!(is_owner, 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(myself, option::none(), domain_name, test_helper::two_hundred_year_secs());
        let is_owner = domains::is_owner_of_name(signer::address_of(myself), option::none(), domain_name);
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), domain_name);
        assert!(time_helper::seconds_to_years(expiration_time_sec) == 200, time_helper::seconds_to_years(expiration_time_sec));

        // Ensure that the user's primary name is still set.
        assert!(option::is_some(&domains::get_reverse_lookup(user_addr)), 1);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun admin_can_force_create_domain_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let _ = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);

        // No domain is registered yet
        assert!(!domains::name_is_registered(option::none(), test_helper::domain_name()), 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(myself, option::none(), test_helper::domain_name(), test_helper::two_hundred_year_secs());
        let is_owner = domains::is_owner_of_name(signer::address_of(myself), option::none(), test_helper::domain_name());
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        assert!(time_helper::seconds_to_years(expiration_time_sec) == 200, time_helper::seconds_to_years(expiration_time_sec));

        // Try to nuke the domain
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 3);
        domains::force_clear_registration(myself, option::none(), test_helper::domain_name());
        assert!(!domains::name_is_registered(option::none(), test_helper::domain_name()), 4);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::config)]
    fun rando_cant_force_seize_domain_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        let is_owner = domains::is_owner_of_name(signer::address_of(user), option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(rando, option::none(), test_helper::domain_name(), test_helper::two_hundred_year_secs());
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::config)]
    fun rando_cant_force_create_domain_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let rando = vector::borrow(&users, 1);

        // No domain is registered yet
        assert!(!domains::name_is_registered(option::none(), test_helper::domain_name()), 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(rando, option::none(), test_helper::domain_name(), test_helper::two_hundred_year_secs());
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun clear_name_happy_path_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        // Clear my reverse lookup.
        domains::clear_reverse_lookup(user);

        assert!(option::is_none(&domains::get_reverse_lookup(user_addr)), 1);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun set_primary_name_after_transfer_clears_old_primary_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Transfer the domain to rando
        let record_obj = domains::get_record_obj(test_helper::domain_name(), option::none());
        object::transfer(user, record_obj, signer::address_of(rando));

        // Verify primary name for |user| hasn't changed
        assert!(option::is_some(&domains::get_reverse_lookup(user_addr)), 1);
        assert!(*option::borrow(&domains::name_resolved_address(option::none(), test_helper::domain_name())) == user_addr, 1);

        // |rando| sets his primary name
        let domain_name_str = string::utf8(b"test");
        domains::set_reverse_lookup(rando, option::none(), domain_name_str);

        // |user|'s primary name should be none.
        assert!(option::is_none(&domains::get_reverse_lookup(user_addr)), 1);
        assert!(*option::borrow(&domains::name_resolved_address(option::none(), test_helper::domain_name())) == rando_addr, 1);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun set_target_address_after_transfer_clears_old_primary_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);
        let rando = vector::borrow(&users, 1);
        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Transfer the domain to rando
        let record_obj = domains::get_record_obj(test_helper::domain_name(), option::none());
        object::transfer(user, record_obj, signer::address_of(rando));

        // Verify primary name for |user| hasn't changed
        assert!(option::is_some(&domains::get_reverse_lookup(user_addr)), 1);
        assert!(*option::borrow(&domains::name_resolved_address(option::none(), test_helper::domain_name())) == user_addr, 1);

        // |rando| sets target address
        let domain_name_str = string::utf8(b"test");
        domains::set_domain_address(rando, domain_name_str, rando_addr);

        // |user|'s primary name should be none.
        assert!(option::is_none(&domains::get_reverse_lookup(user_addr)), 1);
        assert!(*option::borrow(&domains::name_resolved_address(option::none(), test_helper::domain_name())) == rando_addr, 1);
    }

    #[test(myself = @aptos_names_v2, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun owner_of_expired_name_is_not_owner(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Set the time past the domain's expiration time
        let (expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        let is_owner = domains::is_owner_of_name(user_addr, option::none(), test_helper::domain_name());
        assert!(!is_owner, 1);
    }

    #[test(
        aptos_names = @aptos_names,
        aptos_names_v2 = @aptos_names_v2,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_migration(
        aptos_names: &signer,
        aptos_names_v2: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        // Setup test env for v1
        let users = aptos_names::test_helper::e2e_test_setup(aptos_names, user, &aptos, rando, &foundation);

        // Setup test env for v2
        account::create_account_for_test(@aptos_names_v2);
        aptos_names_v2::domains::init_module_for_test(aptos_names_v2);
        aptos_names_v2::config::set_fund_destination_address_test_only(signer::address_of(&foundation));

        let user = vector::borrow(&users, 0);
        let user_addr = signer::address_of(user);

        // Register the domain in v1
        aptos_names::test_helper::register_name(
            user,
            option::none(),
            test_helper::domain_name(),
            test_helper::one_year_secs(),
            test_helper::fq_domain_name(),
            1,
            vector::empty<u8>()
        );
        aptos_names::test_helper::set_name_address(
            user,
            option::none(),
            test_helper::domain_name(),
            user_addr,
        );

        // Migrate the domain from v1
        aptos_names_v2::domains::migrate_domain_from_v1(
            user,
            test_helper::domain_name(),
        );

        // The v1 name belongs to the burn signer and the target address is clear
        {
            assert!(
                aptos_names::domains::name_is_registerable(option::none(), test_helper::domain_name()) == false,
                1,
            );
            let (is_owner, _) = aptos_names::domains::is_owner_of_name(
                aptos_names_v2::domains::get_burn_signer_address(),
                option::none(),
                test_helper::domain_name(),
            );
            assert!(is_owner, 2);
            let target_addr = aptos_names::domains::name_resolved_address(
                option::none(),
                test_helper::domain_name(),
            );
            assert!(option::is_none(&target_addr), 3);
        };

        // The v2 name belongs to `user`, the target address is the user_addr, and exipire in 1 + 1 years
        {
            assert!(
                aptos_names_v2::domains::name_is_registerable(option::none(), test_helper::domain_name()) == false,
                1,
            );
            let is_owner = aptos_names_v2::domains::is_owner_of_name(
                user_addr,
                option::none(),
                test_helper::domain_name(),
            );
            assert!(is_owner, 2);
            let (expiration_time_sec, target_addr) = aptos_names_v2::domains::get_name_record_v1_props_for_name(
                option::none(),
                test_helper::domain_name(),
            );

            assert!(time_helper::seconds_to_years(expiration_time_sec - timestamp::now_seconds()) == 2, 3);
            assert!(option::is_some(&target_addr), 4);
            assert!(*option::borrow(&target_addr) == user_addr, 5);
        }
    }
}
