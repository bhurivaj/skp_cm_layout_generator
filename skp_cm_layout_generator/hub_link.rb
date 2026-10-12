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
    end
  end
end
