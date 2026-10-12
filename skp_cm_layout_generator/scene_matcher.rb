# frozen_string_literal: true

module SkpCm
  module LayoutGenerator
    # Which scene each viewport on a LayOut page should show — plain Ruby, no LayOut API.
    # One viewport: scene = page name. Several: "<page>-1", "<page>-2" … in reading order.
    module SceneMatcher
      # Left edges closer than this (paper inches) count as the same column
      TOLERANCE = 0.01

      module_function

      def match(page_name, positions, scenes)
        order = reading_order(positions)
        order.each_with_index.map do |viewport, n|
          name = order.size == 1 ? page_name : "#{page_name}-#{n + 1}"
          { 'viewport' => viewport, 'scene_name' => name, 'scene_index' => scenes.index(name) }
        end
      end

      # Indexes into positions: left to right, then top to bottom (y grows downward)
      def reading_order(positions)
        (0...positions.size).to_a.sort do |a, b|
          (ax, ay), (bx, by) = positions[a], positions[b]
          by_x = (ax - bx).abs < TOLERANCE ? 0 : ax <=> bx
          by_x.nonzero? || (ay <=> by).nonzero? || a <=> b
        end
      end
    end
  end
end
