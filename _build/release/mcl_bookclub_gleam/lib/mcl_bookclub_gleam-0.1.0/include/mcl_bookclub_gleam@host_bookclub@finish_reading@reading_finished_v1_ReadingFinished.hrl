-record(reading_finished, {
    reading_id :: binary(),
    member_id :: binary(),
    book_id :: binary(),
    started_at :: integer(),
    pages_read :: integer(),
    finished_at :: integer()
}).
