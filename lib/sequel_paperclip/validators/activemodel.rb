# encoding: utf-8
class PaperclipValidator < ActiveModel::EachValidator
  def humanized_size(num)
    for x in ['Byte','KB','MB','GB','TB']
      return "%d %s"%[num, x] if num < 1024.0
      num /= 1024.0
    end
  end

  def validate_each(model, attribute, value)
    return unless value

    if options[:size]
      min = options[:size].min
      max = options[:size].max
      if value.size < min
        model.errors.add(attribute, "zu klein (mindestes #{humanized_size(min)})")
      end
      if value.size > max
        model.errors.add(attribute, "zu groß (maximal #{humanized_size(max)})")
      end
    end

    if options[:geometry]
      geo1 = Sequel::Plugins::Paperclip::Processors::Image::Geometry.from_s(options[:geometry])
      geo2 = Sequel::Plugins::Paperclip::Processors::Image::Geometry.from_file(value)
      if geo2
        if geo2.width < geo1.width
          model.errors.add(attribute, "zu klein (weniger als %d Pixel breit)"%[geo1.width])
        end
        if geo2.height < geo1.height
          model.errors.add(attribute, "zu klein (weniger als %d Pixel hoch)"%[geo1.height])
        end
      else
        model.errors.add(attribute, "unbekanntes Bildformat oder Datei beschäftigt")
      end
    end
  end
end
