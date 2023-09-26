#[test_only]
module router::registerable_tests {
    use router::router;
    use router::router_test_helper;
    use std::option;
    use std::string::utf8;
    use std::vector;
    use aptos_framework::object;
    use aptos_token_objects::token;

    const MAX_MODE: u8 = 1;
    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    fun get_record_obj(

    ) {
        object::address_to_object(token::create_token_address(
            &get_app_signer_addr(),
            &get_collection_name(is_subdomain(subdomain_name)),
            &v2_1_token_helper::get_fully_qualified_domain_name(subdomain_name, domain_name),
        )(domain_name, subdomain_name))
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user1 = @0x077,
        user2 = @0x266f,
        aptos = @0x1,
        foundation = @0xf01d
    )]
    fun test_registerable(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user1: signer,
        user2: signer,
        aptos: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user1, &aptos, user2, &foundation);
        let user1 = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);
        let domain_name1 = utf8(b"test1");
        let domain_name2 = utf8(b"test2");

        // Name is registerable
        assert!(router::can_register(domain_name1, option::none()), 1);

        // Register with v1
        router::register_domain(user1, domain_name1, SECONDS_PER_YEAR, option::none(), option::none());
        router::register_domain(user1, domain_name2, SECONDS_PER_YEAR, option::none(), option::none());

        object::transfer(user1, )

        // Name becomes unregisterable
        assert!(!router::can_register(domain_name1, option::none()), 2);

        // Bump mode
        router::set_mode(router, 1);

        // Name still not registerable
        assert!(!router::can_register(domain_name1, option::none()), 3);

        // Make v1 read only except for admin
        aptos_names::config::set_is_enabled(aptos_names, false);

        // Name still not registerable
        assert!(!router::can_register(domain_name1, option::none()), 4);

        // Migrate to v2
        router::migrate_name(user1, domain_name1, option::none());

        // Name still not registerable
        assert!(!router::can_register(domain_name1, option::none()), 5);
    }
}
