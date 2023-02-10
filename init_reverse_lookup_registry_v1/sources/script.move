script {
    use aptos_names::domains;

    fun main(admin: &signer) {
        domains::init_reverse_lookup_registry_v1(admin);
    }
}
