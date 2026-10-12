# frozen_string_literal: true

module SkpCm
  module LayoutGenerator
    # Page names and the second line of the page title — plain Ruby, no LayOut API
    module TitleText
      module_function

      def page_name(model, template_page)
        "#{model} - #{template_page}"
      end

      # True when the Master already has any page of this model (full names, so tent1 ≠ tent10)
      def model_present?(page_names, model, template_pages)
        template_pages.any? { |page| page_names.include?(page_name(model, page)) }
      end

      # A, B … Z, AA, AB … (spreadsheet columns)
      def sequence_letters(count)
        (1..count).map do |n|
          letters = +''
          while n.positive?
            n -= 1
            letters.prepend((65 + n % 26).chr)
            n /= 26
          end
          letters
        end
      end

      # Keeps the first line (it holds the auto-text) and puts value on line 2
      def with_line2(plain_text, value)
        first = plain_text.to_s.split(/\r\n|\r|\n/, 2).first.to_s
        "#{first}\n#{value}"
      end
    end
  end
end
