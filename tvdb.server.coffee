Http = require 'http'
Db = require 'db'
Timer = require 'timer'
Key = require 'key'

IMAGE_PREFIX = "http://thetvdb.com/banners/"
getHeaders = !->
	headers =
		'Content-Type': 'application/json'
		'Accept': 'application/json' # currently removed in http.coffee, not on the safe list
		'Accept-Language': 'en'
	if language = Db.shared.peek('cfg', 'language')?
		headers['Accept-Language'] = language # not in the safe list in http.coffee, so gets deleted atm

	if Db.shared.peek 'token'
		headers['Authorization'] = 'Bearer ' + Db.shared.peek 'token'

	return headers

exports.onInstall = exports.onUpgrade = !->
	Db.backend.set 'attempts', 0
	exports.getToken()

# TOKEN MANAGEMENT
exports.getToken = !->
	if Db.shared.peek('token')?
		log 'refreshing token...'
		Http.get
			headers: getHeaders()
			url: 'https://api.thetvdb.com/refresh_token'
			cb: ['setToken', true]
	else
		log 'getting new token...'
		Http.post
			headers: getHeaders()
			body: "{\"apikey\":\"#{Key.apikey()}\"}"
			url: 'https://api.thetvdb.com/login'
			cb: ['setToken', false]

exports.setToken = (refreshing, data) !->
	delay = 0
	if refreshing and data.status is '401 Unauthorized' # broken token, let's start fresh.
		log 'broken token'
		Db.shared.set 'token', null
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
		Db.shared.set 'token', body.token

		Db.backend.set 'attempts', 0
		delay = 12*60*60*1000 # expires after 24 hours, so ensure a working token this way

		onToken = Db.backend.peek 'onToken'
		if onToken
			#Db.backend.set 'onToken', null
			if onToken is 'loadShow'
				exports.loadShow()

	Timer.cancel 'getToken', refreshing
	Timer.set delay, 'getToken'

# LOADING A SHOW'S ENTIRE DATA
exports.loadShow = !->
	log 'loadShow'
	id = Db.shared.peek 'cfg', 'showId'
	log "https://api.thetvdb.com/series/#{id}"
	Http.get
		headers: getHeaders()
		url: "https://api.thetvdb.com/series/#{id}"
		cb: ["setShow"]

exports.setShow = (data) !->
	log 'setShow'
	if data.status == '200 OK'
		body = JSON.parse data.body
		showInfo = body.data
		if showInfo.banner
			showInfo.nsImage = IMAGE_PREFIX + showInfo.banner
		Db.shared.merge 'show', showInfo
		App.setTitle showInfo.seriesName
		# show loaded, get the episodes
		loadEpisodes()
	else
		log 'setShow error - code: ', data.status, ', msg: ', data.error

# LOAD GENERIC DATA FOR ALL EPISODES
loadEpisodes = (page) !->
	log 'loadEpisodes', page
	page = page ? 1

	id = Db.shared.peek 'cfg', 'showId'
	Http.get
		headers: getHeaders()
		url: "https://api.thetvdb.com/series/#{id}/episodes?page=#{page}"
		cb: ['setEpisodes']

exports.setEpisodes = (data) !->
	log 'setEpisodes'
	if data.status == '200 OK'
		body = JSON.parse data.body

		showId = Db.shared.peek 'cfg', 'showId'
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
			loadEpisodes body.links.next
	else
		log 'setEpisodes error - code: ', data.status, ', msg: ', data.error

# LOAD MORE DETAILS ON A SPECIFIC EPISODE
exports.loadEpisode = (id) !->
	log "getEpisode: https://api.thetvdb.com/episodes/#{id}"
	Http.get
		headers: getHeaders()
		url: "https://api.thetvdb.com/episodes/#{id}"
		cb: ['setEpisode']

exports.setEpisode = (data) !->
	if data.status == '200 OK'
		body = JSON.parse data.body
		ep = body.data
		if ep.filename
			ep.nsImage = IMAGE_PREFIX + ep.filename

		s = ep.dvdSeason ? (ep.airedSeason ? 0) # 0 = specials etc
		nr = ep.dvdEpisodeNumber ? ep.airedEpisodeNumber

		showId = Db.shared.peek 'cfg', 'showId'
		Db.shared.merge 'show', 'episodes', s, nr, ep
	else
		log 'setEpisode error - code: ', data.status, ', msg: ', data.error

