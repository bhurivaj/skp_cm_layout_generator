# frozen_string_literal: true

require_relative 'scene_matcher'

module SkpCm
  module LayoutGenerator
    # Everything that touches the LayOut Ruby API — runs inside SketchUp only
    module LayoutBuilder
      class SaveError < StandardError; end

      module_function

      # values: { 'ProjectName' => …, 'ClientName' => …, 'ProjectNumber' => … }
      # Returns warnings. Raises SaveError when the output file cannot be written.
      def build(template, skp_path, output, values)
        doc = Layout::Document.open(template)
        warnings = fill_auto_text(doc, values)
        doc.pages.each { |page| warnings.concat(replace_viewports(doc, page, skp_path)) }
        begin
          doc.save(output)
        rescue StandardError => e
          raise SaveError, e.message
        end
        warnings
      end

      def fill_auto_text(doc, values)
        definitions = list(doc.auto_text_definitions)
        values.each_with_object([]) do |(tag, text), warnings|
          definition = definitions.find do |d|
            d.name == tag && d.type == Layout::AutoTextDefinition::TYPE_CUSTOM_TEXT
          end
          unless definition
            warnings << "template ไม่มี auto-text #{tag}"
            next
          end
          begin
            definition.custom_text = text
          rescue StandardError => e
            warnings << "ตั้ง auto-text #{tag} ไม่ได้: #{e.message}"
          end
        end
      end

      def replace_viewports(doc, page, skp_path)
        olds = viewports(page.entities)
        return [] if olds.empty?

        fresh = olds.map { |old| Layout::SketchUpModel.new(skp_path, old.bounds) }
        positions = olds.map do |old|
          corner = old.bounds.upper_left
          [corner.x, corner.y, corner.y + old.bounds.height]
        end
        SceneMatcher.match(page.name, positions, fresh.first.scenes).each_with_object([]) do |m, warnings|
          viewport = fresh[m['viewport']]
          if m['scene_index']
            viewport.current_scene = m['scene_index']
          else
            viewport.current_scene = 0
            warnings << "ไม่พบ scene #{m['scene_name']} (หน้า #{page.name}) — ใช้มุมมองล่าสุดแทน"
          end
          swap(doc, page, olds[m['viewport']], viewport, m['scene_name'], warnings)
        end
      end

      # New viewport goes on the old one's layer and page, then the old one is removed
      def swap(doc, page, old, viewport, scene_name, warnings)
        layer = old.layer_instance && old.layer_instance.definition
        raise 'ไม่พบ layer ของ viewport เดิม' unless layer
        raise 'viewport เดิมถูก lock' if old.locked?
        raise "layer #{layer.respond_to?(:name) ? layer.name : ''} ถูก lock" if layer.respond_to?(:locked?) && layer.locked?

        doc.add_entity(viewport, layer, page)
        begin
          doc.remove_entity(old)
        rescue StandardError
          doc.remove_entity(viewport) # never leave the new viewport stacked on the old one
          raise
        end
      rescue StandardError => e
        warnings << "แทน viewport #{scene_name} (หน้า #{page.name}) ไม่ได้: #{e.message}"
      end

      # SketchUp viewports on a page, including ones inside groups; skips shared (master) layers
      def viewports(entities, found = [])
        entities.each do |e|
          if e.is_a?(Layout::SketchUpModel)
            found << e unless e.on_shared_layer? || found.include?(e)
          elsif e.is_a?(Layout::Group)
            viewports(e.entities, found)
          end
        end
        found
      end

      # Copies a LayOut collection into an Array (never edit a collection while iterating it)
      def list(collection)
        items = []
        collection.each { |item| items << item }
        items
      end
    end
  end
end
