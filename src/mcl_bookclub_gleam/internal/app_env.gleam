//// The application environment edge: application:get_env/3, for the
//// admin listener's port and ip (set by the release's sys.config).

import gleam/dynamic

@external(erlang, "application", "get_env")
pub fn get_env(
  app: dynamic.Dynamic,
  key: dynamic.Dynamic,
  default: dynamic.Dynamic,
) -> dynamic.Dynamic

/// inet:parse_address/1 -- the admin ip, a charlist in, {ok, Address} out.
@external(erlang, "inet", "parse_address")
pub fn parse_address(ip: dynamic.Dynamic) -> dynamic.Dynamic
