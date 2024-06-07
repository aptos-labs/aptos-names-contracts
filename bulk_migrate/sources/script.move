script {
    use std::string::utf8;

    fun main(user: &signer) {
        let names = vector[utf8(b"name01"), utf8(b"name02"),];

        bulk::bulk::bulk_migrate_domain(user, names);
    }
}
