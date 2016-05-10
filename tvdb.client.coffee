Db = require 'db'
Http = require 'http'

getHeaders = (language) !->
	headers =
		'Content-Type': 'application/json'
		'Accept': 'application/json' # currently removed in http.coffee, not on the safe list

	if language?
		headers['Accept-Language'] = language

	if Db.shared.peek 'token'
		headers['Authorization'] = 'Bearer ' + Db.shared.peek 'token'

	return headers

exports.findShow = (name, language, cb) !->
	log "https://api.thetvdb.com/search/series?name=#{encodeURI(name)}"
	Http.get
		headers: getHeaders language
		url: "https://api.thetvdb.com/search/series?name=#{encodeURI(name)}"
		cb: (data) !-> exports.returnShows data, cb

exports.returnShows = (data, cb) !->
	if data.status == '200 OK'
		body = JSON.parse data.body
		shows = {}
		for i, show of body.data
			log i
			shows[i] = show
		cb shows
	else
		log 'returnShows error - code: ', data.status, ', msg: ', data.error
		cb false

exports.loadEpisodes = (id, page, seasons, result) !->
	log 'loadEpisodes', page
	if page is 1
		seasons.set {}

	Http.get
		headers: getHeaders()
		url: "https://api.thetvdb.com/series/#{id}/episodes?page=#{page}"
		cb: (data) !->
			if data.status == '200 OK'
				body = JSON.parse data.body
				episodes = {}
				for ep in body.data
					s = ep.dvdSeason ? (ep.airedSeason ? 0) # 0 = specials etc
					seasons.set s, true
					log 'found season', s

				# are there more episodes?
				if body.links.next
					exports.loadEpisodes id, body.links.next, seasons, result
				else
					result.set 'success'
			else
				log 'setEpisodes error - code: ', data.status, ', msg: ', data.error
				result.set 'failed'
