module Sequel
  module Plugins
    module Paperclip
      class Interpolations
        def self.set(name, &block)
          (class << self; self; end).instance_eval do
            define_method(name, &block)
          end
        end

        def self.interpolate(string, attachment, model, style)
          string.gsub(/:\w+:/i) do |tag|
            send(tag[1..-2], attachment, model, style)
          end
        end

        def self.id(attachment, model, style)
          model.id
        end

        def self.model(attachment, model, style)
          model.class.to_s.underscore.pluralize
        end

        def self.style(attachment, model, style)
          style
        end

        def self.format(attachment, model, style)
          attachment.options[:styles][style][:format]
        end

        def self.filename(attachment, model, style)
          model.send("#{attachment.name}_filename")
        end

        def self.filesize(attachment, model, style)
          model.send("#{attachment.name}_filesize")
        end

        def self.basename(attachment, model, style)
          model.send("#{attachment.name}_basename")
        end

        def self.extname(attachment, model, style)
          File.extname(filename(attachment, model, style))
        end

        def self.rails_root(attachment, model, style)
          Rails.root
        end

        def self.rails_env(attachment, model, style)
          Rails.env
        end
      end
    end
  end
end

