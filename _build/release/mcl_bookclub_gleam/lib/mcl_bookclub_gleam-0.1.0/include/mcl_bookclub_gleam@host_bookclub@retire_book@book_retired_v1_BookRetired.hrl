-record(book_retired, {
    book_id :: binary(),
    club_id :: binary(),
    title :: binary(),
    author :: binary(),
    procured_at :: integer(),
    club_name :: binary(),
    retired_by :: binary(),
    retired_at :: integer()
}).
