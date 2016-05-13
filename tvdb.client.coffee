Db = require 'db'
Http = require 'http'

token = Db.shared?.get 'token'

getHeaders = (language) !->
	headers =
		'Content-Type': 'application/json'
		'Accept': 'application/json' # currently removed in http.coffee, not on the safe list
		'Accept-Language': language ? 'en'
	if token?
		headers['Authorization'] = 'Bearer ' + token

	return headers

exports.findShow = (name, language, cb) !->
	log "https://api.thetvdb.com/search/series?name=#{encodeURI(name)}"
	Http.get
		headers: getHeaders language
		url: "https://api.thetvdb.com/search/series?name=#{encodeURI(name)}"
		cb: (data) !->
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

exports.loadEpisodes = (id, page, episodesO, result) !->
	log 'loadEpisodes', page

	Http.get
		headers: getHeaders()
		url: "https://api.thetvdb.com/series/#{id}/episodes?page=#{page}"
		cb: (data) !->
			if data.status == '200 OK'
				body = JSON.parse data.body
				episodes = {}
				for ep in body.data
					s = ep.dvdSeason ? (ep.airedSeason ? 0) # 0 = specials etc

					# new season?
					if not episodes[s]
						episodes[s] = {}

					nr = ep.dvdEpisodeNumber ? ep.airedEpisodeNumber
					episodes[s][nr] = ep

				episodesO.merge episodes

				# are there more episodes?
				if body.links.next
					exports.loadEpisodes id, body.links.next, episodesO, result
				else
					result.set 'success'
			else
				log 'setEpisodes error - code: ', data.status, ', msg: ', data.error
				result.set 'failed'



# DUPLICATE CODE


API_KEY = "67557EB2FBDA2BED"

exports.getToken = !->
	log 'getting new token...'
	Http.post
		headers: getHeaders()
		body: "{\"apikey\":\"#{API_KEY}\"}"
		url: 'https://api.thetvdb.com/login'
		cb: (data) !->
			if data.status != '200 OK' # other unknown problem
				log 'getToken error - code: ', data.status, ', msg: ', data.error
			else # winning
				log '...got new token!'

				body = JSON.parse data.body
				token = body.token
