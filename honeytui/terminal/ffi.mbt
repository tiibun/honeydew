///|
/// Raw C FFI bindings. Not intended for direct use outside this package.

///|
extern "c" fn hd_enter_raw_mode() -> Int = "hd_enter_raw_mode"

///|
extern "c" fn hd_exit_raw_mode() -> Int = "hd_exit_raw_mode"

///|
/// Returns (cols << 16) | rows, or -1 on error.
extern "c" fn hd_get_winsize() -> Int = "hd_get_winsize"

///|
#borrow(buf)
extern "c" fn hd_write(buf : Bytes, len : Int) -> Unit = "hd_write"

///|
/// Install a SIGWINCH handler that writes one byte to `write_fd` on resize.
/// On Windows this is a no-op. Returns 0 on success, -1 on failure.
extern "c" fn hd_setup_sigwinch(write_fd : Int) -> Int = "hd_setup_sigwinch"

///|
/// Remove the SIGWINCH handler and close the internal write fd.
extern "c" fn hd_cleanup_sigwinch() -> Int = "hd_cleanup_sigwinch"
