module Sequel
  module Plugins
    module Paperclip
      class Attachment
        attr_reader :model
        attr_reader :name
        attr_reader :options
        attr_reader :queued_file

        STORAGE_UPDATE_SAVE   = 1
        STORAGE_UPDATE_DELETE = 2

        def self.preprocess_options(options = {})
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

          options[:processors].each_with_index do |processor, i|
            if processor.is_a?(Hash)
              klass = "Sequel::Plugins::Paperclip::Processors::#{processor[:type].to_s.capitalize}"
              options[:processors][i] = klass.constantize.new(self, processor)
            end
          end
        end

        def initialize(model, name, preprocessed_options)
          @model = model
          @name = name
          @options = preprocessed_options
          @storage_updates = []
        end

        def update(file)
          if file
            if file.respond_to?(:tempfile)
              file = file.tempfile
            end

            unless file.is_a?(File) || file.is_a?(Tempfile)
              raise ArgumentError, "#{name}: #{file} is not a File"
            end
          else
            if exists?
              options[:styles].each_pair do |style, style_options|
                @storage_updates << {
                  :type => STORAGE_UPDATE_DELETE,
                  :path => path(style),
                }
              end
            end
          end

          @queued_file = file
        end

        def exists?
          !!model.send("#{name}_basename")
        end

        def consistent?
          options[:styles].each_key do |style|
            return false unless File.exists?(path(style))
          end
          true
        end

        def path(style = :original)
          Interpolations.interpolate(options[:path], self, model, style)
        end

        def url(style = :original)
          Interpolations.interpolate(options[:url], self, model, style)
        end

        def process
          return unless @queued_file
          src_path = @queued_file.path
          options[:processors].each do |processor|
            processor.pre_runs(model, src_path)
            options[:styles].each_pair do |style, style_options|
              tmp_file = Tempfile.new("paperclip")
              Sequel::Plugins::Paperclip.logger.debug("processing #{name} for style #{style} with processor #{processor.name}")
              processor.run(style, style_options, tmp_file)
              @storage_updates << {
                :type => STORAGE_UPDATE_SAVE,
                :src_file => tmp_file,
                :dst_path => path(style),
              }
            end
            processor.post_runs
          end
          @queued_file = nil
        end

        def update_storage
          @storage_updates.each do |update|
            case update[:type]
              when STORAGE_UPDATE_SAVE
                Sequel::Plugins::Paperclip.logger.debug("saving #{update[:dst_path]} (#{update[:src_file].size} bytes)")
                FileUtils.mkdir_p(File.dirname(update[:dst_path]))
                FileUtils.cp(update[:src_file].path, update[:dst_path])
                update[:src_file].close!
              when STORAGE_UPDATE_DELETE
                Sequel::Plugins::Paperclip.logger.debug("deleting #{update[:path]}")
                begin
                  FileUtils.rm(update[:path])
                rescue Errno::ENOENT => error
                end
              else
                raise ArgumentError, "invalid type '#{update[:type]}'"
            end
          end
          @storage_updates = []
        end
      end
    end
  end
end
