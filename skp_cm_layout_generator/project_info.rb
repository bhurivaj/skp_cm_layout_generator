# frozen_string_literal: true

module SkpCm
  module LayoutGenerator
    # Project data from the .skp path and the Odoo lead — plain Ruby, no SketchUp API
    module ProjectInfo
      OPP_PATTERN = /OPP-\d{11}(?!\d)/.freeze

      module_function

      # OPP number of the deepest folder that has one (folders only, not the file name)
      def opp_from_path(path)
        dirs = path.to_s.split(%r{[/\\]})[0...-1] || []
        dirs.reverse_each do |dir|
          found = dir[OPP_PATTERN]
          return found if found
        end
        nil
      end

      def output_path(skp_path)
        File.join(File.dirname(skp_path), File.basename(skp_path, File.extname(skp_path)) + '.layout')
      end

      # record: one crm.lead from search_read ('name', 'partner_id' = [id, name] or false)
      def lead_values(opp, record)
        name = record['name'].is_a?(String) ? record['name'] : ''
        partner = record['partner_id']
        client = partner.is_a?(Array) && partner[1].is_a?(String) ? partner[1] : ''
        warnings = []
        warnings << "#{opp} ไม่มีชื่อโครงการใน Odoo" if name.strip.empty?
        warnings << "#{opp} ไม่มีลูกค้าใน Odoo" if client.strip.empty?
        [{ 'ProjectName' => name, 'ClientName' => client, 'ProjectNumber' => opp }, warnings]
      end

      def summary(output, warnings)
        text = "สร้าง LayOut แล้ว:\n#{output}"
        return text if warnings.empty?

        "#{text}\n\nคำเตือน:\n#{warnings.map { |w| "- #{w}" }.join("\n")}"
      end
    end
  end
end
