-record(bookclub_state, {
    club_id :: binary(),
    name :: binary(),
    initiated_by :: binary(),
    initiated_at :: integer(),
    parties_planned :: integer(),
    status :: integer()
}).
