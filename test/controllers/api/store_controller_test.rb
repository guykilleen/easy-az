require "test_helper"

class Api::StoreControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  ZONE = "Australia/Brisbane".freeze

  HOUR_KEYS = StoreHours::SCHEDULES.flat_map { |s| ["hours_#{s}_open", "hours_#{s}_close"] }.freeze

  def setup
    Counter.where(key: ["store_open_until"] + HOUR_KEYS).delete_all
    # Pin to the original published schedule so assertions about
    # specific open/close times and closed states remain meaningful.
    StoreHours.update_hours(
      "weekday"  => { open: "16:00", close: "19:30" },
      "saturday" => { open: "07:30", close: "19:30" },
      "sunday"   => { open: "07:30", close: "17:00" },
      "holiday"  => { open: "07:30", close: "19:30" }
    )
  end

  def teardown
    travel_back
    Counter.where(key: HOUR_KEYS).delete_all
  end

  def body
    JSON.parse(response.body)
  end

  # ── Resolved state ────────────────────────────────────────────────────────

  test "reports open with the applicable schedule" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 17, 0)  # Mon 5pm
    get "/api/store/status"
    assert_response :success
    assert_equal true,      body["open"]
    assert_equal "weekday", body["schedule"]
    assert_equal "16:00",   body["opens_at"]
    assert_equal "19:30",   body["closes_at"]
    assert_nil              body["holiday"]
  end

  test "reports closed outside hours" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 11, 0)  # Mon 11am
    get "/api/store/status"
    assert_equal false,     body["open"]
    assert_equal "weekday", body["schedule"]
  end

  test "reports the sunday schedule with its earlier close" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 10, 9, 0)  # Sun 9am
    get "/api/store/status"
    assert_equal true,     body["open"]
    assert_equal "sunday", body["schedule"]
    assert_equal "17:00",  body["closes_at"]
  end

  test "names the matched holiday period on a holiday weekday" do
    travel_to Time.find_zone(ZONE).local(2026, 6, 30, 8, 0)  # Tue, winter break
    get "/api/store/status"
    assert_equal true,      body["open"]
    assert_equal "holiday", body["schedule"]
    assert_equal "07:30",   body["opens_at"]
    assert_equal({ "from" => "2026-06-27", "to" => "2026-07-12" }, body["holiday"])
  end

  test "includes the store timezone and current local time" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 17, 0)
    get "/api/store/status"
    assert_equal ZONE, body["zone"]
    assert_equal Time.find_zone(ZONE).local(2026, 5, 4, 17, 0).iso8601, body["now"]
  end

  # ── Override ──────────────────────────────────────────────────────────────

  test "override reports open and carries its expiry" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 23, 0)  # Mon 11pm — shut
    until_ts = (Time.now + 30 * 60).to_i
    Counter.create!(key: "store_open_until", value: until_ts)

    get "/api/store/status"
    assert_equal true,     body["open"]
    assert_equal true,     body["override"]
    assert_equal until_ts, body["open_until"]
  end

  test "expired override reports closed and no expiry" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 23, 0)
    Counter.create!(key: "store_open_until", value: (Time.now - 60).to_i)

    get "/api/store/status"
    assert_equal false, body["open"]
    assert_equal false, body["override"]
    assert_nil          body["open_until"]
  end

  # ── ?at= time travel (verifies the calendar without waiting for the date) ──

  test "at param answers for a future holiday morning" do
    travel_to Time.find_zone(ZONE).local(2026, 7, 26, 9, 0)  # today: a Sunday
    get "/api/store/status", params: { at: "2026-09-22T08:00:00+10:00" }
    assert_equal true,      body["open"], "spring break weekday 8am should be open"
    assert_equal "holiday", body["schedule"]
    assert_equal({ "from" => "2026-09-19", "to" => "2026-10-05" }, body["holiday"])
  end

  test "at param shows the same date is shut in term time" do
    get "/api/store/status", params: { at: "2026-08-18T08:00:00+10:00" }  # Tue, term 3
    assert_equal false,     body["open"]
    assert_equal "weekday", body["schedule"]
    assert_nil              body["holiday"]
  end

  test "at param is parsed in the store timezone when no offset is given" do
    get "/api/store/status", params: { at: "2026-09-22 08:00" }
    assert_equal true,      body["open"]
    assert_equal "holiday", body["schedule"]
  end

  test "unparseable at param falls back to now instead of erroring" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 17, 0)  # Mon 5pm — open
    get "/api/store/status", params: { at: "not-a-date" }
    assert_response :success
    assert_equal true, body["open"]
  end

  test "at param does not alter the store for anyone else" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 11, 0)  # Mon 11am — shut
    get "/api/store/status", params: { at: "2026-09-22T08:00:00+10:00" }
    assert_equal true, body["open"], "the hypothetical answer"

    get "/api/store/status"
    assert_equal false, body["open"], "the real answer must be unchanged"
    refute StoreHours.open?, "and the actual guard must still see the store as shut"
  end

  # ── Backwards compatibility ───────────────────────────────────────────────
  #
  # Browsers can hold a cached opening-hours.js that only understands
  # `override`. Those keys must keep their old meaning.

  test "keeps the original override and open_until keys" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 11, 0)
    get "/api/store/status"
    assert_includes body.keys, "override"
    assert_includes body.keys, "open_until"
    assert_equal false, body["override"]
    assert_nil          body["open_until"]
  end

  test "is not cached" do
    get "/api/store/status"
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
