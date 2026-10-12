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

  def test_lead_values
    values, warnings = P.lead_values('OPP-20261000074', 'name' => 'งาน A', 'partner_id' => [759, 'บริษัท B จำกัด'])
    assert_equal({ 'ProjectName' => 'งาน A', 'ClientName' => 'บริษัท B จำกัด', 'ProjectNumber' => 'OPP-20261000074' }, values)
    assert_empty warnings
  end

  def test_lead_without_partner_or_name
    values, warnings = P.lead_values('OPP-1', 'name' => false, 'partner_id' => false)
    assert_equal '', values['ProjectName']
    assert_equal '', values['ClientName']
    assert_equal 2, warnings.size
    assert(warnings.all? { |w| w.include?('OPP-1') })
  end

  def test_summary
    assert_equal "สร้าง LayOut แล้ว:\n/a/b.layout", P.summary('/a/b.layout', [])
    assert_match(/คำเตือน:\n- w1\n- w2\z/, P.summary('/a/b.layout', %w[w1 w2]))
  end
end
