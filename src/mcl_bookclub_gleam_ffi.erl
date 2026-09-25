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

%%% The policy's warn channel: logger:warning/1, for refusals that must not
%%% take the delivery of later events down with them.
logger_warning(Term) ->
    logger:warning(Term),
    ok.
