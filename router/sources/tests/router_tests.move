#[test_only]
module router::router_tests {
    use router::router;
    use router::router_test_helper;
    use std::option;
    use std::signer::address_of;
    use std::vector;

    const MAX_MODE: u8 = 1;

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_initialization(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user, &aptos, rando, &foundation);
        assert!(router::get_admin_addr() == @router, 0);
        assert!(option::is_none(&router::get_pending_admin_addr()), 1);
        assert!(router::get_mode() == 0, 2)
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_accept_admin(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = address_of(user);

        router::set_pending_admin(router, user_addr);
        assert!(router::get_admin_addr() == @router, 0);
        assert!(router::get_pending_admin_addr() == option::some(user_addr), 1);

        router::accept_pending_admin(user);
        assert!(router::get_admin_addr() == user_addr, 0);
        assert!(option::is_none(&router::get_pending_admin_addr()), 1);
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327682, location = router)]
    fun test_accept_admin_only_pending_admin(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user_addr = address_of(user);

        router::set_pending_admin(router, user_addr);
        assert!(router::get_admin_addr() == @router, 0);
        assert!(router::get_pending_admin_addr() == option::some(user_addr), 1);

        router::accept_pending_admin(router);
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327680, location = router)]
    fun test_set_pending_admin_only_admin(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        router::set_pending_admin(user, address_of(user));
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    fun test_set_mode(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user, &aptos, rando, &foundation);

        let i = 0;
        while (i <= MAX_MODE) {
            router::set_mode(router, i);
            assert!(router::get_mode() == i, 0);
            i = i + 1
        }
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 327680, location = router)]
    fun test_set_mode_admin_only(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        let users = router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        router::set_mode(user, 0);
    }

    #[test(
        router = @router,
        aptos_names = @aptos_names,
        aptos_names_v2_1 = @aptos_names_v2_1,
        user = @0x077,
        aptos = @0x1,
        rando = @0x266f,
        foundation = @0xf01d
    )]
    #[expected_failure(abort_code = 65539, location = router)]
    fun test_set_mode_invalid_mode(
        router: &signer,
        aptos_names: &signer,
        aptos_names_v2_1: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        router::init_module_for_test(router);
        router_test_helper::e2e_test_setup(aptos_names, aptos_names_v2_1, user, &aptos, rando, &foundation);

        router::set_mode(router, MAX_MODE + 1);
    }
}
