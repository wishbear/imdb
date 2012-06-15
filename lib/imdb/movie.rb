require 'date'

module Imdb

  # Represents a Movie on IMDB.com
  class Movie
    attr_accessor :id, :url, :title, :also_known_as

    # Initialize a new IMDB movie object with it's IMDB id (as a String)
    #
    #   movie = Imdb::Movie.new("0095016")
    #
    # Imdb::Movie objects are lazy loading, meaning that no HTTP request
    # will be performed when a new object is created. Only when you use an
    # accessor that needs the remote data, a HTTP request is made (once).
    #
    def initialize(imdb_id, title = nil, also_known_as = [])
      @id = imdb_id
      @url = "http://akas.imdb.com/title/tt#{imdb_id}/combined"
      @title = title.gsub(/"/, "") if title
      @also_known_as = also_known_as
    end

    def awards
      rows = awards_document.search('.awards table tr').select{ |n| n.search('td').count > 2 }
      result = rows.map do |row|
        elems = row.search('td')
        award = nil
        if elems.count == 3 && elems[0].search('b').count == 1
          type = elems[0]
          award = elems[1]
        elsif elems.count == 4 && elems[1].search('b').count == 1
          year = elems.first.inner_text.strip.to_i
          type = elems[1]
          award = elems[2]
        end
        {type: type.inner_text.strip.downcase, year: year, award: award.inner_text.strip} if award
      end
      result.compact!
    end
    
    def awards_document
      @awards_document ||= Nokogiri(open( "http://akas.imdb.com/title/tt#{@id}/awards"))
    end

    # Returns an array of cast members hashes
    def actors
      cast = []
      document.search("table.cast tr").each do |tr|
        member = {}
        tr.search("td.nm a") do |td|
          member[:person] = Person.new(td['href'].sub(%r{^/name/nm(.*)/}, '\1') )
        end
        member[:character] = tr.search("td.char a").inner_html.strip.imdb_unescape_html   
        cast << member
      end
      cast
      rescue []
    end

    # Returns an array with cast members
    def cast_members
      document.search("table.cast td.nm a").map { |link| link.inner_html.strip.imdb_unescape_html } rescue []
    end

    def cast_member_ids
      document.search("table.cast td.nm a").map {|l| l['href'].sub(%r{^/name/nm(.*)/}, '\1') }
    end

    # Returns an array with cast characters
    def cast_characters
      document.search("table.cast td.char").map { |link| link.inner_text } rescue []
    end

    # Returns an array with cast members and characters
    def cast_members_characters(sep = '=>')
      memb_char = Array.new
      i = 0
      self.cast_members.each{|m|
        memb_char[i] = "#{self.cast_members[i]} #{sep} #{self.cast_characters[i]}"
        i=i+1
      }
      return memb_char
    end
    
    # Returns a array of the director hashes
    def directors
      directors = []
      document.search("h5[text()^='Director'] ~ * a").each do |a|
        directors << Person.new(a['href'].sub(%r{^/name/nm(.*)/}, '\1'))
      end
      directors
      rescue []
    end
    
    # Returns the name of the director
    def director
      document.search("h5[text()^='Director'] ~ * a").map { |link| link.inner_html.strip.imdb_unescape_html } rescue []
    end

    # Returns the url to the "Watch a trailer" page
    def trailer_url
      'http://imdb.com' + document.at("a[@href*='/video/screenplay/']")["href"] rescue nil
    end

    # Returns an array of genres (as strings)
    def genres
      document.search("h5[text()='Genre:'] ~ * a[@href*='/Sections/Genres/']").map { |link| link.inner_html.strip.imdb_unescape_html } rescue []
    end

    # Returns an array of languages as strings.
    def languages
      document.search("h5[text()='Language:'] ~ * a[@href*='/language/']").map { |link| link.inner_html.strip.imdb_unescape_html } rescue []
    end

    # Returns an array of countries as strings.
    def countries
      document.search("h5[text()='Country:'] ~ * a[@href*='/country/']").map { |link| link.inner_html.strip.imdb_unescape_html } rescue []
    end

    # Returns the duration of the movie in minutes as an integer.
    def length
      document.search("//h5[text()='Runtime:']/..").inner_html[/\d+ min/].to_i rescue nil
    end

    # Returns a string containing the plot.
    def plot
      sanitize_plot(document.search("h5[text()='Plot:'] ~ div").first.inner_html) rescue nil
    end

    # Returns a string containing the URL to the movie poster.
    def poster
      src = document.at("a[@name='poster'] img")['src'] rescue nil
      case src
      when /^(http:.+@@)/
        $1 + '.jpg'
      when /^(http:.+?)\.[^\/]+$/
        $1 + '.jpg'
      end
    end

    # Returns a float containing the average user rating
    def rating
      document.at(".starbar-meta b").inner_html.strip.imdb_unescape_html.split('/').first.to_f rescue nil
    end

    # Returns an int containing the number of user ratings
    def votes
      document.at("#tn15rating .tn15more").inner_html.strip.imdb_unescape_html.gsub(/[^\d+]/, "").to_i rescue nil
    end

    # Returns a string containing the tagline
    def tagline
      document.search("h5[text()='Tagline:'] ~ div").first.inner_html.gsub(/<.+>.+<\/.+>/, '').strip.imdb_unescape_html rescue nil
    end

    # Returns a string containing the mpaa rating and reason for rating
    def mpaa_rating
      document.search("h5[text()='MPAA:'] ~ div").first.inner_html.strip.imdb_unescape_html rescue nil
    end

    def mpaa_rating_code
      document.search("h5[text()='Certification:'] ~ div.info-content a[text()^='USA:']").first.inner_html.strip.imdb_unescape_html.gsub('USA:','') rescue nil
    end

    # Returns a string containing the title
    def title(force_refresh = false)
      if @title && !force_refresh
        @title
      else
        @title = document.at("h1").inner_html.split('<span').first.strip.imdb_unescape_html rescue nil
      end
    end

    # Returns an integer containing the year (CCYY) the movie was released in.
    def year
      document.search('a[@href^="/year/"]').inner_html.to_i
    end

    # Returns release date for the movie.
    def release_date
      result = Nokogiri(open("http://www.imdb.com/title/tt#{@id}/releaseinfo")).at('#tn15content table').search('tr')[1].search('td')[1]  rescue nil
      Date.parse(result.content) rescue nil
      # sanitize_release_date(document.search("h5[text()*='Release Date']").first.next_element.inner_html.to_s.strip) rescue nil
    end

    private

    # Returns a new Nokogiri document for parsing.
    def document
      @document ||= Nokogiri(Imdb::Movie.find_by_id(@id))
    end

    # Use HTTParty to fetch the raw HTML for this movie.
    def self.find_by_id(imdb_id)
      RestClient.get("http://akas.imdb.com/title/tt#{imdb_id}/combined", accept_language: 'en-US,en;q=0.8')
    end

    # Convenience method for search
    def self.search(query)
      Imdb::Search.new(query).movies
    end

    def self.top_250
      Imdb::Top250.new.movies
    end

    def sanitize_plot(the_plot)
      the_plot = the_plot.imdb_strip_tags

      the_plot = the_plot.gsub(/add\ssummary|full\ssummary/i, "")
      the_plot = the_plot.gsub(/add\ssynopsis|full\ssynopsis/i, "")
      the_plot = the_plot.gsub(/&nbsp;|&raquo;/i, "")
      the_plot = the_plot.gsub(/see|more/i, "")
      the_plot = the_plot.gsub(/\|/i, "")

      the_plot = the_plot.strip.imdb_unescape_html
    end

    def sanitize_release_date(the_release_date)
      the_release_date = the_release_date.gsub(/<a.*a>/,"")
      the_release_date = the_release_date.gsub(/&nbsp;|&raquo;/i, "")
      the_release_date = the_release_date.gsub(/see|more/i, "")

      the_release_date = the_release_date.strip.imdb_unescape_html
    end

  end # Movie

end # Imdb
