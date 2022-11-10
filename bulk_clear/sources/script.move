script {
    use std::option;
    use std::string;

    fun main(admin: &signer) {
        let names = vector [
            b"520",
            b"eth",
            b"ape",
            b"314",
            b"360",
            b"crypto",
            b"bacon",
            b"dao",
            b"xyz",
            b"wallet",
            b"defi",
            b"art",
            b"coffee",
            b"neil",
            b"cryptography",
            b"god",
            b"420",
            b"hiking",
            b"sports",
            b"233",
            b"111",
            b"000",
            b"hahaha",
            b"666",
            b"911",
            b"abc",
            b"get",
        ];

        while (!std::vector::is_empty(&names)) {
            let name = std::string::utf8(std::vector::pop_back(&mut names));
            aptos_names::domains::force_clear_registration(admin, option::none<string::String>(), name);
        }
    }
}
