# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_title_text.rb
require 'minitest/autorun'
require_relative '../skp_cm_layout_generator/title_text'

class TestTitleText < Minitest::Test
  T = SkpCm::LayoutGenerator::TitleText

  def test_page_name
    assert_equal 'tent1 - Overall', T.page_name('tent1', 'Overall')
    assert_equal 'งาน แบบ - A', T.page_name('งาน แบบ', 'A')
  end

  def test_model_present_matches_full_page_names_only
    names = ['Cover Page', 'tent1 - Overall', 'tent1 - A', 'a - b - A']
    assert T.model_present?(names, 'tent1', %w[Overall A])
    refute T.model_present?(names, 'tent10', %w[Overall A]), 'tent10 must not match tent1 pages'
    refute T.model_present?(names, 'tent', %w[Overall A])
    refute T.model_present?(names, 'a', %w[Overall A]), 'model "a" must not match pages of model "a - b"'
    assert T.model_present?(names, 'a - b', %w[Overall A])
  end

  def test_sequence_letters
    assert_equal [], T.sequence_letters(0)
    assert_equal %w[A], T.sequence_letters(1)
    assert_equal %w[A B C], T.sequence_letters(3)
    letters = T.sequence_letters(28)
    assert_equal %w[Y Z AA AB], letters[24, 4]
    assert_equal 'AZ', T.sequence_letters(52).last
    assert_equal 'BA', T.sequence_letters(53).last
  end

  def test_with_line2_replaces_everything_after_first_line
    assert_equal "<PageName>\nA-01, A-02", T.with_line2('<PageName>', 'A-01, A-02')
    assert_equal "<PageName>\nA", T.with_line2("<PageName>\n", 'A')
    assert_equal "<PageName>\nB", T.with_line2("<PageName>\nold\nolder", 'B')
    assert_equal "<PageNumber>\nA, B", T.with_line2("<PageNumber>\r", 'A, B')
    assert_equal "<PageNumber>\nA", T.with_line2("<PageNumber>\r\nx", 'A')
    assert_equal "\nA", T.with_line2(nil, 'A')
  end
end
