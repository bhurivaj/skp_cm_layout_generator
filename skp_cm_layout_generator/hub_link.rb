# frozen_string_literal: true

module SkpCm
  module LayoutGenerator
    # The only place that knows SKP CM Extensions Hub. Looked up at call time:
    # SketchUp loads plugins in file-name order, so the Hub may load after this plugin.
    module HubLink
      MISSING_MESSAGE = "ต้องติดตั้งหรืออัปเดต SKP CM Extensions Hub (0.5.0 ขึ้นไป) แล้ว restart SketchUp\n" \
                        'https://github.com/bhurivaj/skp_cm_extensions_hub/releases/latest'

      module_function

      # SkpCm::ExtensionsHub::Auth, or nil when the Hub is missing, disabled or older than 0.5.0
      def auth
        return nil unless defined?(SkpCm::ExtensionsHub::Auth)

        hub = SkpCm::ExtensionsHub::Auth
        hub.respond_to?(:execute_kw) ? hub : nil
      end

      # done.call(true, lead_hash) / (true, nil) when no lead has this OPP / (false, message)
      def find_lead(opp, &done)
        hub = auth
        return done.call(false, MISSING_MESSAGE) unless hub

        hub.execute_kw('crm.lead', 'search_read', [[['reference_code', '=', opp]]],
                       { 'fields' => %w[name partner_id], 'limit' => 1 }) do |ok, result|
          if !ok
            done.call(false, result.to_s)
          elsif result.is_a?(Array) && (result.empty? || result.first.is_a?(Hash))
            done.call(true, result.first)
          else
            done.call(false, 'Odoo ตอบกลับไม่ถูกต้อง')
          end
        end
      end

      # done.call(true, project) / (true, nil) when no lead has this OPP / (false, message).
      # project: 'lead', 'contact_address', 'user_name', 'warnings' — address or name that cannot be read
      # only adds a warning, so the LayOut is still created.
      def fetch_project(opp, &done)
        find_lead(opp) do |ok, lead|
          next done.call(ok, lead) unless ok && lead

          project = { 'lead' => lead, 'contact_address' => '', 'user_name' => '', 'warnings' => [] }
          read_address(project) { read_user_name(project) { done.call(true, project) } }
        end
      end

      def read_address(project, &after)
        partner = project['lead']['partner_id']
        return after.call unless partner.is_a?(Array)

        read_field('res.partner', partner[0], 'contact_address') do |value, error|
          value ? project['contact_address'] = value : project['warnings'] << "อ่านที่อยู่ลูกค้าจาก Odoo ไม่ได้: #{error}"
          after.call
        end
      end

      # DrawnBy = name of the Odoo user logged in at the Hub
      def read_user_name(project, &after)
        uid = auth.uid
        unless uid
          project['warnings'] << 'อ่านชื่อผู้เขียนแบบไม่ได้: ยังไม่ได้เชื่อมต่อ Odoo'
          return after.call
        end

        read_field('res.users', uid, 'name') do |value, error|
          value ? project['user_name'] = value : project['warnings'] << "อ่านชื่อผู้เขียนแบบจาก Odoo ไม่ได้: #{error}"
          after.call
        end
      end

      # yields (String value, nil) or (nil, error message)
      def read_field(model, id, field, &done)
        auth.execute_kw(model, 'read', [[id]], { 'fields' => [field] }) do |ok, result|
          record = ok && result.is_a?(Array) ? result.first : nil
          if record.is_a?(Hash)
            value = record[field]
            done.call(value.is_a?(String) ? value : '', nil)
          else
            done.call(nil, ok ? 'ไม่พบข้อมูล' : result.to_s)
          end
        end
      end
    end
  end
end
