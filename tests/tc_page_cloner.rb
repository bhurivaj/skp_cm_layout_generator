# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_page_cloner.rb
require 'minitest/autorun'

# Stand-ins for the LayOut classes page_cloner.rb uses
module Layout
  class Entity
    attr_accessor :group, :layer_instance, :style, :boom
    attr_reader :transforms

    def transformation
      :tr
    end

    # Real LayOut raises when the entity was never moved/rotated (probe 2026-10-12)
    def untransformed_bounds
      raise ArgumentError, 'The entity does not have an explicit transform' if transformation.nil?

      :ub
    end

    def bounds
      :b
    end

    def transform!(transformation)
      (@transforms ||= []) << transformation
    end
  end

  class FormattedText < Entity
    attr_accessor :rtf
    attr_reader :bounds_arg

    def initialize(_text = 'x', bounds = nil)
      @bounds_arg = bounds
    end
  end

  class Path < Entity
    POINT_TYPE_MOVE_TO = 0
    POINT_TYPE_LINE_TO = 1
    POINT_TYPE_BEZIER_TO = 2
    POINT_TYPE_ARC_CENTER = 3
    POINT_TYPE_BEZIER_CONTROL = 4
    POINT_TYPE_CLOSE = 5
    attr_accessor :points, :point_types
    attr_reader :built, :closed
    attr_accessor :closed_flag

    def closed?
      closed_flag ? true : false
    end

    def initialize(*points)
      @built = [points]
    end

    def append_point(*points)
      @built << points
    end

    def close
      @closed = true
    end
  end

  class Group < Entity
    attr_reader :entities

    def initialize(entities = [])
      @entities = entities
    end
  end

  class Ellipse < Entity
    attr_reader :bounds_arg

    def initialize(bounds)
      @bounds_arg = bounds
    end
  end

  class SketchUpModel < Entity; end
  class Image < Entity; end
end

require_relative '../skp_cm_layout_generator/page_cloner'

