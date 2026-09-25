-record(exec, {
    sql :: binary(),
    args :: list(gleam@dynamic:dynamic_()),
    reply_to :: gleam@erlang@process:subject({ok, nil} | {error, gleam@dynamic:dynamic_()})
}).
