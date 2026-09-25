%%% mcl_bookclub_gleam_ffi: the Erlang edge of the Gleam twin.
%%%
%%% Gleam's @external calls an Erlang function directly, so a function is
%%% bound here only when its Erlang shape cannot type in Gleam: evoq's
%%% three-tuple {ok, Version, Events}, mcl_om's {ok, Pool, Realm},
%%% esqlite3's bare-list-or-error returns, jsx's decode-anything-or-raise,
%%% and the health ping, which must never crash the caller.
%%%
%%% Everything here is a SHAPE ADAPTER or a SAFETY WRAPPER. No domain logic,
%%% no business decisions -- those live in the Gleam departments.
-module(mcl_bookclub_gleam_ffi).

-export([dispatch/2]).
-export([mesh_handles/0]).
-export([decode_atoms/1]).
-export([read_body/1]).
-export([sqlite_q/3, sqlite_exec/3]).
-export([safe_ping/2, send_reply/2]).
-export([wrap/1]).
-export([logger_warning/1]).
-export([bin_to_list/1]).
-export([validate_stream_id/1]).
-export([test_set_evoq_env/1, test_ensure_store/2, test_start_subscription/1,
         test_read_stream/2, test_source_files/1, file_read/1]).

%%% evoq_command_router:dispatch/2 returns {ok, Version, [Event]} -- a
%%% three-tuple Gleam's Result cannot carry. Reshaped to
%%% {ok, {Version, Events}} | {error, Reason}.
dispatch(Command, Opts) ->
    case evoq_command_router:dispatch(Command, Opts) of
        {ok, Version, Events} -> {ok, {Version, Events}};
        {error, Reason} -> {error, Reason}
    end.

%%% mcl_om:mesh_handles/0 returns {ok, Pool, Realm}. Reshaped to
%%% {ok, {Pool, Realm}} | {error, Reason}.
mesh_handles() ->
    case mcl_om:mesh_handles() of
        {ok, Pool, Realm} -> {ok, {Pool, Realm}};
        {error, Reason} -> {error, Reason}
    end.

%%% jsx decode with atom labels, tolerant of anything undecodable: an empty
%%% map, never a crash. The desk entry points turn missing fields into
%%% {error, missing_required_fields} -- the answer the operator needs, the
%%% same policy the Erlang twin's admin decode/1 carries.
decode_atoms(Body) ->
    try jsx:decode(Body, [{labels, atom}]) of
        Params when is_map(Params) -> Params;
        _ -> #{}
    catch
        _:_ -> #{}
    end.

%%% cowboy_req:read_body/1 returns {ok, Body, Req} -- reshaped to
%%% {ok, {Body, Req}}.
read_body(Req) ->
    case cowboy_req:read_body(Req) of
        {ok, Body, Req1} -> {ok, {Body, Req1}};
        {more, _, Req1} -> {ok, {<<>>, Req1}}
    end.

%%% esqlite3:q/3 returns a bare list of rows or {error, Reason}. Wrapped so
%%% Gleam sees {ok, Rows} | {error, Reason}.
sqlite_q(Conn, Sql, Args) ->
    case esqlite3:q(Conn, Sql, Args) of
        {error, _} = Error -> Error;
        Rows -> {ok, Rows}
    end.

%%% A single parameterised write: ok, or {error, Reason}. Mirrors the
%%% twins' do_exec: zero rows means the statement ran; a statement that
%%% returned rows is a bug to surface, not to swallow.
sqlite_exec(Conn, Sql, Args) ->
    case esqlite3:q(Conn, Sql, Args) of
        [] -> ok;
        {error, _} = Error -> Error;
        Rows -> {error, {unexpected_rows, Rows}}
    end.

