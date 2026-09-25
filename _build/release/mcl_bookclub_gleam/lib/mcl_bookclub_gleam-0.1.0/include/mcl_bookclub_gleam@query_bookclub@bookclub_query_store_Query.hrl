-record('query', {
    sql :: binary(),
    args :: list(gleam@dynamic:dynamic_()),
    reply_to :: gleam@erlang@process:subject({ok, list(list(gleam@dynamic:dynamic_()))} | {error, gleam@dynamic:dynamic_()})
}).
