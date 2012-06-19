module Imdb
  class Person
    attr_reader :id

    def initialize(imdb_id)
      @id = imdb_id
    end

    def name
      bio_document.at("a[@class='main']").inner_text rescue nil
    end

    def real_name
      bio_document.at("h5[text()*='Birth Name']").next.inner_text.strip rescue nil
    end

    def birthdate
      date_month = bio_document.at("h5[text()*='Date of Birth']").next_element.inner_text.strip rescue ""
      year = bio_document.at("a[@href*='birth_year']").inner_text.strip rescue ""
      Date.parse("#{date_month} #{year}") rescue nil
    end
    
    def deathdate
      date_month = bio_document.at("h5[text()*='Date of Death']").next_element.inner_text.strip rescue ""
      year = bio_document.at("a[@href*='death_date']").inner_text.strip rescue ""
      Date.parse("#{date_month} #{year}") rescue nil
    end

    def nationality
      bio_document.at("a[@href*='birth_place']").inner_text.strip rescue nil
    end

    def height
      bio_document.at("h5[text()*='Height']").next.inner_text[/\(.+\)/] rescue nil
    end

    def biography
      bio_document.at("h5[text()*='Biography']").next_element.inner_text rescue nil
    end
    
    def photo
      photo_document.at("img#primary-img").get_attribute('src') if photo_document 
    end
    
    ##
    #  Imdb code in exrtemely invalid (> 300 errors per one page), 
    #  so we need to clean it before any parsing
    #    @return <Nokogiri::HTML>
    #
    def cleared_document url
      raw_html = open(url).read
      cleared_html = raw_html.gsub("<div class=\"clear\"/>&nbsp;</div>", '')
      Nokogiri::HTML(cleared_html)
    end

    ##
    #  Getting array with person appearances as {role}
    #
    def as role
      person_page = cleared_document("http://www.imdb.com/name/nm#{@id}")
      begin
        person_page.at("#filmo-head-#{role}").next_element.search('.filmo-row b a').map do |e| 
          id = e.get_attribute('href')[/tt(\d+)/, 1]

          # content = e.parent.parent.search('a').last.try(:content)
          # if content.nil?
          #   p = e.parent.parent
          #   # e.parent.children.remove
          #   p.chidren.remove

          #   content = p.content
          # end

          content = e.parent.parent.search('a').last.try(:content)
          if content.nil? || e.parent.parent.search('a').length <= 2
            p = e.parent.parent
            # p.children.each { |c| c.remove unless c.is_a?(Nokogiri::XML::Text) }

            # content = p.content
            content = p.children.reverse.find { |c| c.is_a?(Nokogiri::XML::Text) }.content
          end

          {
            id:   Movie.new(id),
            role: content.strip
          }
        end
      rescue Exception => e
        puts "Exception: #{e} => #{e.message}\n#{e.backtrace.join("\n")}"
        []
      end
    end
   
    ##
    #  Getting all appearances of Person
    #
    def filmography
      {
        writer:     as('Writer'),
        actor:      as('Actor'),
        actress:    as('Actress'),
        director:   as('Director'),
        composer:   as('Composer'),
        producer:   as('Producer'),
        self:       as('Self'),
        soundtrack: as('Soundtrack')
      }
    end

    ##
    #  Getting array with person appearances as {role}
    #  NOTE: this method used in MovieTruly Person parser
    #    @return <Array>
    #
    def role_simplified role
      person_page = cleared_document("http://www.imdb.com/name/nm#{@id}")
      person_page.at("#filmo-head-#{role}").next_element.search('.filmo-row b a').map do |e| 
        id = e.get_attribute('href')[/tt(\d+)/, 1]
        Movie.new(id)
      end rescue []
    end

    ##
    #  Getting all appearances of Person
    #  NOTE: this method used in MovieTruly Person parser
    #    @return <Hash>
    #
    def filmography_simplified
      roles = %w(Writer Actor Actress Director Composer Producer Self Soundtrack)
      Hash[roles.map { |role| [role.downcase.to_sym, role_simplified(role)] }]
    end
    
    def main_document
      @main_document ||= Nokogiri open("http://www.imdb.com/name/nm#{@id}")
    end
    def bio_document
      @bio_document ||= Nokogiri open("http://www.imdb.com/name/nm#{@id}/bio")
    end
    
    def photo_document
      @photo_document ||= if photo_document_url then Nokogiri open("http://www.imdb.com" + photo_document_url) else nil end
    end
    
    def photo_document_url
      bio_document.at(".photo a[@name=headshot]").get_attribute('href') rescue nil
    end
    
  end
end
