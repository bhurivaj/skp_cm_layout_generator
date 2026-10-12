# frozen_string_literal: true

require 'sketchup.rb'
require_relative 'project_info'
require_relative 'hub_link'
require_relative 'layout_builder'

module SkpCm
  module LayoutGenerator
    TEMPLATE = File.join(PLUGIN_DIR, 'templates', 'CIxCM.layout').freeze
    LOG = '[SKP CM Layout Generator]'

    class << self
      # Toolbar / menu "สร้าง LayOut" (spec §4.2)
      def run
        return UI.messagebox('กำลังสร้าง LayOut อยู่ — รอสักครู่') if @busy

        skp = ready_model_path
        return unless skp

        opp = ProjectInfo.opp_from_path(skp)
        return UI.messagebox("ไม่พบเลข OPP-xxxxxxxxxxx ในชื่อโฟลเดอร์ของ\n#{skp}") unless opp
        return UI.messagebox("ไม่พบ template:\n#{TEMPLATE}") unless File.exist?(TEMPLATE)

        @busy = true
        HubLink.fetch_project(opp) do |ok, project|
          @busy = false
          guard { create(skp, opp, ok, project) }
        end
      rescue StandardError => e
        @busy = false
        report(e)
      end

      private

      # Path of the saved model, or nil after telling the user what to do first
      def ready_model_path
        hub = HubLink.auth
        unless hub
          UI.messagebox(HubLink::MISSING_MESSAGE)
          return nil
        end
        unless hub.logged_in?
          answer = UI.messagebox('ยังไม่ได้ login Odoo — เปิด SKP CM Extensions Hub เพื่อ login ไหม?', MB_YESNO)
          hub.show_login if answer == IDYES
          return nil
        end

        model = Sketchup.active_model
        if model.path.empty?
          UI.messagebox('บันทึกไฟล์ .skp ไว้ในโฟลเดอร์โครงการ OPP ก่อน')
          return nil
        end
        # LayOut reads the model from disk
        if model.modified?
          return nil unless UI.messagebox('บันทึก model ก่อนสร้าง LayOut?', MB_YESNO) == IDYES
          unless model.save
            UI.messagebox('บันทึก model ไม่สำเร็จ')
            return nil
          end
        end
        model.path
      end

      def create(skp, opp, ok, project)
        return UI.messagebox(project) unless ok
        return UI.messagebox("ไม่พบ #{opp} ใน Odoo (CRM)") unless project

        values, warnings = ProjectInfo.lead_values(opp, project)
        output = ProjectInfo.output_path(skp)
        if File.exist?(output)
          return unless UI.messagebox("มี #{File.basename(output)} อยู่แล้ว — เขียนทับ?", MB_YESNO) == IDYES
        end
        warnings += LayoutBuilder.build(TEMPLATE, skp, output, values)
        UI.messagebox(ProjectInfo.summary(output, warnings))
      rescue LayoutBuilder::SaveError => e
        puts "#{LOG} save failed: #{e.message}"
        UI.messagebox("บันทึก #{File.basename(output)} ไม่ได้ — ถ้าเปิดไฟล์นี้อยู่ใน LayOut ให้ปิดก่อน")
      end

      def guard
        yield
      rescue StandardError => e
        report(e)
      end

      def report(error)
        puts "#{LOG} #{error.class}: #{error.message}\n#{error.backtrace.to_a.first(3).join("\n")}"
        UI.messagebox("เกิดข้อผิดพลาด: #{error.message}")
      end
    end

    unless file_loaded?(__FILE__)
      cmd = UI::Command.new('สร้าง LayOut') { run }
      cmd.tooltip = 'สร้าง LayOut จาก template + ข้อมูลโครงการจาก Odoo'
      icon = File.join(PLUGIN_DIR, 'icons', 'layout_icon.png')
      cmd.small_icon = icon
      cmd.large_icon = icon
      UI.menu('Extensions').add_item(cmd)
      toolbar = UI::Toolbar.new('SKP CM Layout')
      toolbar.add_item(cmd)
      toolbar.restore
      file_loaded(__FILE__)
    end
  end
end
