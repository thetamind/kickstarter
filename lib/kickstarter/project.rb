module Kickstarter
  
  class Project

    attr_reader :node
    
    def initialize(*args)
      case args[0]
      when String
        @seed_url = args[0]
      when Nokogiri::XML::Node
        @node = args[0]
      else
        raise TypeError
      end
    end
    
    def id
      @id ||= begin
        if node
          /\/projects\/([0-9]+)\/photo-little\.jpg/.match(thumbnail_url)[1].to_i 
        else
          details_page.css(".this_project_id").inner_html.to_i
        end
      end
    end
    
    def name
      @name ||= node ? node_link.inner_html : details_page.css("#headrow h1#name a").inner_html
    end
    
    def description
      @description ||= node ? node.css('h2 + p').inner_html : nil
    end
    
    def url
      @url ||= begin
        path = node ? node_link.attribute('href').to_s : details_page.css("#headrow h1#name a").attr("href").value
        File.join(Kickstarter::BASE_URL, path.split('?').first)
      end
    end
    
    def handle
      @handle ||= url.split('/projects/').last.gsub(/\/$/,"")
    end
    
    def owner
      @owner ||= begin
        if node
          node.css('h2 span').first.inner_html.gsub(/by/, "").strip
        end
      end
    end
    
    def thumbnail_url
      @thumbnail_url ||= begin
        if node
          node.css('.project-thumbnail img').first.attribute('src').to_s
        end
      end
    end
    
    def pledge_amount
      @pledge_amount ||= begin
        if node
          /\$([0-9\,]+)/.match(node.css('.project-stats li')[1].css('strong').inner_html)[1].gsub(/\,/,"").to_i
        else
          Integer(details_page.css("#moneyraised h5")[1].css(".num").inner_html.gsub(/,|\$/,""))
        end
      end
    end
    
    def pledge_percent
      @pledge_percent ||= begin
        if node
          node.css('.project-stats li strong').inner_html.gsub(/\,/,"").to_i * 1.0
        else
          pledge_amount * 1.0 / pledge_goal * 100.0
        end
      end
    end
    
    # can be X days|hours left
    # or <strong>FUNDED</strong> Aug 12, 2011
    def pledge_deadline
      if node
        @pledge_deadline ||= begin
          date = node.css('.project-stats li').last.inner_html.to_s
          if date =~ /Funded/
            Date.parse date.split('<strong>Funded</strong>').last.strip
          elsif date =~ /hours? left/
            future = Time.now + date.match(/\d+/)[0].to_i * 60*60
            Date.parse(future.to_s)
          elsif date =~ /days left/
            Date.parse(Time.now.to_s) + date.match(/\d+/)[0].to_i
          elsif date =~ /minutes? left/
            future = Time.now + date.match(/\d+/)[0].to_i * 60
            Date.parse(future.to_s)
          end
        end
      else
        @pledge_deadline ||= exact_pledge_deadline.to_date
      end
    end

    def to_hash
      node_values = {
        :id              => id,
        :name            => name,
        :handle          => handle,
        :url             => url,
        :description     => description,
        :owner           => owner,
        :pledge_amount   => pledge_amount,
        :pledge_percent  => pledge_percent,
        :pledge_deadline => pledge_deadline.to_s,
        :thumbnail_url   => thumbnail_url
      }
      if node.nil? #we are working with the details page only
        extra_values = {
          :pledge_goal            => pledge_goal,
          :exact_pledge_deadline  => exact_pledge_deadline.to_s,
          :short_url              => short_url,
          :about                  => about,
          :tiers                  => tiers.map{|t|t.to_hash}
        }
        node_values = node_values.merge(extra_values)
      end
      node_values
    end

    def inspect
      to_hash.inspect
    end
    
    #######################################################
    # Methods below *REQUIRE* a fetch of the details page #
    
    def details_page
      @details_page ||= seed_url ? Project.fetch_details(seed_url) : Project.fetch_details(url)
    end
    
    def pledge_goal
      @pledge_goal ||= Integer(/pledged of \$([0-9\.\,]+) goal/.match(details_page.css("#moneyraised").inner_html)[1].gsub(/,/,""))
    end
    
    def exact_pledge_deadline
      @exact_pledge_deadline ||= Time.parse(details_page.css("#project_duration_data").attr("data-end_time").value)
    end
    
    # Note: Not all projects are assigned short_urls.
    def short_url
      @short_url ||= details_page.css("#share_a_link").attr("value").value
    end
    
    def video_url
      @video_url ||= begin
        details_page.css('#video-section .video-player').first.attr('data-video').to_s
      end
    end
    
    def video_poster_url
      @video_poster_url ||= begin
          details_page.css('#video-section .video-player').first.attr('data-image').to_s
      end
    end
    
    def about
      if @about.nil?
        node = details_page.css('#about')
        node.search("h3.dotty").remove
        @about = node.inner_html.to_s
      else
        @about
      end
    end
    
    def tiers
      retries = 0
      results = []
      begin
        nodes = details_page.css('.NS-projects-reward')
        nodes.each do |node|
          results << Kickstarter::Tier.new(node)
        end
      rescue Timeout::Error
        retries += 1
        retry if retries < 3
      end
      results
    end
    
    #######################################################
    private
    #######################################################
    
    attr_reader :seed_url
    
    def node_link
      node.css('h2 a').first
    end
    
    def self.fetch_details(url)
      retries = 0
      begin
        Nokogiri::HTML(open(url))
      rescue Timeout::Error
        retries += 1
        retry if retries < 3
      end
    end
    
  end
  
end
