Http = require 'http'
Db = require 'db'
Timer = require 'timer'

API_KEY = "67557EB2FBDA2BED"
IMAGE_PREFIX = "http://thetvdb.com/banners/"
getHeaders = !->
	headers =
		'Content-Type': 'application/json'
		'Accept': 'application/json' # currently removed in http.coffee, not on the safe list

	if Db.shared.peek('language')?
		headers['Accept-Language'] = Db.shared.peek 'language' # not in the safe list in http.coffee, so gets deleted atm

	if Db.backend.peek 'token'
		headers['Authorization'] = 'Bearer ' + Db.backend.peek 'token'

	return headers

exports.onInstall = !->
	Db.backend.set 'attempts', 0

exports.getToken = !->
	if Db.backend.peek('token')?
		log 'refreshing token...'
		Http.get
			headers: getHeaders()
			url: 'https://api.thetvdb.com/refresh_token'
			cb: ['setToken', true]
	else
		log 'getting new token...'
		Http.post
			headers: getHeaders()
			body: "{\"apikey\":\"#{API_KEY}\"}"
			url: 'https://api.thetvdb.com/login'
			cb: ['setToken', false]

exports.setToken = (refreshing, data) !->
	delay = 0
	if refreshing and data.status is '401 Unauthorized' # broken token, let's start fresh.
		log 'broken token'
		Db.backend.set 'token', null
	else if data.status != '200 OK' # other unknown problem
		log 'setToken error - code: ', data.status, ', msg: ', data.error
		attempts = Db.backend.incr 'attempts'
		delay = (Math.pow(attempts,2)) * 1000 # exponential back-off
	else # winning
		if refreshing
			log '...refreshed token!'
		else
			log '...got new token!'

		body = JSON.parse data.body
		Db.backend.set 'token', body.token

		Db.backend.set 'attempts', 0
		delay = 12*60*60*1000 # expires after 24 hours, so ensure a working token this way

	Timer.cancel 'getToken'
	Timer.set delay, 'getToken'

exports.findShow = (name, cbo) !->
	Http.get
		headers: getHeaders()
		url: "https://api.thetvdb.com/search/series?name=#{encodeURI(name)}"
		cb: ['returnShows', cbo]

exports.returnShows = (cbo, data) !->
	if data.status == '200 OK'
		body = JSON.parse data.body
		shows = {}
		for i, show of body.data
			shows[i] = show
		cbo.reply shows
	else
		log 'returnShows error - code: ', data.status, ', msg: ', data.error
		cbo.reply false

exports.loadShow = (id) !->
	log 'loadShow'
	Db.shared.set 'show', null # clear previous
	log "https://api.thetvdb.com/series/#{id}"
	Http.get
		headers: getHeaders()
		url: "https://api.thetvdb.com/series/#{id}"
		cb: ["setShow"]

exports.setShow = (data) !->
	log 'setShow'
	if data.status == '200 OK'
		body = JSON.parse data.body
		episode = body.data
		episode.image = IMAGE_PREFIX + episode.banner
		Db.shared.set 'show', episode
		# show loaded, get the episodes
		exports.loadEpisodes Db.shared.peek 'show', 'id'
	else
		log 'setShow error - code: ', data.status, ', msg: ', data.error

exports.loadEpisodes = (id, page) !->
	log 'loadEpisodes', page
	page = page ? 1

	Http.get
		headers: getHeaders()
		url: "https://api.thetvdb.com/series/#{id}/episodes?page=#{page}"
		cb: ['setEpisodes']

exports.setEpisodes = (data) !->
	log 'setEpisodes'
	if data.status == '200 OK'
		body = JSON.parse data.body
		episodes = {}
		for ep in body.data
			s = ep.dvdSeason ? (ep.airedSeason ? 0) # 0 = specials etc

			if not episodes[s]
				episodes[s] = {}

			nr = ep.dvdEpisodeNumber ? ep.airedEpisodeNumber
			episodes[s][nr] = ep
		Db.shared.merge 'show', 'episodes', episodes

		# are there more episodes?
		if body.links.next
			exports.loadEpisodes Db.shared.peek('show', 'id'), body.links.next
	else
		log 'returnShows error - code: ', data.status, ', msg: ', data.error

exports.loadEpisode = (id) !->
	Http.get
		headers: getHeaders()
		url: "https://api.thetvdb.com/episodes/#{id}"
		cb: ['setEpisode']

exports.setEpisode = (response) !->
	if response.status == '200 OK'
		body = JSON.parse response.body
		ep = body.data
		ep.image = IMAGE_PREFIX + ep.filename

		s = ep.dvdSeason ? (ep.airedSeason ? 0) # 0 = specials etc
		nr = ep.dvdEpisodeNumber ? ep.airedEpisodeNumber

		Db.shared.merge 'show', 'episodes', s, nr, ep
	else
		log 'setEpisode error - code: ', response.status, ', msg: ', response.error

