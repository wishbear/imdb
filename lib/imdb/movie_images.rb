module Imdb
  class MovieImages

    attr_accessor :id

    def initialize imdb_id
      @id = imdb_id
      @url = "http://akas.imdb.com/title/tt#{imdb_id}/mediaindex"
    end


    private


    def document(url = @url)
      Nokogiri(open(url).read) rescue nil
    end


    ##
    #  Gettign common count of images associated with movie
    #    @return <Int>
    #
    def count
      $1.to_i if document.css("div.leftright #left").first.text =~ /(\d{1,})\sphoto/
    end


    ##
    #  Getting urls for all pages containing photo imdexes
    #    @return <Array>
    #
    def image_indexes
      1.upto(count/48 + 1).map do |page_number|
        "#{@url}?page=#{page_number}"
      end
    end


    ##
    #  Getting all links to pages containing high resolution images
    #    @return <Array>
    #
    def links_to_image_pages
      image_indexes.map do |index|
        unless document(index).nil?
          document(index).css("div.thumb_list a").map do |image_link|
            image_link["href"]
          end
        end
      end.flatten
    end


    public


    ##
    #  Getting links to high resolution images
    #  NOTE: Why not with threads? - Imdb output 503's page on deeply-concurrent image downloading
    #    @return <Array>
    #
    def links
      links_to_image_pages.map do |url|
        doc = document("http://akas.imdb.com#{url}")
        {
          url: doc.css("img#primary-img").first['src'],
          description: doc.css("div#photo-caption").first.text
        } rescue nil
      end.compact
    end

  end # class MovieImages
end # module Imdb
