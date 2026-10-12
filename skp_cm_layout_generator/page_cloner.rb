# frozen_string_literal: true

module SkpCm
  module LayoutGenerator
    # Re-creates page content in another LayOut document — the LayOut API cannot copy entities
    # between documents. Text (via RTF), paths and groups are supported; anything else is skipped
    # with a warning. Viewports are skipped silently (LayoutBuilder places new ones).
    module PageCloner
      module_function

      # Copies the non-shared, non-viewport entities of from_page onto to_page of doc. Returns warnings.
      def copy_page(from_page, doc, to_page)
        warnings = []
        top_level(list(from_page.nonshared_entities)).each do |entity|
          next if entity.is_a?(Layout::SketchUpModel)

          begin
            copy = clone(entity, warnings, from_page.name)
            next unless copy

            layer = layer_for(doc, entity)
            wanted = layer_name(entity)
            unless layer
              warnings << "ไม่มี layer ให้ใส่ #{kind(entity)} ในหน้า #{from_page.name}"
              next
            end
            warnings << "ไม่พบ layer #{wanted} — ใช้ layer #{layer.name} แทน (หน้า #{from_page.name})" if layer.name != wanted
            doc.add_entity(copy, layer, to_page)
          rescue StandardError => e
            warnings << "copy #{kind(entity)} ในหน้า #{from_page.name} ไม่ได้: #{e.message}"
          end
        end
        warnings
      end

      # Shows/hides each layer of to_page like the same-named layer on from_page (template). Returns warnings.
      def copy_layer_visibility(from_page, from_doc, to_page, doc)
        sources = list(from_doc.layers)
        list(doc.layers).each_with_object([]) do |layer, warnings|
          source = sources.find { |l| l.name == layer.name }
          next unless source

          visible = from_page.layer_visible?(source)
          to_page.set_layer_visibility(layer, visible) if to_page.layer_visible?(layer) != visible
        rescue StandardError => e
          warnings << "ตั้งการแสดง layer #{layer.name} ในหน้า #{to_page.name} ไม่ได้: #{e.message}"
        end
      end

      # Layer with the same name in doc; otherwise the first layer that is neither shared nor locked
      def layer_for(doc, entity)
        layers = list(doc.layers)
        wanted = layer_name(entity)
        layers.find { |l| l.name == wanted } ||
          layers.find { |l| !(l.respond_to?(:shared?) && l.shared?) && !(l.respond_to?(:locked?) && l.locked?) }
      end

      # [[:move, p], [:line, p], [:bezier, c1, c2, p], [:close]] — nil when the path has parts we cannot rebuild.
      # Arcs and circles come as bezier segments plus an arc-centre point, which is skipped.
      def path_segments(points, types)
        segments = []
        i = 0
        while i < points.size
          case types[i]
          when Layout::Path::POINT_TYPE_MOVE_TO then segments << [:move, points[i]]
          when Layout::Path::POINT_TYPE_LINE_TO then segments << [:line, points[i]]
          when Layout::Path::POINT_TYPE_CLOSE then segments << [:close]
          when Layout::Path::POINT_TYPE_ARC_CENTER then nil # reference point of an arc/circle, not drawn
          when Layout::Path::POINT_TYPE_BEZIER_TO then segments << [:line, points[i]] # end point with no controls
          when Layout::Path::POINT_TYPE_BEZIER_CONTROL
            return nil unless types[i + 1] == Layout::Path::POINT_TYPE_BEZIER_CONTROL &&
                              types[i + 2] == Layout::Path::POINT_TYPE_BEZIER_TO

            segments << [:bezier, points[i], points[i + 1], points[i + 2]]
            i += 2
          else
            return nil
          end
          i += 1
        end
        segments.size > 1 && segments.first[0] == :move ? segments : nil
      end

      def clone(entity, warnings, page_name)
        copy =
          if entity.is_a?(Layout::FormattedText) then copy_text(entity)
          elsif entity.is_a?(Layout::Path) then copy_path(entity)
          elsif entity.is_a?(Layout::Group) then copy_group(entity, warnings, page_name)
          end
        unless copy
          warnings << "ข้าม #{kind(entity)} ในหน้า #{page_name} (copy ไม่ได้)"
          return nil
        end
        copy_style(entity, copy)
        copy
      end

      def copy_text(text)
        copy = Layout::FormattedText.new('x', source_bounds(text))
        copy.rtf = text.rtf
        transform(copy, text)
        copy
      end

      def copy_path(path)
        return copy_ellipse(path) if full_ellipse?(path)

        segments = path_segments(path.points, path.point_types)
        return nil unless segments

        copy = build_path(segments)
        return nil unless copy

        copy.close if path.closed? && !copy.closed?
        transform(copy, path)
        copy
      end

      # A whole circle/ellipse: move, arc centre, 4 bezier quarters (+ end point), closed.
      # Rebuilding it from the beziers distorted it in LayOut (probe 2026-10-12), so use its bounds.
      def full_ellipse?(path)
        types = path.point_types
        quarter = [Layout::Path::POINT_TYPE_BEZIER_CONTROL, Layout::Path::POINT_TYPE_BEZIER_CONTROL,
                   Layout::Path::POINT_TYPE_BEZIER_TO]
        body = [Layout::Path::POINT_TYPE_MOVE_TO, Layout::Path::POINT_TYPE_ARC_CENTER] + quarter * 4
        path.closed? && (types == body || types == body + [Layout::Path::POINT_TYPE_BEZIER_TO])
      end

      def copy_ellipse(path)
        copy = Layout::Ellipse.new(source_bounds(path))
        transform(copy, path)
        copy
      end

      def build_path(segments)
        start = segments.first[1]
        path = nil
        segments.drop(1).each do |kind, *pts|
          case kind
          when :line then path ? path.append_point(pts[0]) : (path = Layout::Path.new(start, pts[0]))
          when :bezier then path ? path.append_point(*pts) : (path = Layout::Path.new(start, *pts))
          when :close then path.close if path
          when :move then return nil # several sub-paths: not supported
          end
        end
        path
      end

      # Bounds before the explicit transformation; LayOut raises for untransformed_bounds when there is none
      def source_bounds(entity)
        entity.transformation ? entity.untransformed_bounds : entity.bounds
      end

      # Entities that were never moved/rotated have no explicit transformation (nil)
      def transform(copy, original)
        transformation = original.transformation
        copy.transform!(transformation) if transformation
      end

      def copy_group(group, warnings, page_name)
        children = list(group.entities).select { |c| !c.respond_to?(:group) || c.group.nil? || c.group == group }
        copies = children.reject { |c| c.is_a?(Layout::SketchUpModel) }.map do |child|
          clone(child, warnings, page_name)
        rescue StandardError => e
          warnings << "copy #{kind(child)} ในหน้า #{page_name} ไม่ได้: #{e.message}" # keep the rest of the group
          nil
        end.compact
        copies.empty? ? nil : Layout::Group.new(copies)
      end

      def copy_style(from, to)
        style = from.style
        to.style = style if style
      rescue StandardError
        nil # keep LayOut's default style rather than fail the copy
      end

      # Outermost group of each entity, once — works whether the API lists groups, their children, or both
      def top_level(entities)
        entities.each_with_object([]) do |entity, tops|
          top = entity
          top = top.group while top.respond_to?(:group) && top.group
          tops << top unless tops.include?(top)
        end
      end

      def layer_name(entity)
        leaf = entity
        leaf = list(leaf.entities).first while leaf.is_a?(Layout::Group) && !list(leaf.entities).empty?
        instance = leaf.layer_instance
        instance ? instance.definition.name : nil
      end

      def kind(entity)
        entity.class.name.split('::').last
      end

      def list(collection)
        items = []
        collection.each { |item| items << item }
        items
      end
    end
  end
end
