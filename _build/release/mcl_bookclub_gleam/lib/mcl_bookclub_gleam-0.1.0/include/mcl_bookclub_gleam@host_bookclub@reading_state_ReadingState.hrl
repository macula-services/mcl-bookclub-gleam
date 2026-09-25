-record(reading_state, {
    reading_id :: binary(),
    member_id :: binary(),
    book_id :: binary(),
    started_at :: integer(),
    pages_read :: integer(),
    status :: integer()
}).
