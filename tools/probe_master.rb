# frozen_string_literal: true

# Dev only — in SketchUp, open a saved .skp, then in Ruby Console:
#   load '<repo>/tools/probe_master.rb'
# Copies the last template page that has a viewport into a second copy of the template, fills title line 2,
# adds the active model, saves to a temp file. The template itself is never saved.
require 'tmpdir'
# load (not require) so a second run in the same SketchUp session picks up edited files
load File.expand_path('../skp_cm_layout_generator/title_text.rb', __dir__)
load File.expand_path('../skp_cm_layout_generator/page_cloner.rb', __dir__)

module SkpCm
  module LayoutMasterProbe
    remove_const(:TEMPLATE) if const_defined?(:TEMPLATE, false)
    remove_const(:C) if const_defined?(:C, false)
    TEMPLATE = File.expand_path('../skp_cm_layout_generator/templates/CIxCM.layout', __dir__)
    C = SkpCm::LayoutGenerator::PageCloner

    def self.show(entity)
      b = entity.bounds
      text = entity.is_a?(Layout::FormattedText) ? " text=#{entity.plain_text.inspect}" : ''
      if entity.is_a?(Layout::Path)
        text = " class=#{entity.class.name} types=#{entity.point_types.inspect} closed=#{entity.closed?} " \
               "tr=#{entity.transformation.inspect} segs=#{C.path_segments(entity.points, entity.point_types) ? 'ok' : 'NIL'}"
      end
      layer = entity.layer_instance ? entity.layer_instance.definition.name : 'nil'
      group = entity.respond_to?(:group) && entity.group ? 'yes' : 'no'
      "  #{C.kind(entity)} in_group=#{group} layer=#{layer} ul=#{b.upper_left.to_a.map { |v| v.round(3) }} " \
        "size=#{b.width.round(3)}x#{b.height.round(3)}#{text}"
    end

    def self.texts(entities, found = [])
      C.list(entities).each do |e|
        found << e if e.is_a?(Layout::FormattedText)
        texts(e.entities, found) if e.is_a?(Layout::Group)
      end
      found
    end

    def self.run
      src = Layout::Document.open(TEMPLATE)
      dst = Layout::Document.open(TEMPLATE)
      tpage = C.list(src.pages).reverse.find { |p| C.list(p.entities).any? { |e| e.is_a?(Layout::SketchUpModel) } }
      puts "== template page #{tpage.name.inspect} nonshared:"
      C.list(tpage.nonshared_entities).each { |e| puts show(e) }
      C.list(tpage.nonshared_entities).select { |e| e.is_a?(Layout::Group) }.each do |g|
        C.list(g.entities).each { |e| puts "    child:#{show(e)}" }
      end
      texts(tpage.nonshared_entities).each { |e| puts "  text in page/group: #{e.plain_text.inspect}" }
      page = dst.pages.add("probe - #{tpage.name}")
      puts "copy warnings: #{C.copy_page(tpage, dst, page).inspect}"
      puts '== copied page nonshared:'
      C.list(page.nonshared_entities).each { |e| puts show(e) }
      texts(page.nonshared_entities).each { |e| puts "  copied text: #{e.plain_text.inspect}" }
      [['<PageName>', 'A-01, A-02'], ['<PageNumber>', 'A, B']].each do |tag, value|
        text = texts(page.nonshared_entities).find { |e| e.plain_text.include?(tag) }
        next puts("NO TEXT #{tag}") unless text

        style = text.style
        text.plain_text = SkpCm::LayoutGenerator::TitleText.with_line2(text.plain_text, value)
        text.apply_style(style)
        puts "#{tag}: plain=#{text.plain_text.inspect} display=#{text.display_text(page).inspect}"
      end
      skp = Sketchup.active_model.path
      unless skp.empty?
        C.list(tpage.entities).select { |e| e.is_a?(Layout::SketchUpModel) }.each do |old|
          dst.add_entity(Layout::SketchUpModel.new(skp, old.bounds), C.layer_for(dst, old), page)
        end
      end
      out = File.join(Dir.tmpdir, 'skp_cm_layout_master_probe.layout')
      dst.save(out)
      puts "saved → #{out} — open it, compare page #{page.name.inspect} with #{tpage.name.inspect}"
    rescue StandardError => e
      puts "PROBE ERROR #{e.class}: #{e.message}\n#{e.backtrace.first(6).join("\n")}"
    end
  end
end

SkpCm::LayoutMasterProbe.run
