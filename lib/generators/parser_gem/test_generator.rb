require 'nokogiri'
require 'open-uri'  
require 'openssl' 
require 'ruby-progressbar'
require 'aws-sdk-translate'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE # For dodge SSL error

module ParserGem
  class TestGenerator < Rails::Generators::Base
    desc 'Clone site frontend from url'
    class_option :target_url, type: :string, default: nil # Target site url, site must have sitemap.xml 
    class_option :target_site_language, type: :string, default: nil # Set target site language
    class_option :languages, type: :string, default: nil # Additional languages
    class_option :google_api_key, type: :string, default: nil # User google API key for translate pages
    class_option :header_class_name, type: :string, default: nil # Header block id, for create partial 
    class_option :footer_class_name, type: :string, default: nil # Footer block id, for create partial
    class_option :aws_region, type: :string, default: nil # Set aws region for translate API
    class_option :aws_public_key, type: :string, default: nil # Set aws api public key
    class_option :aws_secret_key, type: :string, default: nil # Set aws api secret key
    class_option :to_partials_blocks_ids, type: :array, default: [] # Set blocks ids which must be partial
    class_option :media_to_ignore, type: :array, default: [] # Set media filenames which must be ignored
    class_option :media_to_ignore_for_langs, type: :array, default: [] # Set media filenames which must be ignored in lang versions
    class_option :create_meta_og, type: :boolean, default: false # Create meta og: tags from standart meta tags
    class_option :inline_styles_to_files, type: :boolean, default: false
    class_option :inline_scripts_to_files, type: :boolean, default: false
    class_option :meta_tags_names_to_ignore, type: :array, default: []

    def clone # Main method 
    sitemap = Nokogiri::XML(URI.open("http://#{options[:target_url]}/sitemap.xml")) # Load sitemap.xml
    controller_name = options[:target_url].split('/').last.delete('.').delete('-') # Set controller name from clear domain name
    actions = set_actions(sitemap) # Set actions for controller
    
    puts options[:to_partials_blocks_ids].to_s

    actions.each do |action| # Create routes
      if action[:rails_route] == '/' 
        route "root \"#{controller_name}##{action[:action_name]}\""
      else
        route "get \'#{action[:rails_route]}\', to: \"#{controller_name}##{action[:action_name]}\""
      end
    end

    actions_list = ""
    actions.each do |action| # Create actions list for rails generator
      actions_list += " " + action[:action_name]
    end

    generate "controller", "#{controller_name}#{actions_list} --skip-routes" # Create controller with action list
    
    puts "Start cloning #{options[:target_url]}" 

    progress = ProgressBar.create(:format         => "%a %b\u{15E7}%i %p%% %t", # Setup progressbar
                                  :progress_mark  => ' ',
                                  :remainder_mark => "\u{FF65}",
                                  :starting_at    => 0,
                                  :total          => actions.size)
    
    if options[:languages]
      credentials = Aws::Credentials.new( options[:aws_public_key], options[:aws_secret_key])      
      client = Aws::Translate::Client.new( region: options[:aws_region],
                                           credentials: credentials)
    end

    inline_styles = []
    inline_scripts = []
            
    actions.each do |action| 
      file_path = File.join('app/views', controller_name, "#{action[:action_name]}.html.erb") # Set view
      File.open(file_path, 'wb') do |file|
        page = Nokogiri::HTML(URI.open("#{action[:native_url]}")) # Parse page from url in sitemap
        
        page.css('meta').each do |meta|
          if options[:meta_tags_names_to_ignore].include?(meta['name'].to_s)
            meta.replace('')
          end
        end

        if action[:lang]
          page.css('title').each do |title|
            if title.inner_html.length > 1
              title.inner_html = translate(title.inner_html, action[:lang], client)
            end
          end

          page.css('meta').each do |meta|
            if meta['content'].length > 1
              meta['content'] = translate(meta['content'], action[:lang], client)
            end
          end

          page.css('img, video').each do |media|
            if media['alt'].length > 1
              media['alt'] = translate(media['alt'], action[:lang], client)
            end
          end
        end

        if options[:media_to_ignore_for_langs] && action[:lang]
          page.css('img, video').each do |media|
            if options[:media_to_ignore_for_langs].include?(File.basename(media['src'])) 
              media.replace('')
            end
          end
        end

        head = page.at_css('head') 
        body = page.at_css('body')

        file.puts "<% content_for :head do %>" # Saving uniq page meta and title
        head.css('title').each do |title|
          file.puts title
        end
        
        head.css('meta').each do |meta|
          file.puts meta
        end

        if options[:create_meta_og]
          file.puts "<meta property=\"og:titile\" content=\"#{head.css('title').first.inner_html}\" >"
          file.puts "<meta property=\"og:description\" content=\"#{head.css('meta[name=\"description\"]').first['content']}\" >"
          file.puts "<meta property=\"og:image\" content=\" \" >"
        end

        page.css('link[rel="stylesheet"]').each do |link| # Repair css including for Rails
          css_file_path = download_css(path_to_download(link['href']), controller_name)
          file.puts "<%= stylesheet_link_tag '#{css_file_path}' %>"
        end
        
        page.css('script[type="text/javascript"]').each do |link| # Repair js including for Rails
          if link['src'] != nil
            js_file_name = download_js(path_to_download(link['src']), controller_name)
            file.puts "<%= javascript_tag '#{js_file_name}' %>"
          end
        end

        if options[:inline_styles_to_files]
          page.css('style').each do |style_node| 
            node_hash = { filename: "inline_style_#{inline_styles.size + 1}.css", 
                          content: style_node.content }
            
            if inline_styles.size > 0
              existing_hash = inline_styles.find { |elem| elem[:content] == node_hash[:content] }
              if existing_hash
                file.puts "<%= stylesheet_link_tag '#{existing_hash[:filename]}' %>"
              else
                inline_styles << node_hash  
                file.puts "<%= stylesheet_link_tag '#{node_hash[:filename]}' %>"      
              end
            else
              inline_styles << node_hash 
              file.puts "<%= stylesheet_link_tag '#{node_hash[:filename]}' %>"
            end
          end
        else
          page.css('style').each do |style_node| # Move all style tags to head
            file.puts style_node
          end
        end

        if options[:inline_scripts_to_files]
          page.css('script').each do |script_node|
            if script_node.content && script_node.content.length > 1 
              node_hash = { filename: "inline_script_#{inline_scripts.size + 1}.js", 
                            content: script_node.content }
            
              if inline_scripts.size > 0
                existing_hash = inline_scripts.find { |elem| elem[:content] == node_hash[:content] }
                if existing_hash
                  file.puts "<%= javascript_tag '#{existing_hash[:filename]}' %>"
                else
                  inline_scripts << node_hash  
                  file.puts "<%= javascript_tag '#{node_hash[:filename]}' %>"
                end
              else
                inline_scripts << node_hash 
                file.puts "<%= javascript_tag '#{node_hash[:filename]}' %>"
              end
            end
          end
        else
          page.css('script').each do |script_node| # Move all script tags to head
            file.puts script_node
          end
        end

        file.puts "<% end %>"

        if !File.exist?("app/views/layouts/_#{action[:lang]}header.html.erb") # Create footer and header partials
          if options[:header_class_name] # Find and save header to partial
            File.open(File.join('app/views/layouts/', "_#{action[:lang]}header.html.erb"), 'w') do |file| 
              if action[:lang]
                translated_block = body.css("div[id=\"#{options[:header_class_name]}\"]").first
                translated_block.traverse do |node| 
                  if node.text? && !node.parent.name.in?(%w[script style])
                    if node.text.length > 1
                      node.content = translate(node.text, action[:lang], client)
                    end
                  end
                end
                file.puts translated_block.to_html
              else
                file.puts body.css("div[id=\"#{options[:header_class_name]}\"]").first.to_html
              end
            end
          end
        end

        if !File.exist?("app/views/layouts/_#{action[:lang]}footer.html.erb")
          if options[:footer_class_name] # Find and save footer to partial
            File.open(File.join('app/views/layouts/', "_#{action[:lang]}footer.html.erb"), 'w') do |file| 
              if action[:lang]
                translated_block = body.css("div[id=\"#{options[:footer_class_name]}\"]").first
                translated_block.traverse do |node| 
                  if node.text? && !node.parent.name.in?(%w[script style])
                    if node.text.length > 1
                      node.content = translate(node.text, action[:lang], client)
                    end
                  end
                end
                file.puts translated_block.to_html
              else
                file.puts body.css("div[id=\"#{options[:footer_class_name]}\"]").first.to_html
              end
            end
          end
        end

        body.css('img, video').each do |media| # Save media files from page, and repair src 
          media_file_path = download_media(path_to_download(media['src']), controller_name)
          media['src'] = media_file_path
        end

        body.css('script, style').each do |trash| # Clear already moved to header styles and scripts
          trash.replace('')
        end

        body.css("div[id=\"#{options[:header_class_name]}\"]").each do |header| # Call partial instead of old header block
          header.replace("<%= render \"layouts/#{action[:lang]}header\" %>")
        end
    
        body.css("div[id=\"#{options[:footer_class_name]}\"]").each do |footer| # Call partial instead of old footer block
          footer.replace("<%= render \"layouts/#{action[:lang]}footer\" %>")
        end

        body.css('a').each do |link| # Self absolute links to media repair
          if link['href']  
            if link['href'].include?("http://#{options[:target_url]}") && (link['href'].include?('.png') || link['href'].include?('.jpg') || link['href'].include?('.jpeg') || link['href'].include?('.webp'))
              link['href'] = download_media(link['href'], controller_name)
            end
          end
        end

        options[:to_partials_blocks_ids].each do |block_id|
          body.css("div[id=\"#{block_id}\"]").each do |block|
            if !File.exist?("app/views/layouts/_#{action[:lang]}#{block_id}.html.erb")
              File.open(File.join('app/views/layouts/', "_#{action[:lang]}#{block_id}.html.erb"), 'w') do |file| 
              if action[:lang]
                translated_block = body.css("div[id=\"#{block_id}\"]").first
                translated_block.traverse do |node| 
                  if node.text? && !node.parent.name.in?(%w[script style])
                    if node.text.length > 1
                      node.content = translate(node.text, action[:lang], client)
                    end
                  end
                end
                file.puts translated_block.to_html
              else
                file.puts body.css("div[id=\"#{block_id}\"]").first.to_html
              end
              end
            end
            block.replace("<%= render \"layouts/#{action[:lang]}#{block_id}\" %>")
          end
        end

        if action[:lang]
          body.css('a').each do |link| # Repair links for lang versions
            if link['href']
              if !link['href'].include?('http') && !link['href'].include?('mailto:') && !link['href'].include?('tel:')
                if link['href'][0] == '/' && ( !link['href'].include?('.jpg') || !link['href'].include?('.jpeg') || !link['href'].include?('.png') || !link['href'].include?('.webp'))
                  link['href'] = "/#{action[:lang]}#{link['href']}"
                else
                  link['href'] = "/#{action[:lang]}/#{link['href']}"
                end
              end
              if link['title']
                link['title'] = translate(link['title'], action[:lang], client)
              end
            end
          end
        end

        body.css('a').each do |link|
          if link['href']
            if link['href'][0] != '/'
              link['href'] = "/#{link['href']}"
            end
            link['href'] = link['href'].gsub('/..', '')
          end
        end

        if action[:lang]
          body.traverse do |node|
            if node.text? && !node.parent.name.in?(%w[script style])
              if node.text.length > 1
                if !node.content.include?('<%= render')
                  node.content = translate(node.text, action[:lang], client)
                end
              end
            end
          end
        end

        file.puts body.to_s.gsub(/(&lt;%|%&gt;)/) {|x| x=='&lt;%' ? '<%' : '%>'} # Put edited body to view file, and repair ERB tags
      end
      repair_css(file_path, controller_name) # Repair links in inline css
      progress.increment
    end

    if options[:inline_styles_to_files]
      inline_styles.each do |style|
        File.open(File.join('app/assets/stylesheets', style[:filename]), 'wb') do |file|
          file.puts style[:content]
        end
        repair_css("app/assets/stylesheets/#{style[:filename]}", controller_name)
      end
    end

    if options[:inline_scripts_to_files]
      inline_scripts.each do |script|
        File.open(File.join('app/javascript/', script[:filename]), 'wb') do |file|
          file.puts script[:content]
        end
        File.open('app/javascript/application.js', 'a') do |file|
          file.puts("import \"#{script[:filename]}\"") # add downloaded js file to js including file
        end
      end
    end

    # editing app/views/layouts/application.html.erb template
    File.open("app/views/layouts/application.html.erb", 'w') do |file|
      new_layout = "<!DOCTYPE html><html><head><%= yield :head %></head><body><%= yield %></body></html>"
      file.write(new_layout.to_s.gsub(/(&lt;%|%&gt;)/) {|x| x=='&lt;%' ? '<%' : '%>'})
    end
    end

    # СОЗДАНИЕ ЯЗЫКОВЫХ ВЕРСИЙ
    
    private

    def translate(text_to_translate, target_lang, client)
      client.translate_text({ text: "#{text_to_translate}", # required
      source_language_code: "#{options[:target_site_language]}", # required
      target_language_code: "#{target_lang}", # required
      settings: { formality: "FORMAL" } }).translated_text
    end

    def download_css(css_url, controller_name) # Method for save css table to file
      if !File.exist?("app/assets/stylesheets/#{File.basename(css_url)}") # Check, for dont download one file many times
        begin # need catch errors, sometimes links can be broken
          css_file_path = File.join('app/assets/stylesheets', File.basename(css_url))
          File.open(css_file_path, 'wb') do |file|
            file.write(URI.open(css_url).read) # Save css in file
          end
        rescue
          else
            repair_css(css_file_path, controller_name) # Repair links in css
            "#{File.basename(css_url)}"
        end
      else
        if File.zero?("app/assets/stylesheets/#{File.basename(css_url)}")
          ''
        else
          "#{File.basename(css_url)}" # If file already exist, just return his name
        end
      end
    end

    def download_js(js_url, controller_name) # This method working like download_css
      if !File.exist?("app/javascript/#{File.basename(js_url)}") # Check, for dont download one file many times
        begin # need catch errors, sometimes links can be broken
        js_file_path = File.join('app/javascript', File.basename(js_url))
        File.open(js_file_path, 'wb') do |file|
          file.write(URI.open(js_url).read)
        end
        File.open('app/javascript/application.js', 'a') do |file|
          file.puts("import \"#{File.basename(js_url)}\"") # add downloaded js file to js including file
        end
        rescue
        else
          "#{File.basename(js_url)}"
        end
      else
        "#{File.basename(js_url)}"
      end
    end

    def download_media(media_url, controller_name) # This method work like download_css and download_js
      if !File.exist?("public/#{File.basename(media_url)}") # Check, for dont download one file many times
        begin  # need catch errors, sometimes links can be broken
          media_file_path = File.join('public', File.basename(media_url))
          File.open(media_file_path, 'wb') do |file|
            file.write(URI.open(media_url).read)
          end
        rescue 
        else
          "/#{File.basename(media_url)}"
        end
      else
        "/#{File.basename(media_url)}"
      end
    end

    def repair_css(css_path, controller_name) # Method for repair links in css
      css_content = File.read(css_path)
      css_content.gsub!(/url\((.*?)\)/i) do |match|
        url = $1.gsub(/['"]/, '') # Remove quotes from url
        if url.start_with?('http') # Check if url is a relative path
          match # Return original link, if its third party resource
        else
          new_url = download_media(path_to_download(url), controller_name) #download media included in css
          "url(#{new_url})" 
        end
      end
      File.write(css_path, css_content) # Rewrite file
    end

    def path_to_download(path) # Repair links for download files
      begin
      result = ""
      if path.include?("http://") || path.include?("https://") || path.include?(".com")
        return path
      else
        if path[0] == '/'
          result = "http://#{options['target_url']}#{path}"
        else
          result = "http://#{options['target_url']}/#{path}"
        end
      end
      rescue
      else
      normalize_link(result.gsub(/\?.*/, '')) 
      end
    end

    def normalize_link(link) # Repair links for download files
      link_parts = link.split("/")
      result_parts = []
    
      link_parts.each do |part|
        if part != ".."
          result_parts << part
        end
      end
    
      normalized_link = result_parts.join("/")
      return normalized_link
    end
    

    def set_actions(sitemap) # Set actions from sitemap    
      actions = []
      urls = []
      languages = options[:languages].split(' ') if options[:languages]
      sitemap.xpath('//xmlns:url/xmlns:loc').each do |url|
        urls << url.text
      end

      urls.each do |url|
        element = { rails_route: "#{url.gsub('http://', '').gsub('https://', '').gsub("#{options[:target_url]}", '').delete('.')}",
                    action_name: "#{url.gsub('http://', '').gsub('https://', '').gsub("#{options[:target_url]}", '').delete('.').delete('/').gsub('-', '_')}",
                    native_url:  "#{url}",
                    lang: nil }
        
        if element[:rails_route] == '/'
          element[:action_name] = "index"
        end
        
        actions << element

        if options[:languages]
          languages.each do |lng_ver|
            element = { rails_route: "#{lng_ver}#{url.gsub('http://', '').gsub('https://', '').gsub("#{options[:target_url]}", '').delete('.')}",
                        action_name: "#{lng_ver}_#{url.gsub('http://', '').gsub('https://', '').gsub("#{options[:target_url]}", '').delete('.').delete('/').gsub('-', '_')}",
                        native_url:  "#{url}", 
                        lang: lng_ver }

            if element[:rails_route] == "#{lng_ver}/"
              element[:action_name] = "#{lng_ver}_index"
            end
        
            actions << element
          end
        end
      end
      actions
    end
  
  end
end

