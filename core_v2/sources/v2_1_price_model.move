module aptos_names_v2_1::v2_1_price_model {
    use aptos_names_v2_1::v2_1_config;
    use aptos_std::math64;
    use std::error;

    /// The domain length is too short- currently the minimum is 3 characters
    const EDOMAIN_TOO_SHORT: u64 = 1;
    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    #[view]
    /// There is a fixed cost per each tier of domain names, from 3 to >=6, and it also scales exponentially with number of years to register
    public fun price_for_domain(domain_length: u64, registration_secs: u64): u64 {
        assert!(domain_length >= 3, error::out_of_range(EDOMAIN_TOO_SHORT));
        let length_to_charge_for = math64::min(domain_length, 6);
        let registration_years = (registration_secs / SECONDS_PER_YEAR as u8);
        v2_1_config::domain_price_for_length(length_to_charge_for) * (registration_years as u64)
    }

    #[view]
    /// Subdomains have a fixed unit cost
    public fun price_for_subdomain(_registration_duration_secs: u64): u64 {
        v2_1_config::subdomain_price()
    }

    #[test(myself = @aptos_names_v2_1, framework = @0x1)]
    fun test_price_for_domain(myself: &signer, framework: &signer) {
        use aptos_names_v2_1::v2_1_config;
        use aptos_framework::aptos_coin::AptosCoin;
        use aptos_framework::coin;
        use aptos_framework::account;
        use std::signer;

        account::create_account_for_test(signer::address_of(myself));
        account::create_account_for_test(signer::address_of(framework));

        v2_1_config::initialize_aptoscoin_for(framework);
        coin::register<AptosCoin>(myself);
        v2_1_config::initialize_config(myself, @aptos_names_v2_1, @aptos_names_v2_1);

        v2_1_config::set_subdomain_price(myself, v2_1_config::octas() / 5);
        v2_1_config::set_domain_price_for_length(myself, (60 * v2_1_config::octas()), 3);
        v2_1_config::set_domain_price_for_length(myself, (30 * v2_1_config::octas()), 4);
        v2_1_config::set_domain_price_for_length(myself, (15 * v2_1_config::octas()), 5);
        v2_1_config::set_domain_price_for_length(myself, (5 * v2_1_config::octas()), 6);

        let price = price_for_domain(3, SECONDS_PER_YEAR) / v2_1_config::octas();
        assert!(price == 60, price);

        let price = price_for_domain(4, SECONDS_PER_YEAR) / v2_1_config::octas();
        assert!(price == 30, price);

        let price = price_for_domain(4, 3 * SECONDS_PER_YEAR) / v2_1_config::octas();
        assert!(price == 90, price);

        let price = price_for_domain(5, SECONDS_PER_YEAR) / v2_1_config::octas();
        assert!(price == 15, price);

        let price = price_for_domain(5, 8 * SECONDS_PER_YEAR) / v2_1_config::octas();
        assert!(price == 120, price);

        let price = price_for_domain(10, SECONDS_PER_YEAR) / v2_1_config::octas();
        assert!(price == 5, price);

        let price = price_for_domain(15, SECONDS_PER_YEAR) / v2_1_config::octas();
        assert!(price == 5, price);

        let price =
            price_for_domain(15, 10 * SECONDS_PER_YEAR) / v2_1_config::octas();
        assert!(price == 50, price);
    }

    #[test_only]
    struct YearPricePair has copy, drop {
        years: u8,
        expected_price: u64,
    }
}
