cheerio = require('cheerio');
rp = require('request-promise');

base_url = 'https://mobi.mit.edu'


Date.prototype.addMinutes = (h) ->
    this.setMinutes(this.getMinutes()+h);
    this


module.exports = (robot) ->
  robot.hear /bus/i, (res) ->
    getRouteInfo = (route) ->
        rp(base_url + route).then( (html) ->
            $ = cheerio.load(html);
            out_text = "*#{$('h1.kgoui_detail_title').text()}*\n"
            $("div.kgoui_list_item_subtitle").parent().each( (elem) ->
                stop = cheerio.load($(this).html())
                stop("span").text()
                times = stop("div").text().replace(/[^0-9]/g, " ").split((/(\s+)/)).map( (x) -> parseInt(x) )
                        .filter( (x) -> x ).map( (x) -> new Date().addMinutes(x).toLocaleTimeString('en-US') )

                out_text += "#{stop("span").text()} - #{times.join(', ')}\n"
            )
            res.send(out_text)
        )

    getActiveRoutes = () ->
        rp(base_url + "/default/transit/index").then( (html) ->
            $ = cheerio.load(html);
            $("span:contains('(running)')").parent().parent().each( (elem) ->
                x = $(this).attr("href");
                if(x.includes("transit"))
                    getRouteInfo(x)
            )
        )

    getActiveRoutes()