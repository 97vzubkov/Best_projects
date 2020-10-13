import scrapy, time


class ForumSpiderSpider(scrapy.Spider):
    name = 'forum_spider'
    allowed_domains = ['visforvoltage.org']
    start_urls = ['http://visforvoltage.org/latest_tech/']


    def parse(self, response):
        for href in response.css(r"tbody a[href*='/forum/']::attr(href)").extract():
            url = response.urljoin(href)
            req = scrapy.Request(url, callback=self.parse_data, dont_filter=True)
            yield req

        next_page = response.css(r"li[class='pager-next'] a[href*='page=']::attr(href)")
        if next_page:
        	path = next_page.extract_first()
        	nextpage = response.urljoin(path)
        	yield scrapy.Request(nextpage, callback=self.parse)

    def parse_data(self, response):
        for url in response.css('html'):
            data = {}
            data['name'] = url.css(r"div[class='author-pane-line author-name'] span[class='username']::text").extract()
            data['date'] = url.css(r"div[class='forum-posted-on']:contains('-') ::text").extract()
            data['title'] = url.css(r"div[class='section'] h1[class='title']::text").extract()
            data['body'] = url.css(r"div[class='field-items'] p::text").extract()
            yield data
