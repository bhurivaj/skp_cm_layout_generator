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

  class FormattedText
    attr_accessor :plain_text, :fail_with
    attr_reader :applied

    def initialize(plain_text)
      @plain_text = plain_text
    end

    def style
      :line1_style
    end

    def plain_text=(text)
      raise ArgumentError, fail_with if fail_with

      @plain_text = text
    end

    def apply_style(style)
      @applied = style
    end
  end

  class SketchUpModel; end
  class Group
    attr_reader :entities

    def initialize(entities = [])
      @entities = entities
    end
  end
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
  TitlePage = Struct.new(:name, :nonshared_entities)

  def test_fill_titles_sets_line_2_with_first_line_style
    name = Layout::FormattedText.new("<PageName>\n")
    number = Layout::FormattedText.new('<PageNumber>')
    other = Layout::FormattedText.new('Note')
    warnings = []
    B.fill_titles(TitlePage.new('tent1 - A', [other, Layout::Group.new([name, number])]), %w[A-01 A-02], warnings)
    assert_empty warnings
    assert_equal ["<PageName>\nA-01, A-02", :line1_style], [name.plain_text, name.applied]
    assert_equal "<PageNumber>\nA, B", number.plain_text
    assert_equal 'Note', other.plain_text
  end

  def test_fill_titles_missing_or_locked_text_warns
    number = Layout::FormattedText.new('<PageNumber>')
    number.fail_with = 'locked'
    warnings = []
    B.fill_titles(TitlePage.new('tent1 - A', [number]), %w[A], warnings)
    assert_equal 2, warnings.size
    assert_match(/tent1 - A.*<PageName>/, warnings[0])
    assert_match(/<PageNumber>.*locked/, warnings[1])
  end
end
