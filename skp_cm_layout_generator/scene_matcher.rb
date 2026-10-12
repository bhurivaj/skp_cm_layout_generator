# frozen_string_literal: true

module SkpCm
  module LayoutGenerator
    # Which scene each viewport on a LayOut page should show — plain Ruby, no LayOut API.
    # One viewport: scene = page name. Several: "<page>-1", "<page>-2" … in reading order
    # (zero-padded scene names such as "A-01" count as the same number).
    module SceneMatcher
      module_function

      # positions: [[left, top, bottom], ...] one per viewport (paper inches, y grows downward)
      # scenes: Layout::SketchUpModel#scenes (index 0 = "Last saved SketchUp View")
      def match(page_name, positions, scenes)
        order = reading_order(positions)
        order.each_with_index.map do |viewport, n|
          if order.size == 1
            name = page_name
            index = scenes.index(name)
          else
            name = "#{page_name}-#{n + 1}"
            pattern = /\A#{Regexp.escape(page_name)}-0*#{n + 1}\z/
            index = scenes.index { |scene| scene.match?(pattern) }
          end
          { 'viewport' => viewport, 'scene_name' => name, 'scene_index' => index }
        end
      end

      # Indexes into positions: top to bottom; viewports whose heights overlap form a row, read left to right
      def reading_order(positions)
        rows = []
        (0...positions.size).sort_by { |i| [positions[i][1], positions[i][0]] }.each do |i|
          _left, top, bottom = positions[i]
          row = rows.last
          if row && top < row[:bottom]
            row[:items] << i
            row[:bottom] = [row[:bottom], bottom].max
          else
            rows << { items: [i], bottom: bottom }
          end
        end
        rows.flat_map { |row| row[:items].sort_by { |i| positions[i][0] } }
      end
    end
  end
end
