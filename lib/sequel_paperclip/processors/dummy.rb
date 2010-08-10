module Sequel
  module Plugins
    module Paperclip
      module Processors
        class Dummy
          attr_reader :attachment
          attr_reader :options
          
          def initialize(attachment, options)
          end

          def pre_runs(model, src_path)
            @src_path = src_path
          end
          
          def run(style, style_options, dst_file)
            FileUtils.cp(@src_path, dst_file.path)
          end

          def post_runs
          end
        end
      end
    end
  end
end

