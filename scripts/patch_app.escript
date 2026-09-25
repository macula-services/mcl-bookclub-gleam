#!/usr/bin/env escript
%% Patch an app's .app file into a releasable shape, in place:
%%
%%   scripts/patch_app.escript <ebin-dir> [with_mod]
%%
%%   - union the modules list with EVERY beam in the ebin dir. relx's
%%     embedded boot script preloads only listed modules, and a package can
%%     ship a beam its own .app omits (gleam_otp 1.3.0 omits
%%     gleam_otp_external, which its static_supervisor calls -- undef at
%%     boot otherwise).
%%   - drop test modules (*_test, <app>@test_support, <app>@@main).
%%   - drop the gleeunit dev dependency from applications.
%%   - with_mod: add {mod, {<app>@app, []}} -- the OTP entry (app.gleam) --
%%     for the service app only.
%%
%% Runs on the STAGED tree (scripts/release.sh), never on the build output
%% the gleam test wrapper uses.
main(Args) ->
    {EbinDir, WithMod} = case Args of
        [E, "with_mod"] -> {E, true};
        [E] -> {E, false}
    end,
    AppName = filename:basename(filename:dirname(EbinDir)),
    AppFile = filename:join(EbinDir, AppName ++ ".app"),
    {ok, [{application, Name, Props}]} = file:consult(AppFile),

    Beams = [list_to_atom(filename:rootname(filename:basename(F)))
             || F <- filelib:wildcard("*.beam", EbinDir)],
    Beams1 = [B || B <- Beams, not is_test_module(B)],

    Listed0 = proplists:get_value(modules, Props, []),
    Listed = [M || M <- Listed0, not is_test_module(M)],
    Modules = lists:usort(Beams1 ++ Listed),

    Apps0 = proplists:get_value(applications, Props, []),
    Apps = [A || A <- Apps0, A =/= gleeunit],

    Props1 = lists:keystore(modules, 1, Props, {modules, Modules}),
    Props2 = lists:keystore(applications, 1, Props1, {applications, Apps}),
    Props3 = case WithMod of
        true ->
            Mod = list_to_atom(AppName ++ "@app"),
            case lists:keymember(mod, 1, Props2) of
                true -> Props2;
                false -> Props2 ++ [{mod, {Mod, []}}]
            end;
        false -> Props2
    end,
    ok = file:write_file(AppFile, io_lib:format("~p.~n", [{application, Name, Props3}])).

is_test_module(M) ->
    case lists:suffix("_test", atom_to_list(M)) of
        true -> true;
        false ->
            lists:member(M, ['mcl_bookclub_gleam@test_support',
                             'mcl_bookclub_gleam@@main'])
    end.
