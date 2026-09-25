//// The log edge: logger:warning/1 for the policy's refusal channel.

import mcl_bookclub_gleam/internal/payload.{type Payload}

@external(erlang, "mcl_bookclub_gleam_ffi", "logger_warning")
pub fn warning(term: Payload) -> Nil
