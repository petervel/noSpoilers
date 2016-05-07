Http = require 'http'
Db = require 'db'
Timer = require 'timer'

API_KEY = "67557EB2FBDA2BED"

# TODO: REMOVE?
GOT_ID = 121361 #Game of Thrones
LOST_ID = 73739 #LOST
SEASON_NR = 6
SERIES_ID = GOT_ID

getHeaders = (language) !->
	headers =
		'Content-Type': 'application/json'
		'Accept': 'application/json'

	if language?
		headers['Accept-Language'] = language # due to client side caching, you can't change language yet :/

	if Db.backend.peek 'token'
		headers['Authorization'] = 'Bearer ' + Db.backend.peek 'token'

	return headers

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

getEpisode = (episodeNr, cb) !->
	Http.get
		headers: getHeaders()
		url: "http://thetvdb.com/api/#{API_KEY}/series/#{SERIES_ID}/default/#{SEASON_NR}/#{episodeNr}/en.xml"
		cb: ['setEpisode', episodeNr, cb]

exports.setEpisode = (episodeNr, cb, data) !->
	# called when the Http API has the result for the above request
	if data.status == '200 OK'
		body = JSON.parse data.body
		cb body
	else
		log 'setEpisode ', episodeNr, ' error - code: ', data.status, ', msg: ', data.error
		cb false

exports.findShow = (name, language, cbo) !->
	log 'getting ',"https://api.thetvdb.com/search/series?name=#{encodeURI(name)}"
	Http.get
		headers: getHeaders language
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

