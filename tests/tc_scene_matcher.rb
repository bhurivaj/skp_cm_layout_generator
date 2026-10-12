# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_scene_matcher.rb
require 'minitest/autorun'
require_relative '../skp_cm_layout_generator/scene_matcher'

class TestSceneMatcher < Minitest::Test
  M = SkpCm::LayoutGenerator::SceneMatcher
  SCENES = ['Last saved SketchUp View', 'Overall', 'A-1', 'A-2'].freeze

  def test_single_viewport_uses_page_name
    assert_equal [{ 'viewport' => 0, 'scene_name' => 'Overall', 'scene_index' => 1 }],
                 M.match('Overall', [[1.0, 1.0]], SCENES)
  end

  def test_two_viewports_left_to_right
    result = M.match('A', [[6.0, 1.0], [1.0, 1.0]], SCENES)
    assert_equal [[1, 'A-1', 2], [0, 'A-2', 3]], result.map { |r| r.values_at('viewport', 'scene_name', 'scene_index') }
  end

  def test_same_column_top_to_bottom_with_tiny_x_difference
    result = M.match('A', [[1.004, 5.0], [1.0, 1.0]], SCENES)
    assert_equal [1, 0], result.map { |r| r['viewport'] }, 'upper viewport first even when its x is 0.004 smaller'
  end

  def test_missing_scene_is_nil
    result = M.match('B', [[1.0, 1.0], [2.0, 1.0], [3.0, 1.0]], SCENES)
    assert_equal %w[B-1 B-2 B-3], result.map { |r| r['scene_name'] }
    assert(result.all? { |r| r['scene_index'].nil? })
  end

  def test_thai_page_name_and_exact_match_only
    scenes = ['Last saved SketchUp View', 'ผัง', 'overall']
    assert_equal 1, M.match('ผัง', [[0, 0]], scenes).first['scene_index']
    assert_nil M.match('Overall', [[0, 0]], scenes).first['scene_index'], 'names must match exactly'
  end

  def test_no_viewports
    assert_equal [], M.match('A', [], SCENES)
  end
end
