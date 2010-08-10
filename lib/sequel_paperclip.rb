require 'tempfile'
require 'sequel_paperclip/interpolations'
require 'sequel_paperclip/attachment'
require 'sequel_paperclip/processors/dummy'
require 'sequel_paperclip/processors/image'
require 'sequel_paperclip/validators/activemodel'

module Sequel
  module Plugins
    module Paperclip
      def self.apply(model, opts={}, &block)
      end

      def self.configure(model, opts={}, &block)
        model.class_inheritable_hash :attachments
        model.attachments = {}
      end

      module ClassMethods
        def attachment(name, options)
          attr_accessor name

          attachment = Attachment.new(name, options)
          attachments[name] = attachment

          columns = db_schema.keys
          unless columns.include?(:"#{name}_filename") || columns.include?(:"#{name}_basename")
            raise ArgumentError, "a column named #{name}_filename or #{name}_basename has to exist"
          end

          if columns.include?(:"#{name}_filename")
            if columns.include?(:"#{name}_basename")
              raise ArgumentError, "it does not make sense to have a column named #{name}_filename and #{name}_basename"
            end

            define_method("#{name}_basename") do
              filename = send("#{name}_filename")
              filename ? File.basename(filename) : nil
            end
            
            define_method("#{name}_basename=") do |basename|
              old_filename = send("#{name}_filename")
              extname = old_filename ? File.extname(old_filename) : ""
              send("#{name}_filename=", basename+extname)
            end
          end

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
            file = send(attachment.name)
            next unless file

            unless file.is_a?(File)
              raise ArgumentError, "#{attachment.name} is not a File"
            end

            basename = send("#{attachment.name}_basename")
            if basename.blank?
              basename = ActiveSupport::SecureRandom.hex(4).to_s
              send("#{attachment.name}_basename=", basename)
            end

            if respond_to?("#{attachment.name}_filename")
              send("#{attachment.name}_filename=", basename+File.extname(file.original_filename).downcase)
            end

            if respond_to?("#{attachment.name}_filesize")
              send("#{attachment.name}_filesize=", file.size)
            end

            if respond_to?("#{attachment.name}_originalname")
              send("#{attachment.name}_originalname=", file.original_filename)
            end
          end
          super
        end
        
        def after_save
          self.class.attachments.each_value do |attachment|
            next unless attachment.exists?(self)

            files_to_store = attachment.process(self, file.path)
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
              next unless attachment.exists?(self)
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

