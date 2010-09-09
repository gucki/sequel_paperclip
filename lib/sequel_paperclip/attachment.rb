module Sequel
  module Plugins
    module Paperclip
      class Attachment
        attr_reader :name
        attr_reader :options
        attr_accessor :processors

        STORAGE_UPDATE_SAVE   = 1
        STORAGE_UPDATE_DELETE = 2
        
        def initialize(name, options = {})
          unless options[:styles]
            options[:styles] = {
              :original => {}
            }
          end

          unless options[:processors]
            options[:processors] = [
              {
                :type => :dummy,
              }
            ]
          end

          @name = name
          @options = options
          self.processors = []
          options[:processors].each do |processor|
            klass = "Sequel::Plugins::Paperclip::Processors::#{processor[:type].to_s.capitalize}"
            self.processors << klass.constantize.new(self, processor)
          end
          @storage_updates = []
        end

        def process(model, src_path)
          processors.each do |processor|
            processor.pre_runs(model, src_path)
            options[:styles].each_pair do |style, style_options|
              tmp_file = Tempfile.new("paperclip")
              puts "processing #{name} for style #{style} with processor #{processor.name}"
              processor.run(style, style_options, tmp_file)
              @storage_updates << {
                :type => STORAGE_UPDATE_SAVE,
                :src_file => tmp_file,
                :dst_path => path(model, style),
              }
            end
            processor.post_runs
          end
        end

        def destroy(model)
          return unless exists?(model)

          options[:styles].each_pair do |style, style_options|
            @storage_updates << {
              :type => STORAGE_UPDATE_DELETE,
              :path => path(model, style),
            }
          end
          model.send("#{name}_basename=", nil)
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

        def update_storage(model)
          @storage_updates.each do |update|
            case update[:type]
              when STORAGE_UPDATE_SAVE
                puts "saving #{update[:dst_path]} (#{update[:src_file].size} bytes)"
                FileUtils.mkdir_p(File.dirname(update[:dst_path]))
                FileUtils.cp(update[:src_file].path, update[:dst_path])
                update[:src_file].close!
              when STORAGE_UPDATE_DELETE
                puts "deleting #{update[:path]}"
                begin
                  FileUtils.rm(update[:path])
                rescue Errno::ENOENT => error
                end
              else
                raise ArgumentError, "invalid type '#{update[:type]}'"
            end
          end        
        end
      end
    end
  end
end
