script {
    use std::option;
    use aptos_framework::timestamp;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    fun main(admin: &signer) {
        let names = vector [
            b"ans",
            b"aptos-foundation",
            b"aptos-labs",
            b"aptos-name-service",
            b"aptos-names-service",
            b"aptos-names",
            b"aptos",
            b"aptosfoundation",
            b"aptoslabs",
            b"aptosnames",
            b"aptosnameservice",
            b"aptosnamesservice",
            b"faucet",
            b"foundation",
            b"gas",
            b"move-lang",
            b"move-language",
            b"move",
            b"null",
            b"octa",
            b"petra-foundation",
            b"petra",
            b"petrafoundation",
            b"petrawallet",
            b"undefined",
            b"validators",
        ];
        let years_to_expire = 100;

        while (!std::vector::is_empty(&names)) {
            let name = std::string::utf8(std::vector::pop_back(&mut names));
            aptos_names_v2_1::v2_1_domains::force_set_name_expiration(
                admin,
                name,
                option::none(),
                timestamp::now_seconds() + SECONDS_PER_YEAR * years_to_expire,
            )
        }
    }
}
