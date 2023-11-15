script {
    use std::option;
    use aptos_framework::timestamp;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    fun main(admin: &signer) {
        let names = vector [
            b"ave",
            b"lens",
            b"microsoft",
        ];
        let years_to_expire = 100;

        while (!std::vector::is_empty(&names)) {
            let name = std::string::utf8(std::vector::pop_back(&mut names));
            aptos_names_v2_1::v2_1_domains::force_create_or_seize_name(
                admin,
                name,
                option::none(),
                years_to_expire * SECONDS_PER_YEAR,
            );

        }
    }
}