%%% A health ping that cannot crash the caller. whereis, monitor, ask,
%%% answer honestly either way:
%%%   {ok, Reply} | {error, missing} | {error, {down, Reason}} | {error, timeout}
%%% The twin's stores answer `ping' with the atom ok; gleam_otp actors are
%%% not gen_servers, so this is the actor-shaped equivalent of the twins'
%%% try gen_server:call catch exit:_ -> missing end. The message shape
%%% {ping, {Pid, Ref}} is the runtime encoding of the stores' Gleam
%%% `Ping(reply_to: #(Pid, Ref))' variant -- the selector matches it, and
%%% the handler answers through send_reply/2.
safe_ping(Name, Timeout) ->
    case whereis(Name) of
        undefined ->
            {error, missing};
        Pid ->
            Ref = erlang:monitor(process, Pid),
            Pid ! {ping, {self(), Ref}},
            receive
                {'DOWN', Ref, process, Pid, Reason} ->
                    {error, {down, Reason}};
                {Ref, Reply} ->
                    erlang:demonitor(Ref, [flush]),
                    {ok, Reply}
            after Timeout ->
                erlang:demonitor(Ref, [flush]),
                {error, timeout}
            end
    end.

%%% The reply half of the safe_ping protocol: the store actor answers a
%%% raw {Pid, Ref} ping by sending {Ref, Reply} to Pid.
send_reply({Pid, Ref}, Reply) ->
    Pid ! {Ref, Reply},
    ok.

%%% Identity for Dynamic: gleam_stdlib 1.x dropped dynamic.from/1 in favor
%%% of typed constructors; this wraps any term (atoms, pids, tuples) that
%%% has no constructor.
wrap(Term) ->
    Term.

%%% A REAL charlist: gleam_erlang's charlist module stores a binary, and
%%% the twins' contract callbacks (data_dir/0, reckon-db paths) need an
%%% actual list of codepoints.
bin_to_list(Bin) ->
    binary_to_list(Bin).

%%% reckon_gater_stream_id:validate/1 returns a bare `ok' atom, which
%%% Gleam's Result cannot carry. Reshaped to {ok, nil} | {error, Reason}.
validate_stream_id(Id) ->
    case reckon_gater_stream_id:validate(Id) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

%%% The policy's warn channel: logger:warning/1, for refusals that must not
%%% take the delivery of later events down with them.
logger_warning(Term) ->
    logger:warning(Term),
    ok.

%%% =========================================================================
%%% Test support: the reckon-db plumbing the twins reach through -include_lib
%%% records, exposed here so Gleam tests never build a #store_config{} tuple.
%%% =========================================================================

-include_lib("reckon_db/include/reckon_db.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

%%% The evoq env a desk test needs: the reckon-db adapter on all three
%%% roles and the store id, exactly what the twins' test stores set.
test_set_evoq_env(StoreId) ->
    [ok = application:set_env(evoq, K, V)
     || {K, V} <- [{event_store_adapter, reckon_evoq_adapter},
                   {subscription_adapter, reckon_evoq_adapter},
                   {snapshot_store_adapter, reckon_evoq_adapter},
                   {store_id, StoreId}]],
    {ok, nil}.

%%% Start the store (single mode), the same call the facade's boot makes.
%%% Idempotent across the suite: the tests share ONE store per VM, like the
%%% twins' eunit setup; a later suite's start finds it already running.
test_ensure_store(StoreId, DataDir) ->
    case mcl_om_store:ensure_store(StoreId, DataDir, [], single) of
        ok -> {ok, nil};
        {error, {already_started, _}} -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

%%% The store subscription, unlinked from the test process. One per store:
%%% a later suite's start finds it already running.
test_start_subscription(StoreId) ->
    case evoq_store_subscription:start_link(StoreId) of
        {ok, Sub} ->
            unlink(Sub),
            {ok, Sub};
        {error, {already_started, _}} ->
            {ok, already_running};
        {error, Reason} ->
            {error, Reason}
    end.

%%% A stream's events, as {EventType, Data} pairs: the record plumbing
%%% stays on this side of the FFI.
test_read_stream(StoreId, StreamId) ->
    events(reckon_db_streams:read(StoreId, StreamId, 0, 1000, forward)).

events({ok, Events}) ->
    [{EventType, Data}
     || #event{event_type = EventType, data = Data} <- Events];
events({error, {stream_not_found, _}}) ->
    [];
events({error, _} = Error) ->
    erlang:error(Error).

%%% Every source file under a directory, as {RelPath, Content} -- the
%%% boundary tests scan these for banned imports and status literals.
test_source_files(Dir) ->
    {ok, Entries} = file:list_dir(Dir),
    lists:flatmap(
      fun(Entry) ->
              Path = filename:join(Dir, Entry),
              case filelib:is_dir(Path) of
                  true -> test_source_files(Path);
                  false -> [{Path, file:read_file(Path)}]
              end
      end, Entries).

%%% file:read_file/1, shaped for Gleam.
file_read(Path) ->
    file:read_file(Path).
