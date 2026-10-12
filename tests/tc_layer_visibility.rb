# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_layer_visibility.rb
require 'minitest/autorun'
require_relative '../skp_cm_layout_generator/page_cloner'

class TestLayerVisibility < Minitest::Test
  C = SkpCm::LayoutGenerator::PageCloner
  Layer = Struct.new(:name)

  # Page that remembers per-layer visibility (keyed by layer name)
  class VisPage
    attr_reader :name, :set_calls

    def initialize(name, hidden = [], fail_on = nil)
      @name = name
      @hidden = hidden
      @fail_on = fail_on
      @set_calls = []
    end

    def layer_visible?(layer)
      !@hidden.include?(layer.name)
    end

    def set_layer_visibility(layer, visible)
      raise ArgumentError, 'locked' if layer.name == @fail_on

      @set_calls << [layer.name, visible]
      visible ? @hidden.delete(layer.name) : @hidden << layer.name
    end
  end

  Doc = Struct.new(:layers)

  def test_new_page_hides_the_same_layers_as_the_template_page
    source_doc = Doc.new([Layer.new('Layout'), Layer.new('Watermark'), Layer.new('Notes')])
    doc = Doc.new([Layer.new('Layout'), Layer.new('Watermark'), Layer.new('Notes'), Layer.new('Extra')])
    from = VisPage.new('A', %w[Watermark Notes])
    to = VisPage.new('tent2 - A')
    warnings = C.copy_layer_visibility(from, source_doc, to, doc)
    assert_empty warnings
    assert_equal [%w[Watermark false], %w[Notes false]], to.set_calls.map { |n, v| [n, v.to_s] }
    assert to.layer_visible?(Layer.new('Extra')), 'layers the template does not have are left alone'
  end

  def test_failure_on_one_layer_warns_and_continues
    source_doc = Doc.new([Layer.new('A1'), Layer.new('B1')])
    doc = Doc.new([Layer.new('A1'), Layer.new('B1')])
    to = VisPage.new('tent2 - A', [], 'A1')
    warnings = C.copy_layer_visibility(VisPage.new('A', %w[A1 B1]), source_doc, to, doc)
    assert_equal [%w[B1 false]], to.set_calls.map { |n, v| [n, v.to_s] }
    assert_match(/A1.*tent2 - A.*locked/, warnings.first)
  end
end
