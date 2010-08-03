module Sequel
  module Plugins
    module Paperclip
      class Interpolations
        def self.set(name, &block)
          (class << self; self; end).instance_eval do
            define_method(name, &block)
          end
        end

        def self.interpolate(string, model, attachment_name, style_name)
          string.gsub(/:\w+:/i) do |tag|
            send(tag[1..-2], model, attachment_name, style_name)
          end
        end

        def self.id(model, attachment_name, style_name)
          model.id
        end

        def self.model(model, attachment_name, style_name)
          model.class.to_s.underscore.pluralize
        end

        def self.style(model, attachment_name, style_name)
          style_name
        end

        def self.filename(model, attachment_name, style_name)
          "#{model.send("#{attachment_name}_file_name")}.#{model.class.attachments[attachment_name][:styles][style_name][:format]}"
        end

        def self.basename(model, attachment_name, style_name)
          model.send("#{attachment_name}_file_name")
        end

        def self.extname(model, attachment_name, style_name)
          model.class.attachments[attachment_name][:styles][style_name][:format]
        end

        def self.rails_root(model, attachment, style_name)
          Rails.root
        end

        def self.rails_env(model, attachment, style_name)
          Rails.env
        end
      end
    end
  end
end

