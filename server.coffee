Db = require 'db'
Http = require 'http'
Timer = require 'timer'
App = require 'app'
Xml = require 'xml'
Event = require 'event'
Comments = require 'comments'

API_KEY = "67557EB2FBDA2BED"
GOT_ID = 121361 #Game of Thrones
LOST_ID = 73739 #LOST
SEASON_NR = 6
SERIES_ID = GOT_ID

# make sure we are signed in
exports.onInstall = exports.onUpgrade = !->
	Db.backend.set 'attempts', 0
	exports.getToken 0

exports.getToken = !->
	if Db.backend.get('token')?
		log 'refreshing token...'
		Http.get
			headers: getHeaders()
			url: 'https://api.thetvdb.com/refresh_token'
			cb: ['setToken', true]
	else
		log 'getting new token...'
		Http.post
			headers: getHeaders()
			body: '{"apikey":"67557EB2FBDA2BED"}'
			url: 'https://api.thetvdb.com/login'
			cb: ['setToken', false]

exports.setToken = (refreshing, data) !->
	delay = 0
	if refreshing and data.status is '401 Not Authorized' # broken token, let's start fresh.
		log 'broken token'
		Db.backend.set 'token', null
	else if data.status != '200 OK' # other unknown problem
		log 'setToken error - code: ', data.status, ', msg: ', data.error
		attempts = Db.backend.incr 'attempts'
		delay = (Math.pow(attempts,2)) * 1000 # exponential back-off
	else # winning
		if refreshing
			log 'refreshed token!'
		else
			log 'got new token!'

		body = JSON.parse data.body
		Db.backend.set 'token', body.token

		Db.backend.set 'attempts', 0
		delay = 23*60*60*1000 # expires after 24 hours, so ensure a working token by refreshing every 23

	Timer.cancel 'getToken'
	Timer.set delay, 'getToken'

exports.updateEpisodes = !->
	getEpisode 1

	# update again in a day
	Timer.cancel 'updateEpisodes'
	Timer.set (24*60*60*1000), 'updateEpisodes'

getEpisode = (episodeNr) !->
	Http.get
		headers: getHeaders()
		url: "http://thetvdb.com/api/#{API_KEY}/series/#{SERIES_ID}/default/#{SEASON_NR}/#{episodeNr}/en.xml"
		cb: ['setEpisode', episodeNr]

exports.setEpisode = (episodeNr, data) !->
	# called when the Http API has the result for the above request
	if data.status != '200 OK'
		log 'setEpisode ', episodeNr, ' error - code: ', data.status, ', msg: ', data.error
	else
		body = JSON.parse data.body
		result = {}

		###
		if meta = Xml.search(tree, '*. episodename')[0]
			if (title = meta.innerText)?
				result.title = title

				if meta = Xml.search(tree, '*. overview')[0]
					if (overview = meta.innerText)?
						result.summary = overview

				if meta = Xml.search(tree, '*. firstaired')[0]
					if (airDate = meta.innerText)?
						result.airDate = airDate

				if meta = Xml.search(tree, '*. filename')[0]
					if (filename = meta.innerText)?
						result.image = 'http://www.thetvdb.com/banners/' + filename

				Db.shared.set 'episodes', episodeNr, 'info', result

				#log 'Successfully updated episode ' + episodeNr

				# succes! get the next one!
				getEpisode (episodeNr + 1)
		###
exports.client_unwatched = (id) !->
	episode = Db.shared.ref 'episodes', id
	episode.set 'watched', App.userId(), null

exports.client_watched = (id) !->
	episode = Db.shared.ref 'episodes', id
	watchedBy = episode.ref 'watched'
	sendTo = (+k for k,v of watchedBy.get() when not App.userIsMock(+k))
	Comments.post
		s: 'watched'
		store: ['episodes', id, 'comments']
		u: App.userId()
		path: [id]
		normalPrio: sendTo
		pushText: App.userName() + " watched episode “" + episode.get('info', 'title') + "”"

	watchedBy.set App.userId(), App.time()

getHeaders = (language) ->
	headers =
		'Content-Type': 'application/json'
		'Accept': 'application/json'

	if Db.backend.get 'token'
		headers['Authorization'] = 'Bearer ' + Db.backend.get 'token'

	if language?
		headers['Accept-Language'] = language

	headers

exports.client_findShow = (name, language, cbo) !->
	log 'language: ', language
	Http.get
		headers: getHeaders language
		url: "https://api.thetvdb.com/search/series?name=#{encodeURI(name)}"
		cb: ['returnShows', cbo]

exports.returnShows = (cbo, data) !->
	if data.status != '200 OK'
		log 'returnShows error - code: ', data.status, ', msg: ', data.error
	else
		body = JSON.parse data.body
		shows = {}
		for i, show of body.data
			shows[i] = show
		cbo.reply shows

exports.onConfig = (config = {}, fromInstall = false) !->
	log '[config] ', JSON.stringify(config)

	loadShow +config.showId, +config.seasonNr

loadShow = (showId) !->
