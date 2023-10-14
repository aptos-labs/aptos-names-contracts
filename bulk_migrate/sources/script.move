script {
    use std::string::utf8;

    fun main(user: &signer) {
        let names = vector [
            utf8(b"ans"),
            utf8(b"aptos-foundation"),
            utf8(b"aptos-labs"),
            utf8(b"aptos-name-service"),
            utf8(b"aptos-names-service"),
            utf8(b"aptos-names"),
            utf8(b"aptos"),
            utf8(b"aptosfoundation"),
            utf8(b"aptoslabs"),
            utf8(b"aptosnames"),
            utf8(b"aptosnameservice"),
            utf8(b"aptosnamesservice"),
            utf8(b"faucet"),
            utf8(b"foundation"),
            utf8(b"gas"),
            utf8(b"move-lang"),
            utf8(b"move-language"),
            utf8(b"move"),
            utf8(b"null"),
            utf8(b"octa"),
            utf8(b"petra-foundation"),
            utf8(b"petra"),
            utf8(b"petrafoundation"),
            utf8(b"petrawallet"),
            utf8(b"undefined"),
            utf8(b"validators"),
        ];

        bulk::bulk::bulk_migrate_domain(user, names);
    }
}
