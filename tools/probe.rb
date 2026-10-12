# frozen_string_literal: true

# Dev only — in SketchUp, open a saved .skp, then in Ruby Console:
#   load '<repo>/tools/probe.rb'
# Prints what LayOut sees in the template and tries one viewport swap (saved to a temp file, template untouched).
require 'tmpdir'

module SkpCm
  module LayoutGeneratorProbe
    TEMPLATE = File.expand_path('../skp_cm_layout_generator/templates/CIxCM.layout', __dir__)

    def self.walk(entities, depth, out)
      entities.each do |e|
        out << [e, depth]
        walk(e.entities, depth + 1, out) if e.is_a?(Layout::Group)
      end
      out
    end

    def self.describe(vp, depth)
      b = vp.bounds
      layer = vp.layer_instance ? vp.layer_instance.definition.name : 'nil'
      "  viewport depth=#{depth} upper_left=#{b.upper_left.to_a.map { |v| v.round(3) }} " \
        "size=#{b.width.round(3)}x#{b.height.round(3)} shared=#{vp.on_shared_layer?} layer=#{layer} " \
        "scene=#{vp.scenes[vp.current_scene].inspect} locked=#{vp.locked?}"
    end

    def self.run
      doc = Layout::Document.open(TEMPLATE)
      puts "page size: #{doc.page_info.width} x #{doc.page_info.height}"
      target = nil
      doc.pages.each do |page|
        top = page.entities.to_a
        all = walk(page.entities, 0, [])
        vps = all.select { |e, _d| e.is_a?(Layout::SketchUpModel) }
        puts "== #{page.name.inspect}: top-level #{top.size}, walked #{all.size}, " \
             "top-level viewports #{top.count { |e| e.is_a?(Layout::SketchUpModel) }}, walked viewports #{vps.size}"
        vps.each { |vp, d| puts describe(vp, d) }
        target ||= [page, vps.first[0]] unless vps.empty?
      end
      skp = Sketchup.active_model.path
      return puts('SKIP swap: save the active model first') if skp.empty? || target.nil?

      page, old = target
      fresh = Layout::SketchUpModel.new(skp, old.bounds)
      puts "new viewport scenes: #{fresh.scenes.inspect}"
      doc.add_entity(fresh, old.layer_instance.definition, page)
      doc.remove_entity(old)
      out = File.join(Dir.tmpdir, 'skp_cm_layout_probe.layout')
      doc.save(out)
      puts "swap OK on #{page.name.inspect} → #{out} (open it in LayOut and check the position)"
    rescue StandardError => e
      puts "PROBE ERROR #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    end
  end
end

SkpCm::LayoutGeneratorProbe.run
