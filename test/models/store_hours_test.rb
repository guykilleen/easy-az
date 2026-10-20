require "test_helper"

class StoreHoursTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  ZONE = "Australia/Brisbane".freeze

  def setup
    Counter.where(key: ["store_open_until"] + StoreHours::SCHEDULES.flat_map { |s|
      ["hours_#{s}_open", "hours_#{s}_close"]
    }).delete_all
  end

  def teardown
    travel_back
    setup  # clear counters written by tests
  end

  # ── Always-open defaults ───────────────────────────────────────────────────

  test "store is open at all hours by default" do
    [
      [2026, 5, 4,  0,  0],  # Mon midnight
      [2026, 5, 4, 11, 30],  # Mon 11:30am
      [2026, 5, 4, 16,  0],  # Mon 4pm
      [2026, 5, 4, 23,  0],  # Mon 11pm
      [2026, 5, 9,  7,  0],  # Sat 7am
      [2026, 5, 10, 17, 0],  # Sun 5pm
      [2026, 4,  7,  8, 0],  # Holiday weekday 8am
    ].each do |args|
      travel_to Time.find_zone(ZONE).local(*args)
      assert StoreHours.open?, "expected open at #{args.inspect}"
    end
  end

  test "hours_config returns always-open defaults when no counters set" do
    cfg = StoreHours.hours_config
    StoreHours::SCHEDULES.each do |s|
      assert_equal 0,    cfg[s][:open],  "#{s} open should default to 0"
      assert_equal 1440, cfg[s][:close], "#{s} close should default to 1440"
    end
  end

  # ── Custom hours via DB config ─────────────────────────────────────────────

  test "store respects narrow weekday hours when set" do
    # Set weekday to 4pm-7:30pm
    StoreHours.update_hours("weekday" => { open: "16:00", close: "19:30" })

    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 15, 59)  # Mon 3:59pm
    refute StoreHours.scheduled_open?

    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 16, 0)   # Mon 4:00pm
    assert StoreHours.scheduled_open?

    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 19, 29)  # Mon 7:29pm
    assert StoreHours.scheduled_open?

    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 19, 30)  # Mon 7:30pm
    refute StoreHours.scheduled_open?
  end

  test "store respects narrow saturday hours when set" do
    StoreHours.update_hours("saturday" => { open: "07:30", close: "19:30" })

    travel_to Time.find_zone(ZONE).local(2026, 5, 9, 7, 0)   # Sat 7:00am
    refute StoreHours.scheduled_open?

    travel_to Time.find_zone(ZONE).local(2026, 5, 9, 7, 30)  # Sat 7:30am
    assert StoreHours.scheduled_open?

    travel_to Time.find_zone(ZONE).local(2026, 5, 9, 19, 30) # Sat 7:30pm
    refute StoreHours.scheduled_open?
  end

  test "store respects narrow sunday hours when set" do
    StoreHours.update_hours("sunday" => { open: "07:30", close: "17:00" })

    travel_to Time.find_zone(ZONE).local(2026, 5, 10, 7, 0)  # Sun 7:00am
    refute StoreHours.scheduled_open?

    travel_to Time.find_zone(ZONE).local(2026, 5, 10, 16, 59) # Sun 4:59pm
    assert StoreHours.scheduled_open?

    travel_to Time.find_zone(ZONE).local(2026, 5, 10, 17, 0)  # Sun 5:00pm
    refute StoreHours.scheduled_open?
  end

  test "holiday weekday uses holiday schedule when set" do
    StoreHours.update_hours(
      "weekday" => { open: "16:00", close: "19:30" },
      "holiday" => { open: "07:30", close: "19:30" }
    )

    # Holiday weekday -- uses holiday schedule, not weekday
    travel_to Time.find_zone(ZONE).local(2026, 4, 7, 8, 0)   # Tue autumn holidays
    assert StoreHours.scheduled_open?

    travel_to Time.find_zone(ZONE).local(2026, 4, 7, 7, 0)   # Too early even for holiday
    refute StoreHours.scheduled_open?

    # Non-holiday weekday -- uses weekday schedule
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 8, 0)   # Mon during term -- 8am, before weekday open
    refute StoreHours.scheduled_open?
  end

  test "update_hours persists and round-trips via minutes_to_time" do
    StoreHours.update_hours("weekday" => { open: "09:15", close: "22:45" })
    cfg = StoreHours.hours_config
    assert_equal "09:15", StoreHours.minutes_to_time(cfg["weekday"][:open])
    assert_equal "22:45", StoreHours.minutes_to_time(cfg["weekday"][:close])
  end

  # ── Override (Counter store_open_until) ───────────────────────────────────

  test "override unlocks store when scheduled hours are narrow" do
    StoreHours.update_hours("weekday" => { open: "16:00", close: "19:30" })
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 23, 0)  # Mon 11pm
    refute StoreHours.open?
    Counter.create!(key: "store_open_until", value: (Time.now + 30 * 60).to_i)
    assert StoreHours.open?
  end

  test "expired override does not unlock" do
    StoreHours.update_hours("weekday" => { open: "16:00", close: "19:30" })
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 23, 0)
    Counter.create!(key: "store_open_until", value: (Time.now - 60).to_i)
    refute StoreHours.open?
  end

  test "override_active? false when no record" do
    refute StoreHours.override_active?
  end

  test "override_active? true when future" do
    Counter.create!(key: "store_open_until", value: (Time.now + 60).to_i)
    assert StoreHours.override_active?
  end

  test "override_active? false when past" do
    Counter.create!(key: "store_open_until", value: (Time.now - 60).to_i)
    refute StoreHours.override_active?
  end

  # ── Holiday table health ──────────────────────────────────────────────────
  #
  # The holiday list is hand-maintained in two places. These two tests are the
  # only thing standing between us and another silent lockout, so if one fails
  # the fix is data, not the assertion.

  JS_HOURS_PATH = Rails.root.join("public", "opening-hours.js").freeze

  test "ruby and js holiday tables agree" do
    js = File.read(JS_HOURS_PATH)
    js_holidays = js.scan(/\{\s*from:\s*"(\d{4}-\d{2}-\d{2})",\s*to:\s*"(\d{4}-\d{2}-\d{2})"\s*\}/)
                    .map { |from, to| { from: from, to: to } }

    assert js_holidays.any?, "could not parse any holiday ranges out of #{JS_HOURS_PATH}"
    assert_equal StoreHours::HOLIDAYS.map { |h| h.slice(:from, :to) }, js_holidays,
      "HOLIDAYS in store_hours.rb and opening-hours.js have drifted. " \
      "They must match exactly or the server and the browser disagree about opening time."
  end

  test "holiday coverage extends into the future" do
    last = StoreHours::HOLIDAYS.map { |h| Date.parse(h[:to]) }.max
    runway = (last - Date.current).to_i

    assert runway >= 30,
      "School holiday data runs out on #{last} (#{runway} days away). Top up HOLIDAYS in " \
      "app/models/store_hours.rb AND public/opening-hours.js from " \
      "https://education.qld.gov.au/about-us/calendar/term-dates before the next break."
  end
end
