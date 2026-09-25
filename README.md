# mcl-bookclub-gleam

The Bookclub-on-Mesh in **Gleam**: the **third club on the mesh**, a drop-in
twin of [`mcl-bookclub`](https://github.com/macula-services/mcl-bookclub)
(Erlang) and
[`mcl-bookclub-phoenix`](https://github.com/macula-services/mcl-bookclub-phoenix)
(Elixir). Same org (`mcl-bookclub`), same fact topics, same procedure names —
distinguishable on the wire only by node identity. This is the workspace's
**first Gleam edge service**.

A book club kept as a reckon-db event store, with projections into sqlite, on
the macula mesh through `mcl_om` (0.29 floor — the serving-station spread the
many-club model needs; mcl-om#5).

## The department layout

One Gleam OTP app, four department folders (the Erlang twin's division
boundary is enforced by tests, not by the build; Gleam has no umbrella, so
the single app follows that precedent):

```
src/mcl_bookclub_gleam/
  *.gleam                    the facade: the mcl_om service contract, the
                             get_bookclub_by_id handler, the three fact
                             emitters, the cowboy LAN admin, the supervisors
  host_bookclub/             CMD: nine desks, four aggregates, the party policy
  project_bookclub/          PRJ: the sqlite read-model store, eight projections
  query_bookclub/            QRY: the read-only query store, five query desks
  internal/                  bindings only (evoq, mesh, esqlite, cowboy, ...)
src/mcl_bookclub_gleam_ffi.erl
                             the Erlang edge: shapes Gleam cannot type
```

The facade owns everything that touches the mesh; the divisions import no
mesh SDK (the boundary tests pin that — see below). **Emitters live in the
facade** (the Phoenix twin's stricter boundary), not in host_bookclub.

## Boot order (load-bearing)

`mcl_om:boot/1` opens the reckon-db store and starts the evoq subscription —
whose catch-up replay *delivers* to registered `deliver`-policy projections —
**before** `ServiceMod:start/1` fires. The twins get the ordering from their
umbrella application order; this single app gets it from
[`app.gleam`](src/mcl_bookclub_gleam/app.gleam): the division supervisors
start **first**, then `mcl_om:boot/1`. The facade's own supervisor (admin +
emitters) starts inside `ServiceMod:start/1`, after the replay — harmless for
the `skip`-policy emitters.

## Deviations from the twins, all deliberate

- **Stores are `gleam_otp` actors, not gen_servers.** A NIF connection still
  belongs to the process that opened it (the actor owns it). `health/0`
  probes them with a safe ping that cannot crash the caller
  (`internal/health`), because Gleam actors are not gen_servers.
- **`data_dir/0` is a real charlist** (dets/ra rejects binaries). Note that
  `gleam_erlang`'s own `charlist` module stores a *binary* — the release path
  uses `binary_to_list` through the FFI.
- **Registered names are exact atoms.** `gleam_erlang`'s `process.new_name/1`
  always appends a unique suffix, so the stores register under an exact atom
  via the FFI, and the health ping rides the actor's `{Name, Message}` subject
  envelope.
- **The release is assembled by rebar3's relx from `gleam build` output.**
  Gleam owns compilation; `scripts/release.sh` stages a patched copy
  (mod entry in, test beams and the gleeunit dev dep out, every beam unioned
  into the modules list — `gleam_otp`/`gleam_erlang` ship beams their own
  `.app` files omit, which is an `undef` at boot otherwise) and `rebar3
  release` assembles it. See [`rebar.config`](rebar.config).

## The wire contract (shared with the twins)

- **Org**: `mcl-bookclub`. **Capability**: `get_bookclub_by_id`
  (`mcl-bookclub/get_bookclub_by_id`, `auth => open`).
- **Three fact topics**, one per fact kind, ids and names in the payload:
  `bookclub/member/member_registered_v1`,
  `bookclub/book/book_procured_v1`,
  `bookclub/book/book_retired_v1`.
- Facts are read with `mcl_om_wire:field/2` (Demon 65); text travels as CBOR
  text, booleans as 1/0.

## Where `dynamic.Dynamic` lives, and why

Gleam is a typed language, and the domain is fully typed: commands, events,
aggregate states and the QRY desks' results are all records. `Dynamic`
appears in exactly three places, and each is a deliberate boundary:

1. **The evoq envelope.** evoq hands the aggregate a *map* for `execute/2`
   and `apply/2` and the handler a map for `handle_event/4` — atom keys in
   memory, binary keys from the store, `{text, Bin}` on the wire. Tolerance
   is part of the contract (Demon 65), so `Payload = Dict(Dynamic, Dynamic)`
   at that boundary, converted to typed values the moment a desk reads it.
2. **The sqlite cell.** Rows are lists of cells; SQL NULL is the atom
   `undefined`. The QRY desks coerce each cell to a typed field
   (`desk.cell_string`, `desk.cell_int`, `desk.cell_int_option`) and return
   typed records — `Dynamic` never leaves the store module.
3. **The wire.** `mcl_om_wire:field/2` and `facts.to_wire` read and write
   wire-shaped terms; the facade converts between the typed desks and the
   wire in one place per capability.

The alternative — modeling heterogeneous Erlang terms as Gleam types —
would be a facade over a facade; the corpus's "no wrapper" convention says
call Erlang directly, and the typed boundary above is where that call is
contained.

## Building and testing

```sh
# Everything is scoped: the ambient shell is OTP 29; the repos pin OTP 28.4.3
# and gleam 1.18.1 (see .tool-versions).
mise x erlang@28.4.3 gleam@1.18.1 -- gleam build
scripts/test.sh            # gleam test cannot pass a sys.config to erl; the
                           # wrapper loads config/test.sys.config and runs the
                           # generated test main
mise x erlang@28.4.3 gleam@1.18.1 -- gleam format --check .
```

`scripts/test.sh` runs the 91-test suite: desk tests against a real reckon-db
store through evoq, projection and query-desk tests against the sqlite read
model, the facade contract tests, and the boundary tests.

## The boundary tests (the division wall)

- No division source imports the mesh SDK (`internal/mesh`, `macula`,
  `mcl_om`, `cowboy`, `esqlite`).
- No PRJ source spells a status literal — the readable names come from the
  status modules' flag maps (Demon 68).
- The QRY desks' SELECT columns are all declared by the PRJ schema.

## Release and deploy

`Containerfile` + `.github/workflows/ci.yml` mirror the twins: gates in the
pinned `macula-ci-gleam` image, then the image build (`:main` and `:<sha>`,
never `:latest`), digest-pinned in `macula-fleet` and rolled by the
reconciler. The realm grant for `mcl-bookclub/get_bookclub_by_id` + `info` is
issued by the operator; until then the node boots healthy and advertise fails
with `{provider_authorization, ...}` — the honest pre-grant state.

A local release boot against the real mesh:
`scripts/local_boot.sh` (health on `MCL_HEALTH_PORT`, admin UI on
`MCL_ADMIN_PORT`).

## License

Apache 2.0.
