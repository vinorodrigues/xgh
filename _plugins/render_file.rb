module Jekyll
  class RenderFileTag < Liquid::Tag

    def initialize(tag_name, markup, tokens)
      super

      # Initialize default values
      @file_path = nil
      @raw = false
      @markdown = nil  # Will be set based on file extension if not specified

      # Parse the markup to extract parameters
      # Expected format: 'file_path' raw:true markdown:true
      @file_path = markup[/\s*(['"])(.*?)\1/, 2]
      # Remove the file path from the markup
      markup = markup.sub(/\s*(['"])(.*?)\1/, '').strip

      # Match key:value pairs
      markup.scan(/(\w+)\s*:\s*(\w+)/) do |key, value|
        case key
        when 'raw'
          @raw = value.downcase == 'true'
        when 'markdown'
          @markdown = value.downcase == 'true'
        end
      end

      # Set @markdown based on file extension if not specified
      if @markdown.nil?
        file_extension = File.extname(@file_path).downcase
        @markdown = %w(.md .markdown).include?(file_extension)
      end

      # Error if file_path is not provided
      unless @file_path
        raise ArgumentError.new <<~MSG
          Missing file path in 'render_file' tag

          Usage:
            {% render_file 'path/to/file.ext' %}
            {% render_file 'path/to/file.ext' raw:true markdown:true %}
        MSG
      end
    end

    def render(context)
      site = context.registers[:site]
      base_path = site.source
      full_path = File.expand_path(File.join(base_path, @file_path))

      # Security check: ensure the file is within the site's source directory
      unless full_path.start_with?(base_path)
        return "Error: File #{@file_path} is outside the site source directory."
      end

      if File.exist?(full_path)
        content = File.read(full_path)
        if @raw
          rendered_content = content
        else
          # Parse the content as Liquid
          partial = Liquid::Template.parse(content)
          rendered_content = context.stack do
            partial.render(context)
          end
        end

        # Process with Markdown converter if needed
        if @markdown
          converter = site.find_converter_instance(Jekyll::Converters::Markdown)
          rendered_content = converter.convert(rendered_content)
        end

        rendered_content
      else
        "Error: File not found - #{@file_path}"
      end
    end
  end
end

Liquid::Template.register_tag('render_file', Jekyll::RenderFileTag)
