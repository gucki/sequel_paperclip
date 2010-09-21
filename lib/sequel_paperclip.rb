require 'tempfile'
require 'sequel_paperclip/interpolations'
require 'sequel_paperclip/attachment'
require 'sequel_paperclip/processors/dummy'
require 'sequel_paperclip/processors/image'

module Sequel
  module Plugins
    module Paperclip
      def self.apply(model, opts={}, &block)
        model.class_inheritable_hash :attachments
        model.attachments = {}
      end

      def self.configure(model, opts={}, &block)
      end

      module ClassMethods
        def attachment(name, options)
          attr_accessor name

          Attachment.preprocess_options(options)
          self.attachments[name] = options

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
              if basename
                old_filename = send("#{name}_filename")
                extname = old_filename ? File.extname(old_filename) : ""
                send("#{name}_filename=", basename+extname)
              else
                send("#{name}_filename=", nil)
              end
            end

            define_method("#{name}_extname") do
              filename = send("#{name}_filename")
              filename ? File.extname(filename) : nil
            end

            define_method("#{name}_extname=") do |extname|
              if extname
                old_filename = send("#{name}_filename")
                basename = old_filename ? File.basename(old_filename) : ""
                send("#{name}_filename=", basename+extname)
              else
                send("#{name}_filename=", nil)
              end
            end
          end

          define_method("#{name}") do
            @attachment_instances ||= {}
            @attachment_instances[name] ||= Attachment.new(self, name, options)
          end

          define_method("#{name}=") do |value|
            attachment = send("#{name}")

            # queue destroy attachment, so all old files get deleted properly even
            # if the basename/ filename changes
            attachment.update(nil)

            if value
              basename = attachment_generate_basename(attachment)
              send("#{name}_basename=", basename)

              if respond_to?("#{name}_filename")
                send("#{name}_filename=", basename+File.extname(file.original_filename).downcase)
              end

              if respond_to?("#{name}_filesize")
                send("#{name}_filesize=", file.size)
              end

              if respond_to?("#{name}_originalname")
                send("#{name}_originalname=", file.original_filename)
              end
            else
              send("#{name}_basename=", nil)
            end

            # now queue the real update
            attachment.update(value)

            # force sequel to call the hooks
            modified!
          end

          define_method("#{name}?") do
            attachment = send("#{name}")
            attachment.exists?
          end
        end
      end

      module InstanceMethods     
        def attachment_generate_basename(attachment)
          basename = send("#{attachment.name}_basename")
          basename.blank? ? ActiveSupport::SecureRandom.hex(4).to_s : basename
        end

        def after_save
          if @attachment_instances
            @attachment_instances.each_value do |attachment|
              attachment.process
              attachment.update_storage
            end
          end
          super
        end

        def after_destroy
          self.class.attachments.each_key do |name|
            send("#{name}=", nil)
          end

          if @attachment_instances
            @attachment_instances.each_value do |attachment|
              attachment.update_storage
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