class TestPageCloner < Minitest::Test
  C = SkpCm::LayoutGenerator::PageCloner
  P = Layout::Path
  Layer = Struct.new(:name, :shared_flag, :locked_flag) do
    def shared?
      shared_flag
    end

    def locked?
      locked_flag
    end
  end
  LayerInstance = Struct.new(:definition)
  Page = Struct.new(:name, :nonshared_entities)

  class Doc
    attr_reader :layers, :added

    def initialize(layers)
      @layers = layers
      @added = []
    end

    def add_entity(entity, layer, page)
      raise ArgumentError, 'boom' if entity.respond_to?(:boom) && entity.boom

      @added << [entity, layer, page]
    end
  end

  def on(entity, layer_name)
    entity.layer_instance = LayerInstance.new(Layer.new(layer_name, false, false))
    entity
  end

  def text(rtf, layer = 'Layout')
    t = on(Layout::FormattedText.new, layer)
    t.rtf = rtf
    t.style = :text_style
    t
  end

  def line(layer = 'Layout')
    p = on(P.new, layer)
    p.points = %i[a b]
    p.point_types = [P::POINT_TYPE_MOVE_TO, P::POINT_TYPE_LINE_TO]
    p
  end

  def master
    Doc.new([Layer.new('Shared', true, false), Layer.new('Layout', false, false)])
  end

  def test_path_segments
    assert_equal [[:move, :a], [:line, :b], [:line, :c], [:close]],
                 C.path_segments(%i[a b c d], [P::POINT_TYPE_MOVE_TO, P::POINT_TYPE_LINE_TO, P::POINT_TYPE_LINE_TO,
                                               P::POINT_TYPE_CLOSE])
    assert_equal [[:move, :a], [:bezier, :c1, :c2, :b]],
                 C.path_segments(%i[a c1 c2 b], [P::POINT_TYPE_MOVE_TO, P::POINT_TYPE_BEZIER_CONTROL,
                                                 P::POINT_TYPE_BEZIER_CONTROL, P::POINT_TYPE_BEZIER_TO])
    assert_nil C.path_segments(%i[a b], [P::POINT_TYPE_MOVE_TO, P::POINT_TYPE_ARC_CENTER])
    assert_nil C.path_segments(%i[a], [P::POINT_TYPE_MOVE_TO])
  end

  def test_copies_text_and_path_onto_layer_with_same_name
    src = [text('{\rtf1 <PageName>}'), line]
    doc = master
    warnings = C.copy_page(Page.new('A', src), doc, :new_page)
    assert_empty warnings
    copy_text, layer, page = doc.added[0]
    assert_equal ['{\rtf1 <PageName>}', :ub, [:tr], :text_style], [copy_text.rtf, copy_text.bounds_arg,
                                                                     copy_text.transforms, copy_text.style]
    assert_equal ['Layout', :new_page], [layer.name, page]
    assert_equal [%i[a b]], doc.added[1][0].built
  end

  def test_closed_path_is_closed
    p = line
    p.points = %i[a b c d]
    p.point_types = [P::POINT_TYPE_MOVE_TO, P::POINT_TYPE_LINE_TO, P::POINT_TYPE_LINE_TO, P::POINT_TYPE_CLOSE]
    doc = master
    C.copy_page(Page.new('A', [p]), doc, :pg)
    copy = doc.added[0][0]
    assert_equal [%i[a b], [:c]], copy.built
    assert copy.closed
  end

  def test_viewport_skipped_silently_image_with_warning
    doc = master
    warnings = C.copy_page(Page.new('A', [on(Layout::SketchUpModel.new, 'Layout'), on(Layout::Image.new, 'Layout')]),
                           doc, :pg)
    assert_empty doc.added
    assert_equal 1, warnings.size
    assert_match(/Image.*หน้า A/, warnings.first)
  end

  def test_group_copied_once_even_when_children_are_listed
    child1 = text('t1')
    child2 = line
    group = Layout::Group.new([child1, child2])
    [child1, child2].each { |c| c.group = group }
    doc = master
    warnings = C.copy_page(Page.new('A', [child1, child2, group]), doc, :pg)
    assert_empty warnings
    assert_equal 1, doc.added.size
    copy = doc.added[0][0]
    assert_kind_of Layout::Group, copy
    assert_equal 2, copy.entities.size
    assert_equal 'Layout', doc.added[0][1].name, 'group goes on the layer of its first child'
  end

  def test_one_failure_does_not_stop_the_rest
    bad = text('bad')
    doc = master
    doc.define_singleton_method(:add_entity) do |entity, layer, page|
      raise ArgumentError, 'locked layer' if entity.rtf == 'bad'

      added << [entity, layer, page]
    end
    warnings = C.copy_page(Page.new('A', [bad, text('good')]), doc, :pg)
    assert_equal ['good'], doc.added.map { |e, _l, _p| e.rtf }
    assert_match(/หน้า A.*locked layer/, warnings.first)
  end

  # Circle as LayOut stores it (probe of the template title group): move, arc centre, 4 beziers, end point
  CIRCLE_TYPES = [0, 3, 4, 4, 2, 4, 4, 2, 4, 4, 2, 4, 4, 2, 2].freeze

  def test_path_segments_circle_skips_arc_centre
    points = %i[p0 c a1 a2 p1 b1 b2 p2 c1 c2 p3 d1 d2 p4 p5]
    assert_equal [[:move, :p0], [:bezier, :a1, :a2, :p1], [:bezier, :b1, :b2, :p2], [:bezier, :c1, :c2, :p3],
                  [:bezier, :d1, :d2, :p4], [:line, :p5]], C.path_segments(points, CIRCLE_TYPES)
  end

  def test_full_circle_is_rebuilt_as_ellipse_from_its_bounds
    p = line
    p.points = %i[p0 c a1 a2 p1 b1 b2 p2 c1 c2 p3 d1 d2 p4 p5]
    p.point_types = CIRCLE_TYPES
    p.closed_flag = true
    doc = master
    assert_empty C.copy_page(Page.new('A', [p]), doc, :pg)
    copy = doc.added[0][0]
    assert_kind_of Layout::Ellipse, copy, 'bezier rebuild distorted the circle in real LayOut'
    assert_equal [:ub, [:tr]], [copy.bounds_arg, copy.transforms]
  end

  def test_circle_without_transformation_uses_bounds
    p = line
    p.points = %i[p0 c a1 a2 p1 b1 b2 p2 c1 c2 p3 d1 d2 p4 p5]
    p.point_types = CIRCLE_TYPES
    p.closed_flag = true
    p.define_singleton_method(:transformation) { nil }
    doc = master
    assert_empty C.copy_page(Page.new('A', [p]), doc, :pg)
    assert_equal [:b, nil], [doc.added[0][0].bounds_arg, doc.added[0][0].transforms]
  end

  def test_text_without_transformation_uses_bounds
    t = text('t')
    t.define_singleton_method(:transformation) { nil }
    doc = master
    assert_empty C.copy_page(Page.new('A', [t]), doc, :pg)
    assert_equal :b, doc.added[0][0].bounds_arg
  end

  def test_closed_path_without_close_point_is_closed
    p = line
    p.points = %i[a b c]
    p.point_types = [P::POINT_TYPE_MOVE_TO, P::POINT_TYPE_LINE_TO, P::POINT_TYPE_LINE_TO]
    p.closed_flag = true
    doc = master
    C.copy_page(Page.new('A', [p]), doc, :pg)
    assert doc.added[0][0].closed
  end

  def test_entities_without_transformation_are_copied_as_is
    p = line
    t = text('t')
    [p, t].each { |e| e.define_singleton_method(:transformation) { nil } }
    doc = master
    warnings = C.copy_page(Page.new('A', [Layout::Group.new([p, t])]), doc, :pg)
    assert_empty warnings
    copies = doc.added[0][0].entities
    assert_equal [nil, nil], copies.map(&:transforms), 'transform! must not be called with nil'
  end

  def test_missing_layer_falls_back_to_first_usable_layer_with_warning
    doc = master
    warnings = C.copy_page(Page.new('A', [text('t', 'Gone')]), doc, :pg)
    assert_equal 'Layout', doc.added[0][1].name
    assert_match(/Gone/, warnings.first)
  end

  def test_one_failing_child_keeps_the_rest_of_the_group
    bad = text('bad')
    bad.define_singleton_method(:rtf) { raise ArgumentError, 'broken rtf' }
    good = text('<PageName>')
    group = Layout::Group.new([bad, good])
    doc = master
    warnings = C.copy_page(Page.new('A', [group]), doc, :pg)
    assert_equal 1, doc.added.size, 'the title group must still be copied'
    assert_equal ['<PageName>'], doc.added[0][0].entities.map(&:rtf)
    assert_match(/FormattedText.*หน้า A.*broken rtf/, warnings.first)
  end
end
