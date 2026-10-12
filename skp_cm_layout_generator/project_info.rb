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

      # project: from HubLink.fetch_project — 'lead' (crm.lead with 'name', 'partner_id' = [id, name] or false),
      # 'contact_address', 'user_name', 'warnings'
      def lead_values(opp, project)
        lead = project['lead']
        name = lead['name'].is_a?(String) ? lead['name'] : ''
        partner = lead['partner_id']
        client = partner.is_a?(Array) && partner[1].is_a?(String) ? partner[1] : ''
        warnings = []
        warnings << "#{opp} ไม่มีชื่อโครงการใน Odoo" if name.strip.empty?
        warnings << "#{opp} ไม่มีลูกค้าใน Odoo" if client.strip.empty?
        values = { 'ProjectName' => name, 'ClientName' => client, 'ProjectNumber' => opp,
                   'ClientAddress' => address_text(project['contact_address'], client),
                   'DrawnBy' => project['user_name'].to_s }
        [values, warnings + Array(project['warnings'])]
      end

      # Odoo contact_address without its first line when that line is just the client name
      def address_text(contact_address, client)
        lines = (contact_address.is_a?(String) ? contact_address : '').lines.map(&:strip).reject(&:empty?)
        lines.shift if lines.first == client.to_s.strip
        lines.join("\n")
      end

      def summary(output, warnings)
        text = "สร้าง LayOut แล้ว:\n#{output}"
        return text if warnings.empty?

        "#{text}\n\nคำเตือน:\n#{warnings.map { |w| "- #{w}" }.join("\n")}"
      end
    end
  end
end
