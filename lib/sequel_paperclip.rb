require "tempfile"
require 'sequel_paperclip/interpolations'
require 'sequel_paperclip/attachment'
require 'sequel_paperclip/processors/image'

module Sequel
  module Plugins
    module Paperclip
      def self.apply(model, opts={}, &block)
      end

      def self.configure(model, opts={}, &block)
        model.attachments = {}
      end

      module ClassMethods
        attr_accessor :attachments

        def attachment(name, options)
          attr_accessor name

          attachment = Attachment.new(name, options)
          attachments[name] = attachment

          define_method("#{name}_url") do |style|
            attachment.url(self, style)
          end

          define_method("#{name}_path") do |style|
            attachment.path(self, style)
          end
        end
      end

      module InstanceMethods       
        def before_save
          self.class.attachments.each_value do |attachment|
            next unless send(attachment.name)
            basename = send("#{attachment.name}_basename")
            if basename.blank?
              basename = ActiveSupport::SecureRandom.hex(4).to_s
              send("#{attachment.name}_basename=", basename)
            end
          end
          super
        end
        
        def after_save
          self.class.attachments.each_value do |attachment|
            files_to_store = attachment.process(self)
            attachment.options[:styles].each_key do |style|
              src_file = files_to_store[style]
              dst_path = attachment.path(self, style)
              puts "saving #{dst_path}"
              FileUtils.mkdir_p(File.dirname(dst_path))
              FileUtils.cp(src_file.path, dst_path)
              src_file.close!
            end          
          end
          super
        end

        def after_destroy
          self.class.attachments.each_value do |attachment|
            attachment.options[:styles].each_key do |style|
              dst_path = attachment.path(self, style)
              puts "deleting #{dst_path}"
              begin
                FileUtils.rm(dst_path)
              rescue Errno::ENOENT => error
              end
            end          
          end
          super
        end
      end

      module DatasetMethods       
      end
    end
  end
end

