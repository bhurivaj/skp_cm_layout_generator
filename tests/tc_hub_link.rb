# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_hub_link.rb
require 'minitest/autorun'
require_relative '../skp_cm_layout_generator/hub_link'

class TestHubLink < Minitest::Test
  L = SkpCm::LayoutGenerator::HubLink
  LEAD = { 'id' => 5, 'name' => 'P', 'partner_id' => [759, 'C'] }.freeze

  # Stands in for SkpCm::ExtensionsHub::Auth (Hub 0.5.0+). replies: model => [ok, result]
  class FakeAuth
    attr_reader :calls
    attr_accessor :uid

    def initialize(replies)
      @replies = replies
      @calls = []
      @uid = 7
    end

    def execute_kw(*args, &done)
      @calls << args
      done.call(*@replies.fetch(args[0]))
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

  def call_once(method, opp = 'OPP-20261000074')
    calls = []
    L.public_send(method, opp) { |ok, value| calls << [ok, value] }
    assert_equal 1, calls.size
    calls.first
  end

  def all_ok(overrides = {})
    { 'crm.lead' => [true, [LEAD]],
      'res.partner' => [true, [{ 'id' => 759, 'contact_address' => "C\n1 Road" }]],
      'res.users' => [true, [{ 'id' => 7, 'name' => 'Pensom J.' }]] }.merge(overrides)
  end

  def test_no_hub
    remove_hub
    assert_nil L.auth
    assert_equal [false, L::MISSING_MESSAGE], call_once(:find_lead)
    assert_equal [false, L::MISSING_MESSAGE], call_once(:fetch_project)
  end

  def test_old_hub_without_execute_kw
    install_hub(Object.new)
    assert_nil L.auth
    ok, msg = call_once(:find_lead)
    assert_equal false, ok
    assert_match(/0\.5\.0/, msg)
  end

  def test_found
    auth = FakeAuth.new(all_ok)
    install_hub(auth)
    assert_equal [true, LEAD], call_once(:find_lead)
    assert_equal [['crm.lead', 'search_read', [[['reference_code', '=', 'OPP-20261000074']]],
                   { 'fields' => %w[name partner_id], 'limit' => 1 }]], auth.calls
  end

  def test_not_found
    install_hub(FakeAuth.new(all_ok('crm.lead' => [true, []])))
    assert_equal [true, nil], call_once(:find_lead)
    assert_equal [true, nil], call_once(:fetch_project)
  end

  def test_hub_error_passes_message
    install_hub(FakeAuth.new(all_ok('crm.lead' => [false, 'เชื่อมต่อ server ไม่ได้ (network error)'])))
    assert_equal [false, 'เชื่อมต่อ server ไม่ได้ (network error)'], call_once(:find_lead)
    assert_equal [false, 'เชื่อมต่อ server ไม่ได้ (network error)'], call_once(:fetch_project)
  end

  def test_unexpected_result
    install_hub(FakeAuth.new(all_ok('crm.lead' => [true, false])))
    ok, msg = call_once(:find_lead)
    assert_equal false, ok
    assert_match(/ไม่ถูกต้อง/, msg)
  end

  def test_fetch_project_reads_address_and_user
    auth = FakeAuth.new(all_ok)
    install_hub(auth)
    ok, project = call_once(:fetch_project)
    assert ok
    assert_equal({ 'lead' => LEAD, 'contact_address' => "C\n1 Road", 'user_name' => 'Pensom J.', 'warnings' => [] },
                 project)
    assert_equal ['res.partner', 'read', [[759]], { 'fields' => %w[contact_address] }], auth.calls[1]
    assert_equal ['res.users', 'read', [[7]], { 'fields' => %w[name] }], auth.calls[2]
  end

  def test_fetch_project_without_partner_skips_address
    auth = FakeAuth.new(all_ok('crm.lead' => [true, [LEAD.merge('partner_id' => false)]]))
    install_hub(auth)
    ok, project = call_once(:fetch_project)
    assert ok
    assert_equal '', project['contact_address']
    assert_equal %w[crm.lead res.users], auth.calls.map(&:first)
  end

  def test_fetch_project_address_and_user_failures_are_warnings
    install_hub(FakeAuth.new(all_ok('res.partner' => [false, 'Odoo แจ้ง error: x'], 'res.users' => [true, []])))
    ok, project = call_once(:fetch_project)
    assert ok, 'missing address or drawer name must not stop the LayOut'
    assert_equal ['', ''], project.values_at('contact_address', 'user_name')
    assert_equal 2, project['warnings'].size
    assert_match(/ที่อยู่.*Odoo แจ้ง error: x/, project['warnings'][0])
    assert_match(/ชื่อผู้เขียนแบบ/, project['warnings'][1])
  end

  def test_fetch_project_without_uid_warns
    auth = FakeAuth.new(all_ok)
    auth.uid = nil
    install_hub(auth)
    _ok, project = call_once(:fetch_project)
    assert_equal '', project['user_name']
    assert_equal 1, project['warnings'].size
    refute_includes auth.calls.map(&:first), 'res.users'
  end
end
