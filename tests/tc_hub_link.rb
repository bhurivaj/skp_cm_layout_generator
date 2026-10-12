# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_hub_link.rb
require 'minitest/autorun'
require_relative '../skp_cm_layout_generator/hub_link'

class TestHubLink < Minitest::Test
  L = SkpCm::LayoutGenerator::HubLink

  # Stands in for SkpCm::ExtensionsHub::Auth (Hub 0.5.0+)
  class FakeAuth
    attr_reader :calls

    def initialize(*reply)
      @reply = reply
      @calls = []
    end

    def execute_kw(*args, &done)
      @calls << args
      done.call(*@reply)
    end
  end

  def install_hub(auth)
    SkpCm.const_set(:ExtensionsHub, Module.new) unless SkpCm.const_defined?(:ExtensionsHub, false)
    remove_hub
    SkpCm::ExtensionsHub.const_set(:Auth, auth)
  end

  def remove_hub
    hub = SkpCm.const_defined?(:ExtensionsHub, false) ? SkpCm::ExtensionsHub : nil
    hub.send(:remove_const, :Auth) if hub && hub.const_defined?(:Auth, false)
  end

  def teardown
    remove_hub
  end

  def find(opp = 'OPP-20261000074')
    calls = []
    L.find_lead(opp) { |ok, value| calls << [ok, value] }
    assert_equal 1, calls.size
    calls.first
  end

  def test_no_hub
    remove_hub
    assert_nil L.auth
    assert_equal [false, L::MISSING_MESSAGE], find
  end

  def test_old_hub_without_execute_kw
    install_hub(Object.new)
    assert_nil L.auth
    ok, msg = find
    assert_equal false, ok
    assert_match(/0\.5\.0/, msg)
  end

  def test_found
    auth = FakeAuth.new(true, [{ 'id' => 5, 'name' => 'P', 'partner_id' => [1, 'C'] }])
    install_hub(auth)
    assert_equal [true, { 'id' => 5, 'name' => 'P', 'partner_id' => [1, 'C'] }], find
    assert_equal [['crm.lead', 'search_read', [[['reference_code', '=', 'OPP-20261000074']]],
                   { 'fields' => %w[name partner_id], 'limit' => 1 }]], auth.calls
  end

  def test_not_found
    install_hub(FakeAuth.new(true, []))
    assert_equal [true, nil], find
  end

  def test_hub_error_passes_message
    install_hub(FakeAuth.new(false, 'เชื่อมต่อ server ไม่ได้ (network error)'))
    assert_equal [false, 'เชื่อมต่อ server ไม่ได้ (network error)'], find
  end

  def test_unexpected_result
    install_hub(FakeAuth.new(true, false))
    ok, msg = find
    assert_equal false, ok
    assert_match(/ไม่ถูกต้อง/, msg)
  end
end
