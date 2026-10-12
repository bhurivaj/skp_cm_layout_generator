# frozen_string_literal: true

require_relative 'scene_matcher'
require_relative 'title_text'
require_relative 'page_cloner'

module SkpCm
  module LayoutGenerator
    # Everything that touches the LayOut Ruby API — runs inside SketchUp only
    module LayoutBuilder
      class SaveError < StandardError; end

      module_function

      # New project Master from the template (spec layout-master §4.1). Returns warnings.
      # values: auto-text tag => text. Raises SaveError when the output file cannot be written.
      def create(template, skp_path, output, values)
        doc = Layout::Document.open(template)
        warnings = fill_auto_text(doc, values)
        model = File.basename(skp_path, File.extname(skp_path))
        list(doc.pages).each do |page|
          olds = viewports(page.entities)
          next if olds.empty?

          template_name = page.name
          placed = new_viewports(template_name, olds, skp_path, warnings)
          placed.each { |old, viewport, label| swap(doc, page, old, viewport, label, warnings) }
          page.name = TitleText.page_name(model, template_name)
          fill_titles(page, placed.map(&:last), warnings)
        end
        save(doc, output)
        warnings
      end

      # Adds this model's pages to the end of an existing Master (spec layout-master §4.2).
      # Auto-text of the Master is left alone. Returns warnings; raises SaveError.
      def append(template, skp_path, master_path)
        source = Layout::Document.open(template)
        doc = Layout::Document.open(master_path)
        model = File.basename(skp_path, File.extname(skp_path))
        warnings = []
        list(source.pages).each do |template_page|
          olds = viewports(template_page.entities)
          next if olds.empty?

          page = doc.pages.add(TitleText.page_name(model, template_page.name))
          warnings.concat(PageCloner.copy_page(template_page, doc, page))
          placed = new_viewports(template_page.name, olds, skp_path, warnings)
          placed.each { |old, viewport, label| place(doc, page, old, viewport, label, warnings) }
          fill_titles(page, placed.map(&:last), warnings)
        end
        save(doc, master_path)
        warnings
      end

      def page_names(path)
        list(Layout::Document.open(path).pages).map(&:name)
      end

      # Template pages that hold a viewport ("model pages")
      def model_page_names(template)
        list(Layout::Document.open(template).pages).reject { |page| viewports(page.entities).empty? }.map(&:name)
      end

      # One new viewport per template viewport, scene picked by name. => [[old, new, label], ...] in reading order
      def new_viewports(page_name, olds, skp_path, warnings)
        fresh = olds.map { |old| Layout::SketchUpModel.new(skp_path, old.bounds) }
        scenes = fresh.first.scenes
        positions = olds.map do |old|
          corner = old.bounds.upper_left
          [corner.x, corner.y, corner.y + old.bounds.height]
        end
        SceneMatcher.match(page_name, positions, scenes).map do |m|
          viewport = fresh[m['viewport']]
          if m['scene_index']
            viewport.current_scene = m['scene_index']
            label = scenes[m['scene_index']]
          else
            viewport.current_scene = 0
            label = m['scene_name']
            warnings << "ไม่พบ scene #{m['scene_name']} (หน้า #{page_name}) — ใช้มุมมองล่าสุดแทน"
          end
          [olds[m['viewport']], viewport, label]
        end
      end

      # Line 2 of the page title: scene labels under <PageName>, A, B … under <PageNumber>
      def fill_titles(page, labels, warnings)
        texts = entities_of(page.nonshared_entities, Layout::FormattedText)
        { '<PageName>' => labels.join(', '),
          '<PageNumber>' => TitleText.sequence_letters(labels.size).join(', ') }.each do |tag, value|
          text = texts.find { |t| t.plain_text.to_s.include?(tag) }
          next warnings << "หน้า #{page.name} ไม่มีข้อความ #{tag}" unless text

          begin
            style = text.style
            text.plain_text = TitleText.with_line2(text.plain_text, value)
            text.apply_style(style) if style
          rescue StandardError => e
            warnings << "ใส่บรรทัด 2 ของ #{tag} (หน้า #{page.name}) ไม่ได้: #{e.message}"
          end
        end
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

      # Appending: the template viewport stays in the template; the new one goes on the same-named layer
      def place(doc, page, old, viewport, scene_name, warnings)
        layer = PageCloner.layer_for(doc, old)
        raise 'ไม่มี layer ให้วาง viewport' unless layer

        doc.add_entity(viewport, layer, page)
      rescue StandardError => e
        warnings << "วาง viewport #{scene_name} (หน้า #{page.name}) ไม่ได้: #{e.message}"
      end

      def save(doc, path)
        doc.save(path)
      rescue StandardError => e
        raise SaveError, e.message
      end

      # SketchUp viewports on a page, including ones inside groups; skips shared (master) layers
      def viewports(entities)
        entities_of(entities, Layout::SketchUpModel).reject(&:on_shared_layer?)
      end

      def entities_of(entities, klass, found = [])
        entities.each do |e|
          if e.is_a?(klass)
            found << e unless found.include?(e)
          elsif e.is_a?(Layout::Group)
            entities_of(e.entities, klass, found)
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
