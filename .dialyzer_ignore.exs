[
  # OTP 29 reserves record/0. Ash Authentication Phoenix 2.17.4 still uses
  # Ash.Resource.record/0 in its controller callback type. Remove this exact
  # upstream filter when it switches to Ash.Resource.Record.t/0.
  {"lib/ash_authentication_phoenix/controller.ex", "Unknown type: Ash.Resource.record/0."}
]
