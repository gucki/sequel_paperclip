require 'tempfile'
require 'sequel_paperclip/interpolations'
require 'sequel_paperclip/attachment'
require 'sequel_paperclip/processors/dummy'
require 'sequel_paperclip/processors/image'

module Sequel
  module Plugins
    module Paperclip
      def self.apply(model, opts={}, &block)
        model.class_attribute :attachments
        model.attachments = {}
      end

      def self.configure(model, opts={}, &block)
      end

      def self.logger
        @logger ||= (rails_logger || default_logger)
      end

      def self.rails_logger
        (defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger) ||
        (defined?(RAILS_DEFAULT_LOGGER) && RAILS_DEFAULT_LOGGER.respond_to?(:debug) && RAILS_DEFAULT_LOGGER)
      end

      def self.default_logger
        require 'logger'
        l = Logger.new(STDOUT)
        l.level = Logger::INFO
        l
      end

      def self.logger=(logger)
        @logger = logger
      end

      module ClassMethods
        def attachment(name, options)
          attr_accessor name

          Attachment.preprocess_options(options)
          self.attachments = attachments.merge(name => options)

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
              filename ? filename.gsub(/\..+$/, "") : nil
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
                basename = old_filename ? old_filename.gsub(/\..+$/, "") : ""
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

              original_filename = File.basename(value.respond_to?(:original_filename) ? value.original_filename : value.path)

              if respond_to?("#{name}_filename")
                send("#{name}_filename=", basename+File.extname(original_filename).downcase)
              end

              if respond_to?("#{name}_filesize")
                send("#{name}_filesize=", value.size)
              end

              if respond_to?("#{name}_originalname")
                send("#{name}_originalname=", original_filename)
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
          while true
            new_basename = SecureRandom.hex(4).to_s
            return new_basename unless new_basename == basename
          end
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

