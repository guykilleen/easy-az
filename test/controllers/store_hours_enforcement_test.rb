require "test_helper"

# These tests exercise the server-side store-hours guard on controller actions.
#
# Existing controller tests run with enforcement OFF (default in test env) so
# they don't have to manage clock setup. To exercise the guard, flip the config
# flag in setup and use travel_to to put the clock outside open hours.
class StoreHoursEnforcementTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  ZONE = "Australia/Brisbane".freeze

  CLOSED_TIME = "2026-05-04 23:00:00".freeze  # Mon 11pm — closed
  OPEN_TIME   = "2026-05-04 17:00:00".freeze  # Mon 5pm  — open

  def setup
    RespectsStoreHours.enforce_in_test = true
    Counter.where(key: "store_open_until").delete_all
    # Set weekday hours to 4pm-7:30pm so CLOSED_TIME (Mon 11pm) is actually
    # closed and OPEN_TIME (Mon 5pm) is actually open.
    StoreHours.update_hours("weekday" => { open: "16:00", close: "19:30" })
  end

  def teardown
    RespectsStoreHours.enforce_in_test = false
    travel_back
    Counter.where(key: StoreHours::SCHEDULES.flat_map { |s|
      ["hours_#{s}_open", "hours_#{s}_close"]
    }).delete_all
  end

  def closed_clock!
    travel_to Time.find_zone(ZONE).parse(CLOSED_TIME)
  end

  def open_clock!
    travel_to Time.find_zone(ZONE).parse(OPEN_TIME)
  end

  # ── Gated endpoints redirect to /closed.html when shut ───────────────────

  GATED_GET_PATHS = [
    "/tv",
    "/watch",
    "/learn",
    "/scan",
    "/games/trivia",
    "/games/spotlight",
    "/games/treasure-hunt",
    "/games/hacker-pro",
    "/games/boomerang-brawl"
  ].freeze

  GATED_GET_PATHS.each do |path|
    test "#{path} redirects to /closed.html when store is shut" do
      closed_clock!
      get path
      assert_response :redirect
      assert_redirected_to "/closed.html"
    end

    test "#{path} succeeds (200 or redirect to game room) when store is open" do
      open_clock!
      get path
      assert_includes [200, 302], response.status,
        "expected #{path} to be reachable when open, got #{response.status}"
      # If it redirects, it must NOT be to /closed.html
      if response.status == 302
        refute_equal "/closed.html", URI.parse(response.location).path
      end
    end

    test "#{path} succeeds when an override is active" do
      closed_clock!
      Counter.create!(key: "store_open_until", value: (Time.now + 30 * 60).to_i)
      get path
      assert_includes [200, 302], response.status
      if response.status == 302
        refute_equal "/closed.html", URI.parse(response.location).path
      end
    end
  end

  # ── Always-on endpoints (must NEVER be gated) ─────────────────────────────

  ALWAYS_ON_PATHS = [
    "/up",                  # Rails health check
    "/api/version",
    "/api/store/status",
    "/code",                # the Cipher unlock mechanism
    "/closed.html"          # the closed page itself
  ].freeze

  ALWAYS_ON_PATHS.each do |path|
    test "#{path} stays reachable when store is shut" do
      closed_clock!
      get path
      # Status 200, OR a benign redirect that isn't /closed.html
      assert_includes [200, 302, 304], response.status,
        "expected #{path} not to be hard-blocked by hours, got #{response.status}"
      if response.status == 302
        refute_equal "/closed.html", URI.parse(response.location).path,
          "#{path} should not redirect to /closed.html"
      end
    end
  end
end
