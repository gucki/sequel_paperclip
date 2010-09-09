module Sequel
  module Plugins
    module Paperclip
      module Processors
        class Image
          attr_reader :name
          attr_reader :attachment
          attr_reader :options
          
          def initialize(attachment, options)
            @name = "image"
            @attachment = attachment
            @options = options
          end

          def pre_runs(model, src_path)
            @model = model
            @src_path = src_path
            @src_geometry = Geometry.from_file(@src_path)
          end
          
          def run(style, style_options, dst_file)
            dst_geometry = Geometry.from_s(style_options[:geometry])
            dst_crop = style_options[:geometry][-1,1] == "#"
            resize_str, crop_str = @src_geometry.transform(dst_geometry, dst_crop)

            cmd = []
            cmd << "convert"
            cmd << "-resize"
            cmd << "'#{resize_str}'"
            if crop_str
              cmd << "-crop"
              cmd << "'#{crop_str}'"
            end
            if options[:convert_arguments]
              cmd << options[:convert_arguments]
            end
            cmd << @src_path
            cmd << "#{style_options[:format]}:#{dst_file.path}"
            `#{cmd*" "}`
          end

          def post_runs
          end
        end

        class Image
          class Geometry
            attr_accessor :height, :width, :modifiers

            def initialize(width = nil, height = nil, modifiers = nil)
              self.width = width.to_f
              self.height = height.to_f
              self.modifiers = modifiers
            end

            def self.from_file(file)
              path = file.respond_to?(:path) ? file.path : file
              geometry = `identify -format %wx%h #{path}`
              from_s(geometry)
            end

            def self.from_s(string)
              match = string.match(/(\d+)x(\d+)(.*)/)
              if match
                Geometry.new(match[1], match[2], match[3])
              end
            end

            def to_s
              "%dx%d"%[self.width, self.height]+self.modifiers
            end

            def square?
              height == width
            end

            def horizontal?
              height < width
            end

            def vertical?
              height > width
            end

            def aspect
              width/height
            end

            def larger
              [height, width].max
            end

            def smaller
              [height, width].min
            end

            def transform(dst, crop = false)
              if crop
                ratio = Geometry.new(dst.width/self.width, dst.height/self.height)
                scale_geometry, scale = scaling(dst, ratio)
                crop_geometry = cropping(dst, ratio, scale)
              else
                scale_geometry = dst.to_s
                crop_geometry = nil
              end
              [scale_geometry, crop_geometry]
            end

            def scaling(dst, ratio)
              if ratio.horizontal? || ratio.square?
                ["%dx"%dst.width, ratio.width]
              else
                ["x%d"%dst.height, ratio.height]
              end
            end

            def cropping(dst, ratio, scale)
              if ratio.horizontal? || ratio.square?
                "%dx%d+%d+%d"%[dst.width, dst.height, 0, (self.height*scale-dst.height)/2]
              else
                "%dx%d+%d+%d"%[dst.width, dst.height, (self.width*scale-dst.width)/2, 0]
              end
            end
          end
        end
      end
    end
  end
end

