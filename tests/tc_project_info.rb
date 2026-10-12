# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_project_info.rb
require 'minitest/autorun'
require_relative '../skp_cm_layout_generator/project_info'

class TestProjectInfo < Minitest::Test
  P = SkpCm::LayoutGenerator::ProjectInfo
  BASE = '/Users/x/Library/CloudStorage/OneDrive-บริษัทแมวน้ำแข็งจำกัด/Classmat Project - Documents'

  def test_opp_from_project_folder
    assert_equal 'OPP-20220800031', P.opp_from_path("#{BASE}/OPP-20220800031/03_dwg/honda.skp")
  end

  def test_opp_inside_longer_folder_name
    assert_equal 'OPP-20261000074', P.opp_from_path("#{BASE}/OPP-20261000074 Coffee on the Beach/งาน แบบ.skp")
  end

  def test_deepest_opp_wins
    assert_equal 'OPP-20261000002', P.opp_from_path('/a/OPP-20261000001/sub/OPP-20261000002/x.skp')
  end

  def test_no_opp
    assert_nil P.opp_from_path('/a/b/OPP-123/x.skp')
    assert_nil P.opp_from_path('/a/OPP-202610000011/x.skp'), '12 digits is not an OPP number'
    assert_nil P.opp_from_path('/a/OPP-20261000001.skp'), 'file name alone does not count'
    assert_nil P.opp_from_path('')
    assert_nil P.opp_from_path(nil)
  end

  def test_windows_separators
    assert_equal 'OPP-20261000001', P.opp_from_path('C:\\Projects\\OPP-20261000001\\03_dwg\\a.skp')
  end

  def test_output_path_next_to_skp
    assert_equal "#{BASE}/OPP-1/03_dwg/งาน แบบ.layout", P.output_path("#{BASE}/OPP-1/03_dwg/งาน แบบ.skp")
    assert_equal '/a/B.layout', P.output_path('/a/B.SKP')
  end

  ADDRESS = "บริษัท B จำกัด\n253/9 AK Building ซอยสวนพลู6\nThung Maha Mek Sathon\nกรุงเทพมหานคร / Bangkok Thailand 10120"

  def project(lead, extra = {})
    { 'lead' => lead, 'contact_address' => '', 'user_name' => '', 'warnings' => [] }.merge(extra)
  end

  def test_lead_values
    values, warnings = P.lead_values('OPP-20261000074',
                                     project({ 'name' => 'งาน A', 'partner_id' => [759, 'บริษัท B จำกัด'] },
                                             'contact_address' => ADDRESS, 'user_name' => 'Pensom J.'))
    assert_equal({ 'ProjectName' => 'งาน A', 'ClientName' => 'บริษัท B จำกัด', 'ProjectNumber' => 'OPP-20261000074',
                   'ClientAddress' => "253/9 AK Building ซอยสวนพลู6\nThung Maha Mek Sathon\n" \
                                      'กรุงเทพมหานคร / Bangkok Thailand 10120',
                   'DrawnBy' => 'Pensom J.' }, values)
    assert_empty warnings
  end

  def test_lead_without_partner_or_name
    values, warnings = P.lead_values('OPP-1', project('name' => false, 'partner_id' => false))
    assert_equal '', values['ProjectName']
    assert_equal '', values['ClientName']
    assert_equal '', values['ClientAddress']
    assert_equal 2, warnings.size
    assert(warnings.all? { |w| w.include?('OPP-1') })
  end

  def test_fetch_warnings_are_kept
    _values, warnings = P.lead_values('OPP-1', project({ 'name' => 'P', 'partner_id' => [1, 'C'] },
                                                       'warnings' => ['อ่านชื่อผู้เขียนแบบไม่ได้']))
    assert_includes warnings, 'อ่านชื่อผู้เขียนแบบไม่ได้'
  end

  def test_address_keeps_first_line_when_it_is_not_the_client_name
    assert_equal "C, Mr. X\n1 Road", P.address_text("C, Mr. X\n1 Road\n", 'C')
    assert_equal '1 Road', P.address_text("  C \n\n1 Road", 'C')
    assert_equal '', P.address_text(false, 'C')
  end

  def test_summary
    assert_equal "สร้าง LayOut แล้ว:\n/a/b.layout", P.summary('/a/b.layout', [])
    assert_match(/คำเตือน:\n- w1\n- w2\z/, P.summary('/a/b.layout', %w[w1 w2]))
  end
end
