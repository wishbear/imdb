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
    #  Getting array with person appearances as {role}
    #
    def as role
      # Imdb code in exrtemely invalid (> 300 errors per one page), 
      # so we need to clean it before any parsing
      raw_html = open("http://www.imdb.com/name/nm#{@id}").read
      cleared_html = raw_html.gsub("<div class=\"clear\"/>&nbsp;</div>", '')
      person_page = Nokogiri::HTML(cleared_html)
      
      begin
        person_page.at("#filmo-head-#{role}").next_element.search('.filmo-row b a').map do |e| 
          e.get_attribute('href')[/tt(\d+)/, 1]
        end
      rescue
        []
      end
    end
   
    ##
    #  Getting all appearances of Person
    #
    def filmography
      {
        writer:     as('Writer').map { |m| Movie.new(m) }, 
        actor:      as('Actor').map { |m| Movie.new(m) }, 
        actress:    as('Actress').map { |m| Movie.new(m) }, 
        director:   as('Director').map { |m| Movie.new(m) }, 
        composer:   as('Composer').map { |m| Movie.new(m) },
        producer:   as('Producer').map { |m| Movie.new(m) },
        self:       as('Self').map { |m| Movie.new(m) },
        soundtrack: as('Soundtrack').map { |m| Movie.new(m) }
      }
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
