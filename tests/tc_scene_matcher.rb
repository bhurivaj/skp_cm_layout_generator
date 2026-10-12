# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_scene_matcher.rb
require 'minitest/autorun'
require_relative '../skp_cm_layout_generator/scene_matcher'

class TestSceneMatcher < Minitest::Test
  M = SkpCm::LayoutGenerator::SceneMatcher
  SCENES = ['Last saved SketchUp View', 'Overall', 'A-1', 'A-2'].freeze

  def order(result)
    result.map { |r| r.values_at('viewport', 'scene_name', 'scene_index') }
  end

  def test_single_viewport_uses_page_name
    assert_equal [{ 'viewport' => 0, 'scene_name' => 'Overall', 'scene_index' => 1 }],
                 M.match('Overall', [[1.0, 1.0, 5.0]], SCENES)
  end

  # Template page "A" as measured by the probe: stacked, lower one starts 0.23" further right
  def test_stacked_viewports_top_first_even_when_lower_is_left
    result = M.match('A', [[2.715, 3.531, 6.497], [2.482, 1.148, 3.293]], SCENES)
    assert_equal [[1, 'A-1', 2], [0, 'A-2', 3]], order(result)
    result = M.match('A', [[2.0, 3.531, 6.497], [2.482, 1.148, 3.293]], SCENES)
    assert_equal [1, 0], result.map { |r| r['viewport'] }, 'upper viewport first even when the lower one is further left'
  end

  def test_side_by_side_row_left_to_right_with_uneven_tops
    result = M.match('A', [[6.0, 1.0, 4.0], [1.0, 1.3, 4.0]], SCENES)
    assert_equal [1, 0], result.map { |r| r['viewport'] }, 'overlapping heights = same row → left first'
  end

  def test_two_rows_of_two
    positions = [[5.0, 5.0, 7.0], [1.0, 5.2, 7.0], [5.0, 1.0, 4.0], [1.0, 1.1, 4.0]]
    assert_equal [3, 2, 1, 0], M.match('B', positions, []).map { |r| r['viewport'] }
  end

  def test_zero_padded_scene_names_match
    scenes = ['Last saved SketchUp View', 'A-01', 'A-002']
    result = M.match('A', [[1.0, 1.0, 2.0], [1.0, 3.0, 4.0]], scenes)
    assert_equal [[0, 'A-1', 1], [1, 'A-2', 2]], order(result)
  end

  def test_number_must_match_exactly
    scenes = ['Last saved SketchUp View', 'A-10', 'A-1x', 'AA-1']
    result = M.match('A', [[1.0, 1.0, 2.0], [1.0, 3.0, 4.0]], scenes)
    assert(result.all? { |r| r['scene_index'].nil? })
  end

  def test_page_name_with_regex_characters
    scenes = ['Last saved SketchUp View', 'A (1)-1', 'A (1)-2']
    result = M.match('A (1)', [[1.0, 1.0, 2.0], [1.0, 3.0, 4.0]], scenes)
    assert_equal [1, 2], result.map { |r| r['scene_index'] }
  end

  def test_missing_scene_is_nil
    result = M.match('B', [[1.0, 1.0, 2.0], [2.0, 1.0, 2.0], [3.0, 1.0, 2.0]], SCENES)
    assert_equal %w[B-1 B-2 B-3], result.map { |r| r['scene_name'] }
    assert(result.all? { |r| r['scene_index'].nil? })
  end

  def test_thai_page_name_and_exact_match_only
    scenes = ['Last saved SketchUp View', 'ผัง', 'overall']
    assert_equal 1, M.match('ผัง', [[0, 0, 1]], scenes).first['scene_index']
    assert_nil M.match('Overall', [[0, 0, 1]], scenes).first['scene_index'], 'names must match exactly'
  end

  def test_hairline_overlap_is_not_one_row
    result = M.match('A', [[2.0, 1.0, 4.0], [1.0, 3.99, 7.0]], [])
    assert_equal [0, 1], result.map { |r| r['viewport'] }, 'a 0.01" overlap must not merge stacked viewports'
  end

  def test_no_viewports
    assert_equal [], M.match('A', [], SCENES)
  end
end
