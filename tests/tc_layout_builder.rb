# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_layout_builder.rb
require 'minitest/autorun'

# Minimal stand-ins for the LayOut Ruby API classes layout_builder.rb checks against
module Layout
  class AutoTextDefinition
    TYPE_CUSTOM_TEXT = 3
    attr_reader :name, :type, :custom_text

    def initialize(name, error = nil)
      @name = name
      @type = TYPE_CUSTOM_TEXT
      @error = error
    end

    def custom_text=(text)
      raise ArgumentError, @error if @error

      @custom_text = text
    end
  end

  class SketchUpModel; end
  class Group; end
end

require_relative '../skp_cm_layout_generator/layout_builder'

class TestLayoutBuilder < Minitest::Test
  B = SkpCm::LayoutGenerator::LayoutBuilder
  Layer = Struct.new(:locked_flag) do
    def locked?
      locked_flag
    end
  end
  LayerInstance = Struct.new(:definition)
  Viewport = Struct.new(:locked_flag, :layer_instance) do
    def locked?
      locked_flag
    end
  end
  Page = Struct.new(:name)

  class FakeDoc
    attr_reader :added, :removed, :auto_text_definitions

    def initialize(definitions = [], fail_remove: nil)
      @auto_text_definitions = definitions
      @fail_remove = fail_remove
      @added = []
      @removed = []
    end

    def add_entity(entity, layer, page)
      @added << [entity, layer, page]
    end

    def remove_entity(entity)
      raise ArgumentError, 'entity is locked' if entity.equal?(@fail_remove)

      @removed << entity
    end
  end

  def test_auto_text_failure_becomes_warning_and_others_still_fill
    defs = [Layout::AutoTextDefinition.new('ProjectName'), Layout::AutoTextDefinition.new('ClientName', 'bad text')]
    warnings = B.fill_auto_text(FakeDoc.new(defs), 'ProjectName' => 'P', 'ClientName' => '', 'ProjectNumber' => 'OPP-1')
    assert_equal 'P', defs[0].custom_text
    assert_equal 2, warnings.size
    assert_match(/ClientName.*bad text/, warnings[0])
    assert_match(/ไม่มี auto-text ProjectNumber/, warnings[1])
  end

  def test_swap_replaces_viewport
    layer = Layer.new(false)
    old = Viewport.new(false, LayerInstance.new(layer))
    doc = FakeDoc.new
    warnings = []
    B.swap(doc, Page.new('A'), old, :new_vp, 'A-1', warnings)
    assert_empty warnings
    assert_equal [[:new_vp, layer, Page.new('A')]], doc.added
    assert_equal [old], doc.removed
  end

  def test_locked_viewport_is_skipped_without_adding
    doc = FakeDoc.new
    warnings = []
    B.swap(doc, Page.new('A'), Viewport.new(true, LayerInstance.new(Layer.new(false))), :new_vp, 'A-1', warnings)
    assert_empty doc.added
    assert_match(/A-1.*lock/, warnings.first)
  end

  def test_locked_layer_is_skipped_without_adding
    doc = FakeDoc.new
    warnings = []
    B.swap(doc, Page.new('A'), Viewport.new(false, LayerInstance.new(Layer.new(true))), :new_vp, 'A-1', warnings)
    assert_empty doc.added
    assert_equal 1, warnings.size
  end

  def test_failed_remove_rolls_back_new_viewport
    old = Viewport.new(false, LayerInstance.new(Layer.new(false)))
    doc = FakeDoc.new([], fail_remove: old)
    warnings = []
    B.swap(doc, Page.new('A'), old, :new_vp, 'A-1', warnings)
    assert_equal [:new_vp], doc.removed, 'the new viewport must be taken out again — no stacked duplicate'
    assert_match(/A-1/, warnings.first)
  end
end
