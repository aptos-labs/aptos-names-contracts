#[test_only]
<<<<<<<< HEAD:core_v2/sources/v2_1_test_utils.move
module aptos_names_v2::v2_1_test_utils {
========
module aptos_names_v2_1::v2_test_utils {
>>>>>>>> j/rename-package:core_v2/sources/tests/v2_test_utils.move

    use std::string::{Self, String};
    use aptos_std::debug;

    struct PrintDebug<T: drop> has copy, drop {
        label: String,
        value: T,
    }

    struct ActualExpectedDebug<T: drop> has copy, drop {
        actual: T,
        expected: T,
    }

    public fun print_actual_expected<T: drop>(label: vector<u8>, actual: T, expected: T, always: bool) {
        if (!always && &actual == &expected) {
            return
        };
        let expected_actual = ActualExpectedDebug {
            actual,
            expected,
        };
        print_trace(label, expected_actual);
    }

    public fun print<T: drop>(label: vector<u8>, value: T) {
        let print_debug = PrintDebug {
            label: string::utf8(label),
            value,
        };
        debug::print(&print_debug);
        let PrintDebug { label: _, value: _ } = print_debug;
    }

    public fun print_trace<T: drop>(label: vector<u8>, value: T) {
        debug::print_stack_trace();
        print(label, value);
    }
}
