module Sequel
  module Plugins
    module Paperclip
      class Attachment
        attr_reader :name
        attr_reader :options
        attr_accessor :processors

        def initialize(name, options = {})
          unless options[:styles]
            options[:styles] = {
              :original => {}
            }
          end

          unless options[:processors]
            options[:processors] = {
              :dummy => {}
            }
          end

          @name = name
          @options = options
          self.processors = []
          options[:processors].each do |p_name, p_opts|
            self.processors << "Sequel::Plugins::Paperclip::Processors::#{p_name.to_s.capitalize}".constantize.new(self, p_opts)
          end
        end

        def process(model, src_path)
          files_to_store = {}
          processors.each do |processor|
            processor.pre_runs(model, src_path)
            options[:styles].each_pair do |style, style_options|
              files_to_store[style] ||= Tempfile.new("paperclip")
              processor.run(style, style_options, files_to_store[style])
            end
            processor.post_runs
          end
          files_to_store
        end

        def exists?(model)
          !!model.send("#{name}_basename")
        end

        def path(model, style)
          Interpolations.interpolate(options[:path], self, model, style)
        end

        def url(model, style)
          Interpolations.interpolate(options[:url], self, model, style)
        end
      end
    end
  end
end
