require 'nokogiri'
require 'open-uri'  
require 'openssl'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE


module ParserGem
  class TestGenerator < Rails::Generators::Base
    desc 'Clone site frontend from url'
    class_option :target_url, type: :string, default: nil 
    class_option :languages, type: :string, default: nil
    class_option :dry, type: :boolean, default: true

    def clone
    sitemap = Nokogiri::XML(URI.open("http://#{options[:target_url]}/sitemap.xml"))
    controller_name = options[:target_url].split('/').last.delete('.').delete('-')
    actions = set_actions(sitemap)[0..1]
    
    actions.each do |action|
      if action[:rails_route] == '/'
        route "root \"#{controller_name}##{action[:action_name]}\""
      else
        route "get \'#{action[:rails_route]}\', to: \"#{controller_name}##{action[:action_name]}\""
      end
    end

    actions_list = ""
    actions.each do |action|
      actions_list += " " + action[:action_name]
    end

    generate "controller", "#{controller_name}#{actions_list} --skip-routes"
    
    actions.each do |action| 
      # Открываем файл вью, очищаем его и записываем нужную информацию
      file_path = File.join('app/views', controller_name, "#{action[:action_name]}.html.erb")
      File.open(file_path, 'w') do |file|
        page = Nokogiri::HTML(URI.open("#{action[:native_url]}"))
        file.puts "<% content_for :head do %>"
        page.css('link[rel="stylesheet"]').each do |link|
          css_file_path = download_css(path_to_download(link['href']), controller_name)
          link.replace("<%= stylesheet_link_tag '#{css_file_path}' %>")
        end
        
        page.css('script[type="text/javascript"]').each do |link|
          if link['src'] != nil
            js_file_name = download_js(path_to_download(link['src']), controller_name)
            link.replace("<%= javascript_tag '#{js_file_name}' %>")
          end
        end
        file.puts page.css('head').to_s.gsub(/(&lt;%|%&gt;)/) {|x| x=='&lt;%' ? '<%' : '%>'}

        page.css('img, video').each do |media|
          media_file_path = download_media(path_to_download(media['src']), controller_name)
          media['src'] = media_file_path
        end
        
        file.puts "<% end %>"

        file.puts page.css('body').to_s.gsub(/(&lt;%|%&gt;)/) {|x| x=='&lt;%' ? '<%' : '%>'}
      end
      repair_css(file_path, controller_name)
    end
    
    end

    # ШАБЛОНИЗАЦИЯ ХЕДЕРА - ФУТЕРА
    # ОБРАБОТКА ГЛАВНОГО ШАБЛОНА
    # СОЗДАНИЕ ЯЗЫКОВЫХ ВЕРСИЙ
    
    private

    def download_css(css_url, controller_name)
      begin
        css_file_path = File.join('app/assets/stylesheets', File.basename(css_url))
        File.open(css_file_path, 'wb') do |file|
          file.write(URI.open(css_url).read)
        end
        
      rescue
        puts "CANNOT LOAD OR REPAIR #{css_url}, FILE IGNORED"
      else
        repair_css(css_file_path, controller_name) 
        "#{File.basename(css_url)}"
      end
    end

    def download_js(js_url, controller_name)
      begin
      js_file_path = File.join('app/javascript', File.basename(js_url))
      File.open(js_file_path, 'wb') do |file|
        file.write(URI.open(js_url).read)
      end
      File.open('app/javascript/application.js', 'a') do |file|
        file.puts("import \"#{File.basename(js_url)}\"")
      end
      rescue
        puts "ОШИБКА ПРИ ЗАГРУЗКЕ \"#{js_url}\""
      else
        "#{File.basename(js_url)}"
      end
    end

    def download_media(media_url, controller_name)
      begin 
        media_file_path = File.join('public', File.basename(media_url))
        File.open(media_file_path, 'wb') do |file|
          file.write(URI.open(media_url).read)
        end
      rescue
        puts "CANNOT LOAD #{media_url}, FILE IGNORED" 
      else
        "#{File.basename(media_url)}"
      end
    end

    def repair_css(css_path, controller_name)
      css_content = File.read(css_path)
      css_content.gsub!(/url\((.*?)\)/i) do |match|
        url = $1.gsub(/['"]/, '') # Remove quotes from url
        if url.start_with?('http') # Check if url is a relative path
          match
        else
          new_url = download_media(path_to_download(url), controller_name)
          "url(/#{new_url})"
        end
      end
      File.write(css_path, css_content)
    end

    def path_to_download(path)
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
      puts "ОШИБКА ПРИ ФОРМИРОВАНИИ ССЫЛКИ: \"#{path}\""
      else
      puts "ПОМЕНЯЛ #{path} НА #{normalize_link(result.gsub(/\?.*/, ''))}"
      normalize_link(result.gsub(/\?.*/, '')) 
      end
    end

    def normalize_link(link)
      link_parts = link.split("/")
      result_parts = []
    
      link_parts.each do |part|
        if part != ".."
          # Иначе добавляем текущую часть в result_parts
          result_parts << part
        end
      end
    
      # Объединяем все элементы из result_parts обратно в строку и возвращаем результат
      normalized_link = result_parts.join("/")
      return normalized_link
    end
    

    def set_actions(sitemap)
      actions = []
      urls = []
      sitemap.xpath('//xmlns:url/xmlns:loc').each do |url|
        urls << url.text
      end

      urls.each do |url|
        element = { rails_route: "#{url.gsub('http://', '').gsub('https://', '').gsub("#{options[:target_url]}", '').delete('.')}",
                    action_name: "#{url.gsub('http://', '').gsub('https://', '').gsub("#{options[:target_url]}", '').delete('.').delete('/').gsub('-', '_')}",
                    native_url:  "#{url}" }
        
        if element[:rails_route] == '/'
          element[:action_name] = "index"
        end
        
        actions << element
      end
      actions
    end
  
  end
end

