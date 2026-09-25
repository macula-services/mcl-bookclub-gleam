-record(member_unregistered, {
    member_id :: binary(),
    club_id :: binary(),
    name :: binary(),
    registered_at :: integer(),
    unregistered_by :: binary(),
    unregistered_at :: integer()
}).
